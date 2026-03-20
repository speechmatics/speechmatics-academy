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

- [Feature 1] (e.g., batch-transcription, realtime-transcription, voice-agents)
- [Feature 2]

## Prerequisites

- **Speechmatics API Key**: Get one from [portal.speechmatics.com](https://portal.speechmatics.com/)
- **[Language runtime]** (e.g., Python 3.10+, Node.js 18+)
- [Other requirements]

## Quick Start

[Step-by-step setup and run instructions — include platform-specific notes if needed]

## How It Works

[Brief explanation of the architecture or flow]

---

**Difficulty**: Beginner | Intermediate | Advanced

[Back to Community Projects](../) | [Back to Academy](../../../README.md)
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
# Speechmatics API Key (required)
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

## Quality Checklist

Before submitting:

- [ ] README.md includes all 5 required sections
- [ ] CONTRIBUTORS.md is filled in
- [ ] .env.example includes all required variables (no real secrets)
- [ ] Code runs end-to-end
- [ ] Metadata added to `docs/index.yaml`
- [ ] No hardcoded API keys or secrets

## Code Style

- **Python**: We recommend following PEP 8 and passing `ruff check`, but this is not enforced for community projects
- **Other languages**: Follow the language's standard conventions
- Community projects receive **warning-only** lint checks in CI, not blocking errors

---

[Back to Community Projects](README.md) | [Back to Academy](../README.md)
