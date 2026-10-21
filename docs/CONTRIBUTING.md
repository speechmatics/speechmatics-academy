# Contributing to Speechmatics Academy

Contribute examples, integrations, bug fixes, or documentation that help developers use Speechmatics. Official examples live in `basics/`, `integrations/`, and `use-cases/`; migration guides live in `guides/`. Community projects have a separate [submission guide](../community/README.md) and [template](../community/COMMUNITY_TEMPLATE.md).

## Before you start

Check the existing examples and [open issues](https://github.com/speechmatics/speechmatics-academy/issues). For a larger example or refactor, open an issue to discuss the scope first. Small fixes can go directly to a pull request.

Use the [example template](EXAMPLE_TEMPLATE.md). Choose one clear learning outcome, the current API or SDK that supports it, and a setup a developer can reproduce from a fresh checkout.

## Adding an example

### Choose a location

| Location | Purpose |
|---|---|
| `basics/NN-name/` | A focused API or SDK feature |
| `integrations/framework/NN-name/` | A third-party framework or service |
| `use-cases/NN-name/` | An application built around a specific workflow |
| `guides/migration-guides/provider/` | A migration guide and supporting code |
| `community/subcategory/project-name/` | A community-maintained project |

Use numbered prefixes for official examples and descriptive kebab-case names. Integration numbering is local to each framework. Community projects do not use numbered prefixes.

Small Python examples usually use this structure:

```text
NN-example-name/
├── python/
│   ├── main.py
│   └── requirements.txt
├── assets/
├── .env.example
└── README.md
```

Use a framework-appropriate structure for web and mobile applications. Existing examples include Python, JavaScript, TypeScript, and Dart. Document the entry point, working directory, package manager, and environment-file location for every implementation.

### Implement the example

- Use the current SDK and its documented configuration and error handling.
- Use asynchronous calls and context managers where the client supports them.
- Close microphone streams, WebSockets, files, and background tasks on success, error, and cancellation.
- Read credentials from environment variables or a documented token service. Commit placeholder values only.
- List all dependencies and the runtime version used to test the example.
- Include or explain how to obtain each required sample asset. Match filename casing exactly.
- Keep the example focused. Explain application-specific logic separately from Speechmatics behavior.

Speechmatics provides transcription and speech synthesis. A voice-agent application also needs conversation logic, an LLM, and any tools it calls. Start new transcription integrations with [agent STT](https://docs.speechmatics.com/speech-to-text/agent-stt); identify examples that retain the [deprecated Voice SDK](https://docs.speechmatics.com/integrations-and-sdks/voice-sdk).

### Write the README

Start with a title and a one-sentence description of what the example does. Include these sections:

1. What you'll learn
2. Prerequisites
3. Quick start
4. How it works
5. Key features demonstrated
6. Expected output
7. Next steps
8. Troubleshooting
9. Resources

Include estimated time, difficulty, APIs used, and navigation links in the footer. Follow the example's actual layout; do not paste commands that assume a different working directory. Give separate PowerShell and macOS/Linux instructions when commands differ. Quote package constraints such as `"package>=1.0,<2"` so shells do not interpret them as redirection.

Distinguish runnable commands from illustrative snippets. Keep snippets consistent with the checked-in implementation, and say when extra setup or code changes are required. Explain known example limitations where they affect the instructions.

### Use documentation terminology

Use the names and distinctions in the [official documentation](https://docs.speechmatics.com/) and [model comparison](https://docs.speechmatics.com/speech-to-text/models):

- **Speech to Text (STT)** and **Text to Speech (TTS)** on first use; **Realtime API** and **Batch API**.
- **Standard**, **Enhanced**, **Melia 1**, **Oak 1**, and **Linden 1** in prose. Preserve literal API values such as `melia-1` in code.
- **agent STT** for the transcription interaction pattern; **Agent STT** at the beginning of a sentence or in a heading. Describe a voice agent as the application built around transcription, an LLM, and speech synthesis.
- **Medical** for the sub-variant of Enhanced. Preserve `domain="medical"` in configuration and distinguish it from the standalone Oak 1 model.
- **custom dictionary**, **smart formatting**, **speaker diarization**, **speaker identification**, **channel diarization**, **API key**, **portal**, **WebSocket**, and **on-prem**.

Define less familiar abbreviations on first use. Use direct instructions, sentence-case prose, and en-US spelling such as "diarization." Link feature names to their official documentation rather than copying large capability tables that will drift.

Verify feature support for the selected model and API. Link current [release notes](https://speechmatics.featurebase.app/en/changelog) for release-sensitive claims. Avoid unsupported performance, pricing, compliance, production-readiness, or availability claims. Keep paths, package names, class names, configuration keys, and event names exact.

### Add catalog metadata

Add an entry to `docs/index.yaml` using the existing schema and update `total_examples`:

```yaml
- id: "your-example-id"
  title: "Your example title"
  description: "One sentence describing the learning outcome."
  category: "basics"
  difficulty: "beginner"
  languages: ["python"]
  features:
    - "batch-transcription"
  integrations: []
  path: "basics/NN-your-example-id"
  readme: "basics/NN-your-example-id/README.md"
  tags: ["batch", "getting-started"]
  last_updated: "YYYY-MM-DD"
  estimated_time: "10 minutes"
```

Use an actual date and existing category, language, feature, and integration identifiers. Keep the root README's example list in sync. The current structure checker does not discover migration guides or arbitrary new integration framework folders, so include those additions explicitly in the review description.

## Testing and local checks

The repository's Python CI runs on **Python 3.12**. Use that version as the default development environment and state any different minimum you have verified. Install each example's dependencies in a separate environment.

Run the repository checks from its root:

```bash
python -m pip install ruff
ruff check .
ruff format --check .
python .github/scripts/check_structure.py
python .github/scripts/check_community_structure.py
```

Ruff configuration is in `ruff.toml`: Python 3.12 target, a 120-character line length, and pycodestyle, pyflakes, and import-order rules. Markdown is excluded from Ruff.

Run the selected example's own tests and build commands, as documented in its README. Existing suites include the Agora backend/frontend tests, Flutter tests, and Oak Consultation Studio's JavaScript/Python tests. They are **not currently run by the root CI workflow**.

Test the documented quick start from a fresh checkout. For a microphone or streaming example, check startup, authentication failure, interruption, and final-transcript handling. For a UI, check that changing a setting changes the request it sends. Keep offline tests separate from live probes that need credentials and may incur usage.

Include the actual commands, results, runtime, and any untested live-service steps in the pull request.

### What CI currently checks

| Job | Current coverage |
|---|---|
| Python Checks | Repository-wide Ruff lint/format and Python syntax |
| JavaScript Checks | Dependency installation and syntax checks for the Voice API Explorer's three JavaScript files |
| Structure & Catalog Check | Catalog paths, README existence, declared count, and selected layout checks; some problems are warnings |
| Dependency Resolution Check | Files named `requirements.txt` on Python 3.12, allowing prereleases; this does not run the applications |
| Community Project Checks | Community structure and a separate warning-only lint step |
| Docker Build | The Vapi example on Linux amd64 |

The repository-wide Python job also includes community code, so Python lint and formatting can currently block community contributions despite the separate warning-only step. JavaScript/TypeScript web builds, Flutter analysis/tests, other Dockerfiles, `pyproject.toml`-only projects, and `requirements-dev.txt` are not covered by the corresponding root jobs. Passing CI does not replace testing the example.

## Pull request process

1. Fork the repository and create a branch from `main`.
2. Make a focused change and run the relevant checks.
3. Commit with a descriptive type prefix.
4. Push to your fork and open a pull request.
5. Explain the problem, resulting behavior, and validation. Address review feedback before merge.

Use `feat/`, `fix/`, `docs/`, or `chore/` for branch names. Commit prefixes are `Feat:`, `Fix:`, `Docs:`, `Chore:`, and `Refactor:`. Keep the first line under 72 characters and add context in the body when needed.

```text
Feat: add a Batch notification example
Fix: close the microphone after a streaming failure
Docs: clarify model support in the multilingual example
```

Required checks must pass before merge. Maintainers review scope, correctness, documentation, and reproducibility; a passing resolver or syntax check alone does not establish runtime compatibility.

### Submission checklist

- [ ] The implementation and README describe the same behavior.
- [ ] Setup works from a fresh checkout with the documented runtime.
- [ ] Dependencies, credentials, environment variables, and assets are documented.
- [ ] Resources are cleaned up on normal exit and failure.
- [ ] Required README sections and navigation links are present.
- [ ] Model and API terminology matches current documentation.
- [ ] Catalog metadata and the root example list are updated where applicable.
- [ ] Relevant checks and existing tests pass; untested steps are disclosed.
- [ ] No credentials or generated private data are committed.

## Adding another language

Use a language-specific directory or the framework's standard layout. Implement the same learning outcome, document the package manager and runtime, add setup and test commands, and update the catalog's `languages` array. Discuss larger ports in an issue before starting.

## Community projects

Community projects can use any language and live under `community/{subcategory}/project-name/`. Include working code, `README.md`, `CONTRIBUTORS.md`, an environment template when credentials are needed, and catalog metadata with `category: "community"`.

Open a [proposal](https://github.com/speechmatics/speechmatics-academy/issues/new?template=community-project-proposal.yml) or submit a pull request directly. Maintainers assign the review tier:

- **Community**: basic structure and a light review of the submitted project.
- **Verified**: full template review, maintainer code review, and end-to-end testing.

Submitting a proposal does not itself grant Verified status. Authors remain the primary maintainers, and projects can be promoted through a follow-up review. See the [community guide](../community/README.md) for the full process.

## Reporting issues and getting help

Include the example path, steps to reproduce, expected and actual behavior, runtime versions, and relevant sanitized logs. Do not include API keys or private audio/transcripts.

- [Report an issue](https://github.com/speechmatics/speechmatics-academy/issues)
- [Ask a question in community discussions](https://github.com/speechmatics/community/discussions/categories/academy)
- Email: devrel@speechmatics.com

Be respectful, welcome new contributors, and help others reproduce problems.

[Back to Academy](../README.md)
