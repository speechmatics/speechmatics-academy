# Application testing

The [Application Tests workflow](../.github/workflows/application-tests.yml) runs existing application tests on pull requests targeting `main` and pushes to `main`. It complements the repository-wide syntax, formatting, dependency, and catalog checks.

## Automated coverage

| Application | Runtime | Checks |
|---|---|---|
| [Oak Consultation Studio](../use-cases/11-oak-consultation-studio/README.md) | Python 3.12 and Node.js 22 | Node's built-in JavaScript tests; Python configuration and token-service tests |
| [Agora Conversational AI Voice Agent](../integrations/agora/01-conversational-ai-agent/README.md) | Python 3.12, Node.js 22, Bun 1.4.2 | Mocked Python backend tests; Bun frontend tests; API contracts; Next.js production build and type checking |
| [Flutter Mobile Transcription](../use-cases/09-flutter-mobile-transcription/README.md) | Flutter 3.44.8, including Dart 3.12.2 | Dart tests; release web build |

The tests use synthetic credentials, mocked service responses, and local fixtures. No Speechmatics, Agora, or Google credentials need to be added to GitHub Secrets. Dependency installation and builds require network access; Agora's build also downloads its Google Fonts assets. These checks do not exercise microphones, make calls, submit paid transcription jobs, or deploy applications.

## Which changes run which checks?

- Changes inside an application's directory select its tests, including source, tests, dependencies, configuration, and assets. Markdown-only changes do not select application jobs. Flutter's scope is its `flutter/` directory; the adjacent experimental Python agent is separate.
- Changes to Flutter's `flutter/lib/models/lang_catalog.dart` select both Flutter and Oak, because an Oak test compares the shared language catalog.
- Changes to `application-tests.yml`, its selection script, or the script's tests select all three applications.
- A manual **Run workflow** run of **Application Tests** selects all three applications.
- If Git history or event metadata cannot establish the changed files, all three run. Pull requests compare against their merge base; pushes compare their before and after commits. Renames and deletions count as changes.

The workflow starts for documentation-only pull requests too, runs the selection tests, and reports a successful **Application checks** result when no application needs testing. It fails if selection fails, a selected job fails or is cancelled, or a selected job unexpectedly skips. Maintainers can choose this stable check name in branch protection; adding the workflow does not change repository settings.

## Run the checks locally

Use a separate Python 3.12 virtual environment for each Python application. Activate it before installing requirements or running tests. Start each block from the repository root; none requires a real `.env` file.

### Oak Consultation Studio

```bash
cd use-cases/11-oak-consultation-studio
python -m pip install -r requirements.txt
npm test
python -m unittest discover -s tests -p "test_*.py" -v
```

Oak has no npm dependencies and no frontend compilation step. Keep the repository's sibling Flutter directory available: its language catalog is a test input.

### Agora

```bash
cd integrations/agora/01-conversational-ai-agent
bun install --frozen-lockfile --ignore-scripts
python -m pip install -r server/requirements-dev.txt
python -m pytest server/tests -q
bun test
```

The web verification needs a syntactically valid backend URL for its proxy configuration. No backend service needs to be running. In PowerShell:

```powershell
$env:AGENT_BACKEND_URL = "http://127.0.0.1:8000"
$env:NEXT_TELEMETRY_DISABLED = "1"
bun run verify:web
```

In Bash or Zsh:

```bash
AGENT_BACKEND_URL=http://127.0.0.1:8000 NEXT_TELEMETRY_DISABLED=1 bun run verify:web
```

`verify:web` runs prerequisite checks, API contract checks, and the production frontend build. The frozen install preserves `bun.lock`; dependency lifecycle scripts are disabled because this application builds successfully without them.

### Flutter

```bash
cd use-cases/09-flutter-mobile-transcription/flutter
flutter pub get --enforce-lockfile
flutter test --no-pub
flutter build web --release --no-pub
```

Use the pinned Flutter version above to reproduce CI. The committed lockfile requires Dart 3.12 or later and Flutter 3.44 or later; a broadly compatible version in `pubspec.yaml` does not override that lockfile. Update the workflow version deliberately when upgrading dependencies. The web build checks compilation; it does not test Android/iOS packaging or browser audio behavior.

CI installs Flutter from its official Linux x64 archive, verifies the pinned SHA-256 checksum before extraction, and caches the SDK with GitHub's cache action. This setup uses a GitHub-owned action permitted by the repository's allowed-actions policy. When changing Flutter versions, update the version and checksum together using the [official Linux release manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json), then verify the lockfile and run the tests/build with that SDK.

## Extend coverage

When adding a tested application, add a job and its path/dependency rules to [select_application_tests.py](../.github/scripts/select_application_tests.py), then include the job in the final **Application checks** gate. Update the selector regression tests and this guide. Prefer fake clients and local fixtures for routine CI; keep live probes with credentials as a separate, explicit operation.

Run the selector tests from the repository root:

```bash
python -m unittest discover -s .github/tests -p test_application_selection.py -v
```

[Contributing](CONTRIBUTING.md) · [Back to Academy](../README.md)
