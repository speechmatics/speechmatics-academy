# Community Project Template

This is a simplified template for community-contributed projects. For official Academy examples, see [EXAMPLE_TEMPLATE.md](../docs/EXAMPLE_TEMPLATE.md).

## Directory Structure

```
community/{subcategory}/your-project-name/
├── python/                    # or typescript/, go/, etc.
│   ├── main.py                # Primary implementation
│   └── requirements.txt       # Dependencies
├── assets/                    # Optional: sample files, images
├── .env.example               # Environment variables template
├── CONTRIBUTORS.md            # Attribution (REQUIRED)
└── README.md                  # Documentation (REQUIRED)
```

**Subcategories:** `use-cases/`, `integrations/`, `tools/`, `experiments/`

> [!NOTE]
> Community projects do **not** use numbered prefixes. Use descriptive kebab-case names: `podcast-transcription`, `discord-bot-stt`, `whisper-vs-speechmatics`.

## Multi-Language Support

Use a language-specific subdirectory matching your implementation:

| Language | Directory | Key files |
|----------|-----------|-----------|
| Python | `python/` | `main.py`, `requirements.txt` |
| TypeScript | `typescript/` | `index.ts`, `package.json`, `tsconfig.json` |
| JavaScript | `javascript/` | `index.js`, `package.json` |
| Go | `go/` | `main.go`, `go.mod` |
| Rust | `rust/` | `main.rs`, `Cargo.toml` |
| C# | `csharp/` | `Program.cs`, `*.csproj` |

## README.md Template

Your project README must include at minimum these 5 sections:

```markdown
# [Project Title]

![Community Project](https://img.shields.io/badge/Speechmatics_Academy-Community_Project-blue)

**[One-line description]**

> Contributed by [@username](https://github.com/username)

## What This Does

[2-3 sentences explaining the project and what problem it solves]

## Speechmatics Features Used

- [Feature 1] (for example, Batch transcription, Realtime transcription, or agent STT; keep catalog identifiers in the metadata)
- [Feature 2]

## Prerequisites

- **Speechmatics API key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **[Language runtime]** (state the version you tested and the minimum required by your dependencies)
- [Other requirements]

## Quick Start

[Step-by-step setup and run instructions — include platform-specific notes if needed]

## How It Works

[Brief explanation of the architecture or flow]

---

**Difficulty**: Beginner | Intermediate | Advanced

[Back to Community Projects](../../README.md) | [Back to Academy](../../../README.md)
```

### Optional Sections

These are encouraged but not required:

- **Expected Output** — Sample output or screenshots
- **Configuration Options** — How to customize behavior
- **Architecture Diagram** — Mermaid diagram for integrations
- **Troubleshooting** — Common issues and solutions
- **Next Steps** — Related examples or extensions

## CONTRIBUTORS.md Template

```markdown
# Contributors

## Original Author

- **Name**: [Your Name]
- **GitHub**: [@username](https://github.com/username)
- **Date**: YYYY-MM-DD

## Contributors

<!-- Add contributors as they contribute -->
```

## .env.example Template

```bash
# Speechmatics API key (required)
# Get yours at: https://portal.speechmatics.com/
SPEECHMATICS_API_KEY=your_api_key_here

# Add any other required keys below
```

## Metadata Entry (index.yaml)

Add your project to `docs/index.yaml` under the `examples:` section:

```yaml
  - id: "your-project-id"
    title: "Your Project Title"
    description: "One-line description"
    category: "community"
    subcategory: "use-cases"           # use-cases | integrations | tools | experiments
    difficulty: "intermediate"
    languages: ["python"]
    features:
      - "batch-transcription"
    integrations: []
    packages: ["speechmatics-batch"]
    apis: ["batch"]
    collections: []
    lifecycle: "current"
    kind: "code"
    order: 100
    demos: []
    path: "community/use-cases/your-project-id"
    readme: "community/use-cases/your-project-id/README.md"
    tags: ["tag1", "tag2"]
    last_updated: "YYYY-MM-DD"
    estimated_time: "X minutes"
    status: "community"
    contributor:
      name: "Your Name"
      github: "your-github-username"
```

Follow the [catalog maintenance guide](../docs/CATALOG_GUIDE.md) to select registered metadata values and regenerate the discovery pages. Community review `status` and implementation `lifecycle` are separate fields.

## Quality Checklist

Before submitting:

- [ ] README.md includes all 5 required sections
- [ ] CONTRIBUTORS.md is filled in
- [ ] .env.example includes all required variables (no real secrets)
- [ ] Code runs end-to-end
- [ ] Metadata added to `docs/index.yaml` and discovery pages regenerated
- [ ] No hardcoded API keys or secrets

## Code Style

- **Python**: Follow PEP 8 and run `ruff check` and `ruff format --check`. The repository-wide Python job currently checks community code too.
- **Other languages**: Follow the language's standard conventions
- The dedicated community lint step is warning-only, but the repository-wide job can still block a pull request. See [current CI coverage](../docs/CONTRIBUTING.md#what-ci-currently-checks).
- Follow the [documentation terminology](../docs/CONTRIBUTING.md#use-documentation-terminology) and preserve exact API identifiers in code.

---

[Back to Community Projects](README.md) | [Back to Academy](../README.md)
