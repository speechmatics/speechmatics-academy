# Contributing to Speechmatics Academy

Thank you for your interest in contributing to Speechmatics Academy! This document provides guidelines for contributing examples, integrations, and improvements.

## Ways to Contribute

1. **Add New Examples** - Create production-ready examples
2. **Improve Existing Examples** - Fix bugs, add features, improve docs
3. **Add Language Implementations** - Add TypeScript to Python-only examples (or vice versa)
4. **Fix Documentation** - Improve README files, fix typos, clarify instructions
5. **Report Issues** - Report bugs or suggest improvements

## Before You Start

1. **Check existing examples** - Make sure your idea isn't already covered
2. **Open a discussion** - Share your idea in [Community Discussions](https://github.com/speechmatics/community/discussions/categories/academy)
3. **Follow the template** - Use [EXAMPLE_TEMPLATE.md](docs/EXAMPLE_TEMPLATE.md)

## Adding a New Example

### Step 1: Choose a Category

Examples are organized into three categories:

- **basics/** - Fundamental SDK features (5-15 minutes)
- **integrations/** - Third-party framework integrations (15-30 minutes)
- **use-cases/** - Production-ready applications (30+ minutes)

### Step 2: Create Directory Structure

```bash
# For basics or integrations
academy create your-example-name --category basics

# Or manually:
mkdir -p category/your-example-name/{python,typescript,assets}
```

### Step 3: Implement the Example

Follow the structure in [EXAMPLE_TEMPLATE.md](docs/EXAMPLE_TEMPLATE.md):

```
your-example-name/
├── python/
│   ├── main.py
│   ├── requirements.txt
│   └── README.md (optional)
├── typescript/
│   ├── index.ts
│   ├── package.json
│   └── tsconfig.json
├── .env.example
├── assets/
│   └── demo.mp4
└── README.md (required)
```

### Step 4: Test Thoroughly

```bash
# Test Python implementation
cd python
pip install -r requirements.txt
python main.py

# Test TypeScript implementation
cd typescript
npm install
npm start
```

### Step 5: Add Metadata

Add your example to `docs/index.yaml`:

```yaml
examples:
  - id: "your-example-id"
    title: "Your Example Title"
    description: "Clear one-line description"
    category: "basics"
    difficulty: "beginner"
    languages: ["python", "typescript"]
    features: ["batch-transcription"]
    integrations: []
    path: "basics/your-example-id"
    readme: "basics/your-example-id/README.md"
    tags: ["tag1", "tag2"]
    last_updated: "2025-01-14"
    estimated_time: "10 minutes"
```

### Step 6: Create Pull Request

1. Fork the repository
2. Create a feature branch: `git checkout -b add-example-name`
3. Commit your changes: `git commit -m "Add [example name] example"`
4. Push to your fork: `git push origin add-example-name`
5. Open a Pull Request

## Example Quality Standards

All examples must meet these standards:

### Code Quality

- [ ] Code is clean, readable, and well-commented
- [ ] Follows SDK best practices
- [ ] Includes proper error handling
- [ ] No hardcoded secrets or API keys
- [ ] Uses environment variables for configuration

### Documentation

- [ ] Main README.md is clear and language-agnostic
- [ ] Includes "What You'll Learn" section
- [ ] Shows expected output
- [ ] Includes troubleshooting section
- [ ] Links to relevant documentation

### Testing

- [ ] Example has been tested end-to-end
- [ ] Works in both Python and TypeScript (if both provided)
- [ ] Includes .env.example with all required variables
- [ ] Dependencies are clearly listed

### Completeness

- [ ] Includes demo.gif or screenshot (if applicable)
- [ ] Metadata added to docs/index.yaml
- [ ] Follows directory structure template
- [ ] README follows the template format

## Style Guidelines

### Python

- Follow [PEP 8](https://peps.python.org/pep-0008/)
- Use async/await for all Speechmatics API calls
- Include type hints where helpful
- Use `python-dotenv` for environment variables

```python
import os
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, TranscriptionConfig

load_dotenv()

async def main():
    api_key = os.getenv("SPEECHMATICS_API_KEY")
    # Your code here
```

### TypeScript

- Follow [TypeScript best practices](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)
- Use modern ES6+ syntax
- Include proper type definitions
- Use `dotenv` for environment variables

```typescript
import * as dotenv from 'dotenv';
import { BatchClient } from 'speechmatics';

dotenv.config();

async function main(): Promise<void> {
  const apiKey = process.env.SPEECHMATICS_API_KEY;
  // Your code here
}
```

### README Files

- Use clear, concise language
- Include code blocks with syntax highlighting
- Add screenshots/GIFs where helpful
- Link to official documentation
- Be welcoming to beginners

## Adding Language Implementations

If an example only has Python and you want to add TypeScript (or vice versa):

1. Create the language directory (`typescript/` or `python/`)
2. Implement the same functionality
3. Add language-specific README if needed
4. Update main README.md quick start section
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

For small changes, just open a PR. For larger refactoring, open an issue first to discuss.

## Reporting Issues

Found a bug or have a suggestion?

1. Check [existing issues](https://github.com/speechmatics/speechmatics-academy/issues)
2. Open a new issue with:
   - Clear title
   - Example name (if applicable)
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, Python/Node version)

## Code Review Process

After submitting a PR:

1. **Automated checks** run (linting, validation, tests)
2. **Maintainer review** - Usually within 2-3 business days
3. **Feedback** - Address any requested changes
4. **Merge** - Once approved, your PR will be merged

We aim to review PRs quickly, but please be patient during busy periods.

## Community Guidelines

- Be respectful and welcoming
- Help others in discussions
- Assume good intentions


## Questions?

- **General questions**: [Community Academy Discussions](https://github.com/speechmatics/community/discussions/categories/academy)
- **Bug reports**: [GitHub Issues](https://github.com/speechmatics/speechmatics-academy/issues)


## Recognition

Contributors are recognized in:
- Pull request comments
- Release notes
- README acknowledgments

Thank you for contributing to Speechmatics Academy! 🎉
