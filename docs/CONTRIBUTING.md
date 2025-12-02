# Contributing to Speechmatics Academy

Thank you for your interest in contributing to Speechmatics Academy! This document provides guidelines for contributing examples, integrations, and improvements.

## Ways to Contribute

1. **Add New Examples** - Create examples demonstrating Speechmatics features
2. **Improve Existing Examples** - Fix bugs, add features, improve documentation
3. **Add Language Implementations** - Add TypeScript/C# to Python-only examples (coming soon)
4. **Fix Documentation** - Improve README files, fix typos, clarify instructions
5. **Report Issues** - Report bugs or suggest improvements

## Before You Start

1. **Check existing examples** - Make sure your idea isn't already covered
2. **Open a discussion** - For larger examples, share your idea first via [GitHub Issues](https://github.com/speechmatics/speechmatics-academy/issues)
3. **Follow the template** - Use [EXAMPLE_TEMPLATE.md](EXAMPLE_TEMPLATE.md)

## Adding a New Example

### Step 1: Choose a Category

Examples are organized into three categories:

| Category | Purpose | Typical Time |
|----------|---------|--------------|
| **basics/** | Fundamental SDK features | 5-15 minutes |
| **integrations/** | Third-party framework integrations | 15-30 minutes |
| **use-cases/** | Industry-specific applications | 20-30 minutes |

### Step 2: Create Directory Structure

```bash
# Create the example directory
mkdir -p category/XX-your-example-name/python
mkdir -p category/XX-your-example-name/assets
```

Use **numbered prefixes** (`01-`, `02-`, etc.) to maintain ordering within categories.

Your structure should look like:

```
XX-your-example-name/
├── python/
│   ├── main.py             # Primary implementation
│   ├── requirements.txt    # Dependencies
│   └── .gitignore          # Ignore venv/, __pycache__/, .env
├── assets/                 # Sample files (audio, images, agent prompts)
│   └── sample.wav
├── .env.example            # Environment variables template
└── README.md               # Main documentation (REQUIRED)
```

> [!NOTE]
> TypeScript and C# implementations are coming soon. For now, focus on Python.

### Step 3: Implement the Example

Follow the detailed structure in [EXAMPLE_TEMPLATE.md](EXAMPLE_TEMPLATE.md).

**Key requirements:**
- Use async/await pattern with context managers
- Include error handling for `AuthenticationError`
- Follow PEP 8 style guidelines
- No hardcoded API keys

### Step 4: Write the README

Your README.md must include:

1. **Title** with bold one-line description
2. **What You'll Learn** section
3. **Prerequisites** section
4. **Quick Start** with platform-specific setup (Windows/Mac/Linux)
5. **How It Works** explanation
6. **Expected Output**
7. **Troubleshooting** section
8. **Footer** with Time/Difficulty/API Mode

Use GitHub-flavored callouts for important information:

```markdown
> [!NOTE]
> Useful information users should know.

> [!TIP]
> Helpful advice for doing things better.

> [!IMPORTANT]
> Key information users need to know.

> [!WARNING]
> Urgent info that needs immediate user attention.

> [!CAUTION]
> Advises about risks or negative outcomes.
```

### Step 5: Test Thoroughly

```bash
# Create and activate virtual environment
cd python
python -m venv venv

# Windows:
venv\Scripts\activate

# Mac/Linux:
source venv/bin/activate

# Install and test
pip install -r requirements.txt
cp ../.env.example .env
# Add your API key to .env
python main.py
```

### Step 6: Add Metadata

Add your example to `docs/index.yaml`:

```yaml
- id: "your-example-id"
  title: "Your Example Title"
  description: "Clear one-line description"
  category: "basics"
  difficulty: "beginner"
  languages: ["python"]
  features:
    - "batch-transcription"
  integrations: []
  path: "basics/XX-your-example-id"
  readme: "basics/XX-your-example-id/README.md"
  tags: ["tag1", "tag2"]
  last_updated: "2025-12-02"
  estimated_time: "10 minutes"
```

### Step 7: Create Pull Request

1. Fork the repository
2. Create a feature branch: `git checkout -b add-example-name`
3. Commit your changes: `git commit -m "Add [example name] example"`
4. Push to your fork: `git push origin add-example-name`
5. Open a Pull Request

## Example Quality Standards

All examples must meet these standards:

### Code Quality

- [ ] Code is clean, readable, and well-commented
- [ ] Follows PEP 8 style guidelines
- [ ] Uses async/await pattern
- [ ] Includes proper error handling
- [ ] No hardcoded secrets or API keys
- [ ] Uses environment variables for configuration

### Documentation

- [ ] Main README.md follows the template structure
- [ ] Includes "What You'll Learn" section
- [ ] Has platform-specific setup (Windows/Mac/Linux)
- [ ] Shows expected output
- [ ] Includes troubleshooting section
- [ ] Has footer with Time/Difficulty/API Mode
- [ ] Links to relevant documentation

### Testing

- [ ] Example has been tested end-to-end
- [ ] Works with a fresh virtual environment
- [ ] Includes .env.example with all required variables
- [ ] Dependencies are correctly listed in requirements.txt

### Completeness

- [ ] Metadata added to docs/index.yaml
- [ ] Follows directory structure template
- [ ] Uses numbered prefix for ordering (e.g., `01-`, `02-`)
- [ ] README follows the template format

## Style Guidelines

### Python

- Follow [PEP 8](https://peps.python.org/pep-0008/)
- Use async/await for all Speechmatics API calls
- Include type hints where helpful
- Use `python-dotenv` for environment variables
- Place imports at top (stdlib → third-party → local)

```python
#!/usr/bin/env python3
"""
Example Title

Brief description of what this example demonstrates.
"""

import asyncio
import os
from pathlib import Path

from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, AuthenticationError

load_dotenv()


async def main():
    """Function description."""
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    try:
        async with AsyncClient(api_key=api_key) as client:
            # Your code here
            pass

    except (AuthenticationError, ValueError) as e:
        print(f"\nError: {e}")


if __name__ == "__main__":
    asyncio.run(main())
```

### README Files

- Use clear, concise language
- Include code blocks with syntax highlighting
- Use GitHub-flavored callouts (`> [!NOTE]`, `> [!TIP]`, etc.)
- Add screenshots/GIFs where helpful
- Link to official documentation
- Be welcoming to beginners

## Adding Language Implementations

> [!NOTE]
> TypeScript and C# support is coming soon. If you'd like to contribute implementations in these languages, please open an issue first to discuss.

When adding a new language to an existing example:

1. Create the language directory (`typescript/` or `csharp/`)
2. Implement the same functionality as Python
3. Add language-specific README if needed
4. Update main README.md Quick Start section
5. Update `languages` array in `docs/index.yaml`
6. Test thoroughly

## Improving Existing Examples

Small improvements are always welcome:

- Fix typos or unclear instructions
- Update dependencies
- Add missing error handling
- Improve code comments
- Add screenshots/demos
- Fix bugs
- Update to use GitHub callouts

For small changes, just open a PR. For larger refactoring, open an issue first to discuss.

## Reporting Issues

Found a bug or have a suggestion?

1. Check [existing issues](https://github.com/speechmatics/speechmatics-academy/issues)
2. Open a new issue with:
   - Clear title
   - Example name (if applicable)
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, Python version)

## Code Review Process

After submitting a PR:

1. **Automated checks** run (linting, validation)
2. **Maintainer review** - Usually within 2-3 business days
3. **Feedback** - Address any requested changes
4. **Merge** - Once approved, your PR will be merged

We aim to review PRs quickly, but please be patient during busy periods.

## Community Guidelines

- Be respectful and welcoming
- Help others in discussions
- Assume good intentions


## Questions?

- **General questions**: [GitHub Discussions](https://github.com/speechmatics/community/discussions/categories/academy)
- **Bug reports**: [GitHub Issues](https://github.com/speechmatics/speechmatics-academy/issues)
- **Email**: devrel@speechmatics.com

## Recognition

Contributors are recognized in:
- Pull request comments
- Release notes
- README acknowledgments

Thank you for contributing to Speechmatics Academy!

---

[Back to Academy](../README.md)
