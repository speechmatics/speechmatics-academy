"""Offline loading, validation, and rendering for the Academy catalog."""

from __future__ import annotations

import html
import ipaddress
import os
import re
import tempfile
from collections import Counter
from pathlib import Path, PurePosixPath
from urllib.parse import quote, unquote, urlsplit

import jsonschema
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_FILE = REPO_ROOT / "docs/catalog.schema.yaml"
GITHUB = "https://github.com/speechmatics/speechmatics-academy/blob/main/"
NUMBERED = re.compile(r"^\d{2}-")
MARKER = re.compile(r"<!-- (BEGIN|END) GENERATED: ([a-z0-9-]+) -->")


class CatalogError(ValueError):
    """Invalid metadata, references, generated markers, or freshness."""


class UniqueKeyLoader(yaml.SafeLoader):
    """Safe YAML loader which never silently discards a duplicate mapping key."""


def _unique_mapping(loader, node, deep=False):
    loader.flatten_mapping(node)
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        try:
            duplicate = key in result
        except TypeError as error:
            raise CatalogError(f"YAML mapping key must be scalar at line {key_node.start_mark.line + 1}") from error
        if duplicate:
            raise CatalogError(f"duplicate YAML key {key!r} at line {key_node.start_mark.line + 1}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _unique_mapping)


def load_yaml(path):
    try:
        return yaml.load(Path(path).read_text(encoding="utf-8"), Loader=UniqueKeyLoader)
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise CatalogError(f"Cannot load {path}: {error}") from error


def local_path(root, reference, *, directory=False, allow_fragment=False):
    """Resolve a real local reference, rejecting traversal and symlink escape."""
    if not isinstance(reference, str) or any(ord(char) < 32 for char in reference):
        raise CatalogError(f"Invalid local reference: {reference!r}")
    try:
        parsed = urlsplit(reference)
    except ValueError as error:
        raise CatalogError(f"Invalid local reference: {reference!r}") from error
    raw_path = unquote(parsed.path)
    parts = raw_path.split("/")
    if (
        parsed.scheme
        or parsed.netloc
        or parsed.query
        or not raw_path
        or "\\" in raw_path
        or ":" in raw_path
        or raw_path.startswith("/")
        or any(p in ("", ".", "..") for p in parts)
    ):
        raise CatalogError(f"Unsafe repository-relative path: {reference!r}")
    if parsed.fragment and (directory or not allow_fragment):
        raise CatalogError(f"This local path cannot have a fragment: {reference!r}")
    resolved = (root / raw_path).resolve()
    if not resolved.is_relative_to(root.resolve()):
        raise CatalogError(f"Path escapes repository: {reference!r}")
    if not (resolved.is_dir() if directory else resolved.is_file()):
        raise CatalogError(f"Missing {'directory' if directory else 'file'}: {reference}")
    if parsed.fragment:
        fragment = unquote(parsed.fragment)
        if fragment not in markdown_anchors(resolved):
            raise CatalogError(f"Missing local fragment #{fragment} in {reference}")
    return resolved


def markdown_anchors(path):
    """GitHub-style heading IDs plus explicit HTML IDs in local Markdown/assets."""
    if path.suffix.lower() not in (".md", ".mdx", ".txt", ".html", ".svg"):
        return set()
    text = path.read_text(encoding="utf-8")
    anchors = set(re.findall(r"""\b(?:id|name)\s*=\s*["']([^"']+)["']""", text))
    used = set()
    fence = None
    previous = ""
    for line in text.splitlines():
        stripped = line.strip()
        fenced = re.match(r"^(`{3,}|~{3,})", stripped)
        if fenced:
            marker = fenced.group(1)
            if fence is None:
                fence = marker[0]
            elif marker[0] == fence:
                fence = None
            previous = ""
            continue
        if fence is not None:
            continue
        heading = re.match(r"^ {0,3}#{1,6}\s+(.+?)(?:\s+#+\s*)?$", line)
        title = heading.group(1) if heading else None
        if title is None and previous and re.fullmatch(r" {0,3}(?:=+|-+)\s*", line):
            title = previous
        if title:
            title = re.sub(r"!?\[([^\]]+)\]\([^)]*\)", r"\1", title)
            title = html.unescape(re.sub(r"<[^>]*>", "", title)).lower()
            slug = re.sub(r"[^\w\s-]", "", title).replace(" ", "-")
            slug = re.sub(r"\s", "-", slug)
            candidate = slug
            suffix = 0
            while candidate in used:
                suffix += 1
                candidate = f"{slug}-{suffix}"
            used.add(candidate)
            anchors.add(candidate)
        previous = stripped
    return anchors


def validate_https(reference):
    try:
        parsed = urlsplit(reference)
        hostname = (parsed.hostname or "").lower()
        if parsed.scheme != "https" or not hostname or parsed.username or parsed.password:
            raise ValueError("expected a public HTTPS URL without credentials")
        if any(char.isspace() or ord(char) < 32 for char in reference) or "\\" in reference:
            raise ValueError("invalid URL characters")
        if hostname == "localhost" or hostname.endswith((".localhost", ".local")):
            raise ValueError("localhost is not a hosted demo")
        try:
            address = ipaddress.ip_address(hostname)
        except ValueError:
            address = None
        if address is not None and not address.is_global:
            raise ValueError("private addresses are not hosted demos")
        _ = parsed.port
    except ValueError as error:
        raise CatalogError(f"Unsafe external URL {reference!r}: {error}") from error


def readme(example):
    return example.get("readme", example["path"] + "/README.md")


def discover_examples(root, community_subcategories=()):
    """Discover every numbered example, including previously unknown frameworks."""
    found = set()
    for category in ("basics", "use-cases"):
        parent = root / category
        if parent.is_dir():
            found.update(
                p.relative_to(root).as_posix() for p in parent.iterdir() if p.is_dir() and NUMBERED.match(p.name)
            )
    integrations = root / "integrations"
    if integrations.is_dir():
        for framework in integrations.iterdir():
            if framework.is_dir():
                found.update(
                    p.relative_to(root).as_posix() for p in framework.iterdir() if p.is_dir() and NUMBERED.match(p.name)
                )
    for category in community_subcategories:
        parent = root / "community" / category
        if parent.is_dir():
            found.update(
                p.relative_to(root).as_posix() for p in parent.iterdir() if p.is_dir() and not p.name.startswith(".")
            )
    return found


def load_catalog(root):
    root = Path(root).resolve()
    data = load_yaml(root / "docs/index.yaml")
    validator = jsonschema.Draft202012Validator(load_yaml(SCHEMA_FILE), format_checker=jsonschema.FormatChecker())
    errors = sorted(validator.iter_errors(data), key=lambda e: str(list(e.absolute_path)))
    if errors:
        raise CatalogError(
            "Schema validation failed:\n"
            + "\n".join(f"  {'.'.join(map(str, error.absolute_path)) or '<root>'}: {error.message}" for error in errors)
        )
    registries = {}
    for name in ("categories", "packages", "apis", "collections", "integration_frameworks"):
        records = data[name]
        duplicates = [key for key, count in Counter(record["id"] for record in records).items() if count > 1]
        if duplicates:
            raise CatalogError(f"Duplicate {name} IDs: {', '.join(duplicates)}")
        registries[name] = {record["id"]: record for record in records}
        for record in records:
            if "url" in record:
                validate_https(record["url"])
            if "readme" in record:
                local_path(root, record["readme"])
            if "logo" in record:
                for theme in ("light", "dark"):
                    local_path(root, record["logo"][theme])
    for field in ("id", "path", "order"):
        duplicates = [key for key, count in Counter(ex[field] for ex in data["examples"]).items() if count > 1]
        if duplicates:
            raise CatalogError(f"Duplicate example {field}: {duplicates}")
    for vocabulary, labels in (("languages", "language_labels"), ("features", "feature_labels")):
        unknown = set(data[labels]) - set(data[vocabulary])
        missing = set(data[vocabulary]) - set(data[labels])
        if unknown or missing:
            raise CatalogError(
                f"{labels} must label exactly {vocabulary}; unknown={sorted(unknown)}, missing={sorted(missing)}"
            )
    vocabularies = {
        "category": registries["categories"],
        "difficulty": data["difficulty_levels"],
        "languages": data["languages"],
        "features": data["features"],
        "integrations": registries["integration_frameworks"],
        "packages": registries["packages"],
        "apis": registries["apis"],
        "collections": registries["collections"],
        "status": data.get("community_status", []),
        "subcategory": data.get("community_subcategories", []),
    }
    used_readmes = set()
    for example in data["examples"]:
        for field, vocabulary in vocabularies.items():
            values = example.get(field, [])
            if isinstance(values, str):
                values = [values]
            unknown = set(values) - set(vocabulary)
            if unknown:
                raise CatalogError(f"[{example['id']}] Unknown {field}: {sorted(unknown)}")
        local_path(root, example["path"], directory=True)
        if example["path"].split("/")[0] != example["category"]:
            raise CatalogError(f"[{example['id']}] Category must match its top-level example directory")
        canonical = local_path(root, readme(example))
        if canonical in used_readmes:
            raise CatalogError(f"Reused canonical README: {readme(example)}")
        used_readmes.add(canonical)
        if not canonical.is_relative_to((root / example["path"]).resolve()):
            raise CatalogError(f"[{example['id']}] README must be inside its example path")
        if example["category"] == "community":
            if "status" not in example or "subcategory" not in example:
                raise CatalogError(f"[{example['id']}] Community example requires status and subcategory")
            if len(example["path"].split("/")) != 3 or example["path"].split("/")[1] != example["subcategory"]:
                raise CatalogError(f"[{example['id']}] Community subcategory must match its directory")
        if example["category"] != "community" and ("status" in example or "subcategory" in example):
            raise CatalogError(f"[{example['id']}] Community status/subcategory requires category community")
        for demo in example["demos"]:
            if demo["type"] == "local":
                local_path(root, demo["url"], allow_fragment=True)
            elif demo["type"] == "recording" and not re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", demo["url"]):
                local_path(root, demo["url"], allow_fragment=True)
            else:
                validate_https(demo["url"])
    orphaned = discover_examples(root, data.get("community_subcategories", [])) - {
        ex["path"] for ex in data["examples"]
    }
    if orphaned:
        raise CatalogError("Orphan example directories missing from index.yaml: " + ", ".join(sorted(orphaned)))
    examples_by_id = {ex["id"]: ex for ex in data["examples"]}
    # Compare destinations as resolved filesystem paths, including Windows case
    # aliases, decoded references and symlinks, before preparing any outputs.
    hub_paths = {(root / path).resolve() for path in ("README.md", "docs/CATALOG.md", "llms.txt")} | used_readmes
    for registry_name, field in (("collections", "collections"), ("integration_frameworks", "integrations")):
        for hub in data[registry_name]:
            if "readme" not in hub:
                continue
            target = hub["start_here"]
            if target not in examples_by_id or hub["id"] not in examples_by_id[target][field]:
                raise CatalogError(f"Hub {hub['id']}: start_here must identify a member example")
            path = hub["readme"]
            destination = local_path(root, path)
            if destination in hub_paths:
                raise CatalogError(f"Hub output path reused: {path}")
            hub_paths.add(destination)
    return data


def literal_text(value):
    """Escape Markdown text; quotes need escaping only in HTML attributes."""
    text = html.escape(str(value), quote=False)
    for char in ("|", "[", "]", "*", "_", "`", "~", "\\"):
        text = text.replace(char, f"&#{ord(char)};")
    return text


def escape(value):
    """Render literal table-safe Markdown without injected HTML, links, or cells."""
    return " ".join(literal_text(value).split())


def plain_text(value):
    """Single-line raw index prose, preserving literal punctuation and identifiers."""
    return " ".join(str(value).split())


def plain_link_label(value):
    """Use readable Markdown escapes inside raw-index link labels, not entities."""
    text = plain_text(value)
    for char in ("\\", "[", "]", "`", "*", "_", "~", "<", ">"):
        text = text.replace(char, "\\" + char)
    return text


def note_text(value):
    """Allow balanced code spans in prose notes; keep other markup literal."""
    source = str(value).strip().replace("\r\n", "\n").replace("\r", "\n")
    runs = list(re.finditer(r"`+", source))
    pieces = []
    cursor = index = 0
    while index < len(runs):
        opening = runs[index]
        before = source[: opening.start()]
        backslashes = len(before) - len(before.rstrip("\\"))
        if backslashes % 2:
            index += 1
            continue
        closing_index = next(
            (other for other in range(index + 1, len(runs)) if runs[other].group() == opening.group()), None
        )
        if closing_index is None:
            index += 1
            continue
        closing = runs[closing_index]
        pieces.append(re.sub(r"\s+", " ", literal_text(source[cursor : opening.start()])))
        pieces.append(source[opening.start() : closing.end()].replace("\n", " "))
        cursor = closing.end()
        index = closing_index + 1
    pieces.append(re.sub(r"\s+", " ", literal_text(source[cursor:])))
    return "".join(pieces)


def link(title, reference, output, *, formatter=escape):
    if urlsplit(reference).scheme:
        target = quote(reference, safe=":/?#[]@!$&'()*+,;=%-._~")
    else:
        path, separator, fragment = reference.partition("#")
        target = Path(os.path.relpath(unquote(path), PurePosixPath(output).parent.as_posix())).as_posix()
        target = quote(target, safe="/-._~")
        if separator:
            target += "#" + quote(unquote(fragment), safe="-._~")
    return f"[{formatter(title)}](<{target}>)"


def absolute_link(title, path):
    return link(title, GITHUB + quote(path, safe="/-._~#"), "llms.txt", formatter=plain_link_label)


def registry(data, name):
    return {record["id"]: record for record in data[name]}


def names(data, example, field, *, formatter=escape):
    if field in ("languages", "features"):
        labels = data["language_labels" if field == "languages" else "feature_labels"]
        return ", ".join(formatter(labels[item]) for item in example[field]) or "None listed"
    records = registry(data, "integration_frameworks" if field == "integrations" else field)
    return ", ".join(formatter(records[item]["title"]) for item in example[field]) or "None listed"


def package_links(data, example, output):
    packages = registry(data, "packages")
    if not example["packages"]:
        return "Direct API / configuration"
    return ", ".join(link(packages[item]["label"], packages[item]["url"], output) for item in example["packages"])


def api_links(data, example, output):
    apis = registry(data, "apis")
    return (
        ", ".join(
            link(apis[item]["title"], apis[item]["url"], output) if "url" in apis[item] else escape(apis[item]["title"])
            for item in example["apis"]
        )
        or "No API directly demonstrated"
    )


def status(example):
    text = "Implementation: " + escape(example["lifecycle"])
    if "status" in example:
        text += "; Community review: " + escape(example["status"])
    return text


def navigation_title(example, output):
    title = link(example["title"], readme(example), output)
    if example["lifecycle"] != "current":
        title += " **" + escape(example["lifecycle"].capitalize()) + "**"
    if "status" in example:
        title += "<br>Community review: " + escape(example["status"])
    return title


def demos(example, output):
    return (
        "<br>".join(
            link(demo["type"].capitalize(), demo["url"], output) + ": " + escape(demo["description"])
            for demo in example["demos"]
        )
        or "No demo listed"
    )


def table(headers, rows):
    return "\n".join(
        ["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"]
        + ["| " + " | ".join(row) + " |" for row in rows]
    )


def sorted_examples(data):
    return sorted(data["examples"], key=lambda ex: (ex["order"], ex["id"]))


def primary_integration(example):
    members = example["integrations"]
    parts = PurePosixPath(example["path"]).parts
    parent = parts[1] if len(parts) > 1 else ""
    return parent if parent in members else next(iter(members), None)


def integration_label(item, output):
    if item is None:
        return "Direct API"
    if "logo" not in item:
        return link(item["title"], item.get("readme", item["url"]), output)
    logo = item["logo"]
    light = html.escape(quote(logo["light"], safe="/-._~"), quote=True)
    dark = html.escape(quote(logo["dark"], safe="/-._~"), quote=True)
    alt = html.escape(item["title"], quote=True).replace("|", "&#124;")
    return (
        f'<picture><source media="(prefers-color-scheme: dark)" srcset="{dark}">'
        f'<img src="{light}" alt="{alt}" height="{logo["height"]}"></picture>'
    )


def root_group_cells(data, group, members, fallback_anchor):
    count = len(members)
    destination = group.get("readme") or (readme(members[0]) if count == 1 else "docs/CATALOG.md#" + fallback_anchor)
    languages = {language for example in members for language in example["languages"]}
    return [
        link(f"{count} {'example' if count == 1 else 'examples'}", destination, "README.md").replace(" ", "&nbsp;", 1),
        escape(group.get("description", members[0]["description"])),
        ", ".join(escape(data["language_labels"][language]) for language in data["languages"] if language in languages)
        or "None listed",
    ]


def render_root_table(data, category):
    output = "README.md"
    rows = []
    integrations = registry(data, "integration_frameworks")
    collections = registry(data, "collections")
    examples = sorted_examples(data)
    if category == "basics":
        for example in examples:
            if example["category"] != category:
                continue
            rows.append(
                [
                    navigation_title(example, output),
                    escape(example.get("summary", example["description"])),
                    package_links(data, example, output),
                    escape(example["difficulty"]),
                ]
            )
    elif category == "integrations":
        seeds = dict.fromkeys(primary_integration(example) for example in examples if example["category"] == category)
        for identifier in seeds:
            item = integrations.get(identifier)
            members = [
                example
                for example in examples
                if identifier in example["integrations"]
                or (identifier is None and example["category"] == category and not example["integrations"])
            ]
            rows.append(
                [integration_label(item, output)]
                + root_group_cells(
                    data, item or {}, members, "integration-" + identifier if identifier else "by-integration"
                )
            )
    else:
        seeds = {
            identifier
            for example in examples
            if example["category"] == category
            for identifier in example["collections"]
        }
        for identifier, item in collections.items():
            if identifier not in seeds:
                continue
            members = [example for example in examples if identifier in example["collections"]]
            rows.append([escape(item["title"])] + root_group_cells(data, item, members, "collection-" + identifier))
        others = [example for example in examples if example["category"] == category and not example["collections"]]
        if others:
            rows.append(["Other examples"] + root_group_cells(data, {}, others, "all-example-details"))
    headers = {
        "basics": ["Example", "Description", "Packages", "Difficulty"],
        "integrations": ["Integration", "Examples", "What you'll build", "Languages"],
        "use-cases": ["Focus", "Examples", "What you'll build", "Languages"],
    }[category]
    return table(headers, rows)


def render_hub(data, hub, field):
    output = hub["readme"]
    members = [example for example in sorted_examples(data) if hub["id"] in example[field]]
    groups = [(None, members)]
    if hub.get("group_by_lifecycle"):
        groups = [
            ("Current examples", [ex for ex in members if ex["lifecycle"] == "current"]),
            ("Legacy and preview examples", [ex for ex in members if ex["lifecycle"] != "current"]),
        ]
    lines = []
    for title, examples in groups:
        if not examples:
            continue
        if title:
            lines.extend(["### " + title, ""])
        rows = [
            [
                navigation_title(example, output),
                escape(example.get("summary", example["description"])),
                package_links(data, example, output),
                names(data, example, "languages") + "<br>" + escape(example["difficulty"]),
                " · ".join(link(demo["type"].capitalize(), demo["url"], output) for demo in example["demos"])
                or "No demo listed",
            ]
            for example in examples
        ]
        lines.extend([table(["Example", "What you'll build", "SDK / adapter", "Language / level", "Demo"], rows), ""])
    noted = [example for _, examples in groups for example in examples if example.get("demo_note")]
    if noted:
        lines.extend(["### Demo access", ""])
        lines.extend(
            "- " + link(example["title"], readme(example), output) + ": " + note_text(example["demo_note"])
            for example in noted
        )
        lines.append("")
    apis = {identifier for example in members for identifier in example["apis"]}
    references = [api for api in data["apis"] if api["id"] in apis and "url" in api]
    if references:
        lines.extend(
            [
                "API reference: " + " · ".join(link(api["title"], api["url"], output) for api in references) + ".",
                "",
            ]
        )
    if "voice-preview" in apis:
        lines.extend([voice_preview_note(), ""])
    return "\n".join(lines).rstrip()


def availability_note():
    return (
        "Service availability: implementation lifecycle describes this example, not an access guarantee. "
        "Check the linked API documentation and your account access before running it. "
        "A local demo requires setup; a recording shows a captured session."
    )


def voice_preview_note():
    return "The Voice API preview is a legacy protocol, separate from Agent STT."


def render_catalog(data):
    output = "docs/CATALOG.md"
    lines = [
        "# Speechmatics Academy Catalog",
        "",
        link("← Back to Academy", "README.md", output),
        "",
        "<!-- Generated from docs/index.yaml; run .github/scripts/generate_catalog.py. -->",
        "",
        f"{len(data['examples'])} examples. Metadata updated {escape(data['last_updated'])}.",
        "",
        availability_note(),
        "",
        "Browse: [Package](#by-package) · [Feature](#by-feature) · [Language](#by-language) · "
        "[Integration](#by-integration) · [Collection](#by-collection) · [Difficulty](#by-difficulty)",
        "",
    ]
    facets = [
        ("package", "Package", "packages", data["packages"]),
        (
            "feature",
            "Feature",
            "features",
            [{"id": key, "title": data["feature_labels"][key]} for key in data["features"]],
        ),
        (
            "language",
            "Language",
            "languages",
            [{"id": key, "title": data["language_labels"][key]} for key in data["languages"]],
        ),
        ("integration", "Integration", "integrations", data["integration_frameworks"]),
        ("collection", "Collection", "collections", data["collections"]),
        (
            "difficulty",
            "Difficulty",
            "difficulty",
            [{"id": key, "title": key.capitalize()} for key in data["difficulty_levels"]],
        ),
    ]
    examples = sorted_examples(data)
    for singular, label, field, groups in facets:
        lines.extend([f'<a id="by-{singular}"></a>', f"## By {label.lower()}", ""])
        groups = list(groups)
        if field == "packages":
            groups.append({"id": "direct-api-configuration", "title": "Direct API / configuration"})
        for group in groups:
            if field == "difficulty":
                matches = [ex for ex in examples if ex[field] == group["id"]]
            elif field == "packages" and group["id"] == "direct-api-configuration":
                matches = [ex for ex in examples if not ex["packages"]]
            else:
                matches = [ex for ex in examples if group["id"] in ex[field]]
            if not matches:
                continue
            lines.extend([f'<a id="{singular}-{group["id"]}"></a>', "### " + escape(group["title"]), ""])
            if "description" in group:
                lines.extend([escape(group["description"]), ""])
            if "readme" in group:
                lines.extend([link("Open the " + group["title"] + " guide", group["readme"], output), ""])
            rows = [
                [
                    navigation_title(ex, output) + " · " + f"[Details](#example-{ex['id']})",
                    escape(ex.get("summary", ex["description"])),
                    package_links(data, ex, output),
                    names(data, ex, "languages"),
                    escape(ex["difficulty"]),
                ]
                for ex in matches
            ]
            lines.extend([table(["Example", "Description", "Packages", "Languages", "Difficulty"], rows), ""])
    lines.extend(['<a id="all-example-details"></a>', "## Example details", ""])
    for example in examples:
        lines.extend(
            [
                f'<a id="example-{example["id"]}"></a>',
                "### " + escape(example["title"]),
                "",
                f"Example ID: `{example['id']}`. " + link("Canonical README", readme(example), output) + ".",
                "",
                escape(example["description"]),
                "",
                f"{status(example)}; kind: {escape(example['kind'])}; "
                f"difficulty: {escape(example['difficulty'])}; languages: {names(data, example, 'languages')}.",
                "",
                "- APIs: " + api_links(data, example, output),
                "- Packages: " + package_links(data, example, output),
                "- Features: " + names(data, example, "features"),
                "- Integrations: " + names(data, example, "integrations"),
                "- Collections: " + names(data, example, "collections"),
                "- Estimated time: "
                + escape(example["estimated_time"])
                + "; last updated: "
                + escape(example["last_updated"]),
                "- Demos: " + demos(example, output),
            ]
        )
        if example.get("models"):
            lines.append("- Demonstrated model IDs: " + ", ".join(escape(model) for model in example["models"]))
        if example.get("demo_note"):
            lines.append("- Demo access: " + note_text(example["demo_note"]))
        if "voice-preview" in example["apis"]:
            lines.extend(["", voice_preview_note()])
        lines.append("")
    lines.extend(["---", "", link("← Back to Academy", "README.md", output), ""])
    return "\n".join(lines).rstrip() + "\n"


def render_llms(data, root):
    lines = [
        "# Speechmatics Academy",
        "",
        "> Examples and learning guides for Speechmatics APIs, SDKs, and integrations.",
        "",
        "This index supplements the repository documentation. Follow each linked README for setup and access requirements.",
        "",
        availability_note(),
        "",
        "## Guides",
        "",
    ]
    for title, path in (
        ("Academy overview", "README.md"),
        ("Complete example catalog", "docs/CATALOG.md"),
        ("Catalog maintenance guide", "docs/CATALOG_GUIDE.md"),
        ("Contributing", "docs/CONTRIBUTING.md"),
    ):
        if path == "docs/CATALOG.md" or (root / path).is_file():
            lines.append("- " + absolute_link(title, path))
    lines.extend(["", "## Topic and integration guides", ""])
    for name in ("collections", "integration_frameworks"):
        for hub in data[name]:
            if "readme" in hub:
                lines.append(
                    "- "
                    + absolute_link(hub["title"], hub["readme"])
                    + ": "
                    + plain_text(hub.get("description", hub["title"] + " examples and setup choices"))
                )
    lines.extend(["", "## Examples", ""])
    for example in sorted_examples(data):
        lines.append(
            "- "
            + absolute_link(example["title"], readme(example))
            + ": "
            + plain_text(example["description"])
            + " "
            + status(example)
            + "; APIs: "
            + names(data, example, "apis", formatter=plain_text)
            + "; packages: "
            + (
                names(data, example, "packages", formatter=plain_text)
                if example["packages"]
                else "Direct API / configuration"
            )
            + "; languages: "
            + names(data, example, "languages", formatter=plain_text)
            + "."
            + (" Demo access: " + plain_text(example["demo_note"]) if example.get("demo_note") else "")
            + (" " + voice_preview_note() if "voice-preview" in example["apis"] else "")
        )
    lines.append("")
    return "\n".join(lines)


def replace_blocks(text, blocks, path):
    """Validate the entire marker structure before replacing any block."""
    opened = None
    spans = {}
    for token in MARKER.finditer(text):
        direction, name = token.groups()
        if direction == "BEGIN":
            if opened is not None or name in spans:
                raise CatalogError(f"Ambiguous or nested generated marker in {path}: {name}")
            opened = (name, token.end())
        else:
            if opened is None or opened[0] != name:
                raise CatalogError(f"Unmatched generated marker in {path}: {name}")
            spans[name] = (opened[1], token.start())
            opened = None
    if opened:
        raise CatalogError(f"Unclosed generated marker in {path}: {opened[0]}")
    for name in blocks:
        if name not in spans:
            raise CatalogError(f"Missing generated marker pair in {path}: {name}")
    for name in sorted(blocks, key=lambda name: spans[name][0], reverse=True):
        start, end = spans[name]
        text = text[:start] + "\n" + blocks[name].strip() + "\n" + text[end:]
    return text


def prepare_outputs(data, root):
    """Build every target in memory, so marker errors never cause partial writes."""
    root = Path(root).resolve()
    outputs = {"docs/CATALOG.md": render_catalog(data), "llms.txt": render_llms(data, root)}
    blocks = {"README.md": {name: render_root_table(data, name) for name in ("basics", "integrations", "use-cases")}}
    for name, field in (("collections", "collections"), ("integration_frameworks", "integrations")):
        for hub in data[name]:
            if "readme" in hub:
                blocks[hub["readme"]] = {"examples": render_hub(data, hub, field)}
    for path, replacements in blocks.items():
        original = local_path(root, path).read_text(encoding="utf-8")
        outputs[path] = replace_blocks(original, replacements, path)
    for path in outputs:
        target = root / path
        if not target.resolve().is_relative_to(root):
            raise CatalogError(f"Output path escapes repository: {path}")
        if target.exists() and not target.is_file():
            raise CatalogError(f"Output path is not a file: {path}")
    return outputs


def update_outputs(root, outputs, *, check=False):
    root = Path(root).resolve()
    changed = {}
    for path, content in outputs.items():
        target = root / path
        payload = content.replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")
        if not target.is_file() or target.read_bytes() != payload:
            changed[path] = payload
    if check:
        if changed:
            raise CatalogError(
                "Generated outputs are missing or stale: "
                + ", ".join(changed)
                + ". Run .github/scripts/generate_catalog.py"
            )
        return []
    # Prepare payload files only after every metadata, path and marker check.
    # Atomic replacement prevents any individual target being truncated.
    staged = []
    try:
        for path, payload in changed.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".catalog-", delete=False) as temp:
                staged.append((Path(temp.name), target))
                temp.write(payload)
        for temporary, target in staged:
            temporary.replace(target)
    finally:
        for temporary, _target in staged:
            temporary.unlink(missing_ok=True)
    return list(changed)
