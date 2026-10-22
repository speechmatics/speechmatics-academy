# Maintaining the Academy catalog

The Academy's example metadata lives in [index.yaml](index.yaml). The generator uses it to produce the [complete catalog](CATALOG.md), example tables in the main README and collection pages, and the supplementary [LLM index](../llms.txt). Edit metadata once rather than maintaining the same example in several lookup tables.

Example source directories and their READMEs remain the canonical implementations and run instructions. The generated catalog describes what an example demonstrates; it does not replace its prerequisites, compatibility notes, or code.

## Add or update an example

1. Add the implementation and its README using the [example template](EXAMPLE_TEMPLATE.md).
2. Add or update one entry under `examples` in [index.yaml](index.yaml). Preserve the example's stable `id` when its title changes.
3. Run the generator from the repository root:

   ```bash
   python -m pip install -r .github/requirements-catalog.txt
   python .github/scripts/generate_catalog.py
   ```

4. Review the metadata and generated changes together. Include the generated files in the same pull request as the example.
5. Run the validation commands below. Generation does not commit, push, or publish anything.

The number of examples is derived from the entries. There is no manually maintained `total_examples` value.

## Metadata conventions

The machine-readable contract is [catalog.schema.yaml](catalog.schema.yaml). Cross-references and repository paths are also checked by the validator.

| Field | Meaning |
|---|---|
| `id` | Stable example identity, independent of its display title or numbered directory. |
| `path` / `readme` | Canonical repository-relative source directory and guide. Keep existing paths stable; an override README must exist. |
| `description` | A short, self-contained description naming the example's purpose and relevant Speechmatics capability. |
| `summary` | Optional compact outcome used in hub and catalog lookup tables. Keep the full API, model, and compatibility context in `description`; the renderer falls back to it if no summary is supplied. |
| `category` | The existing physical category. An example can belong to several discovery collections without moving its code. |
| `packages` | SDKs or adapters directly demonstrated by the example, not a dump of transitive dependencies. An empty list is appropriate for direct HTTP/WebSocket or configuration-only examples. |
| `apis` | The Speechmatics API surfaces used by the example. The older preview protocol is distinct from current agent STT. |
| `languages` | Authored implementation languages in this repository. Use `config` for a configuration guide rather than attributing the upstream application's language to it. |
| `integrations` | Explicit framework, platform, or service membership from the registry. Free-form tags do not imply integration membership. |
| `collections` | Cross-cutting topics such as healthcare, multilingual, or telephony. Membership can overlap. |
| `lifecycle` | Whether this implementation is current, legacy, or preview. This is separate from a community project's review status. |
| `demos` | Typed links for a hosted application, recorded walkthrough, or local run instructions, with a short access/requirements description. |
| `demo_note` | Optional material access or behavior note for hub readers, such as preview access, a paid provider request, or calendar changes. Balanced backtick code spans can identify literal API values or paths; other Markdown and HTML remain literal. Generic setup advice belongs in the example guide; full descriptions remain attached to each demo in the detail records. |
| `models` | Optional literal API model IDs when the implementation demonstrates them. Do not infer complete model compatibility from a shared API. |
| `order` | Presentation order. Folder numbering is not used as an implicit learning sequence. |
| `last_updated` | Date the example metadata/content was updated; not a claim that every live workflow was tested on that date. |

Shared registries define readable labels, integration logos, and documentation URLs. An API registry entry may omit `url` when no independent API reference exists; its name remains in detailed records, but it is omitted from hub API-reference links. Do not substitute an example's own README as an API reference. Use the canonical terminology in the [contribution guide](CONTRIBUTING.md#use-documentation-terminology). Keep technical IDs and package names exact.

## Authored guidance and generated sections

The main README and collection pages retain authored introductions, recommended starting points, learning paths, logos, and supporting links. Only content between these markers is replaced:

```markdown
<!-- BEGIN GENERATED: examples -->
<!-- END GENERATED: examples -->
```

The root README uses `basics`, `integrations`, and `use-cases` as its block names. A hub uses `examples`. Keep exactly one matching pair for each required block. Changes outside those blocks are preserved; missing or ambiguous markers stop generation.

The main README shows each integration or focus once. Integration rows start from the primary platforms represented in the `integrations` category; service providers used alongside them remain discoverable in the full catalog. Focus rows use the collections represented in `use-cases`. Each row's example count and languages include all matching entries across the Academy, regardless of where their code lives. Membership can overlap, so adding the row counts does not give the number of unique examples.

Groups link to a hub README when the registry supplies one. A group with one example can link directly to its guide; a group with multiple examples and no hub links to its catalog section. Add a hub when a group benefits from a starting point, workflow guidance, and links to related collections. Integration registry descriptions supply the main table's short summaries.

For example, the Healthcare hub is selected by `collections: [healthcare]`; the LiveKit hub is selected by `integrations: [livekit]`. Their registry entries supply `readme` and `start_here`. The Pipecat, Twilio, Telephony, Multilingual, Voice agents, and Captions and insights hubs use the same mechanism. A source example can appear in several hubs without duplicating its code or setup instructions.

Fundamentals and hub tables use compact summaries and consistent `Legacy` and `Preview` markers; full descriptions and lifecycle values stay in detailed records. Hubs retain SDK/adapter links, language and difficulty labels, and demo-type links. Material `demo_note` values appear below the table in displayed example order, with API references listed once per hub. A hub registry can set `group_by_lifecycle: true` to separate current examples from legacy and preview references. The Voice agents hub uses this layout.

Empty catalog groups are omitted from display while their vocabulary values remain available for new examples. Compatibility notes follow the actual API membership: an example using a preview Realtime endpoint does not automatically use the separate legacy Voice API preview protocol.

`docs/CATALOG.md` and `llms.txt` are generated as complete files. Do not hand-edit them. The catalog includes lookup tables and self-contained example sections with stable ID anchors, so readers can understand an individual result without finding a distant table heading.

## Validate locally

Run these commands from the repository root after installing the catalog requirements:

```bash
python .github/scripts/generate_catalog.py --validate-only
python .github/scripts/generate_catalog.py --check
python .github/scripts/check_structure.py
python -m unittest discover -s .github/tests -v
```

`--check` is read-only: it reports stale or missing generated content without rewriting files. CI runs the checks on a pull request. It does not update files automatically or publish a site.

Validation checks the YAML/schema, unique IDs and paths, registered values, referenced files, and example coverage. Generated output is deterministic so a metadata change produces a reviewable diff. Live APIs and demo applications are not executed by these checks.

## GitHub and LLM retrieval

Discovery content is available as ordinary Markdown, without JavaScript rendering or image-only navigation. Descriptive headings, explicit API names, language/package labels, and nearby compatibility and demo requirements make individual sections useful when retrieved separately. Screenshots and recordings supplement the written description.

The root `llms.txt` is a supplementary link index with canonical GitHub URLs. Its prose preserves raw identifiers and punctuation; Markdown link labels use backslash escapes where needed, and URL destinations retain percent encoding. Markdown table escaping is separate, so raw retrieval does not require decoding generated HTML entities. It is not an agent instruction file, an ingestion configuration, or evidence that a retrieval service has indexed the repository. Its links refer to the intended published `main` version; new local pages will be available there only after maintainers choose to publish them.
