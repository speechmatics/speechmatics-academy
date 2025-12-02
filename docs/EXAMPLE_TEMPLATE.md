# Example Template

This document describes the standard structure and content for Academy examples.

## Directory Structure

Every example should follow this structure:

```
example-name/
├── python/
│   ├── main.py             # Primary Python implementation
│   ├── requirements.txt    # Python dependencies
│   ├── config.py           # Configuration (optional)
│   └── README.md           # Python-specific notes (optional)
├── typescript/
│   ├── index.ts            # Primary TypeScript implementation
│   ├── package.json        # Node dependencies
│   ├── tsconfig.json       # TypeScript config
│   └── README.md           # TypeScript-specific notes (optional)
├── .env.example            # Environment variables template
├── assets/                 # Screenshots, sample files, etc.
│   ├── demo.gif
│   └── sample.wav
└── README.md               # Language-agnostic overview (REQUIRED)
```

## Main README.md Template

The main README.md should be language-agnostic and follow this structure:

```markdown
# [Example Title]

[One-line description of what this example does]

## What You'll Learn

- [Key concept 1]
- [Key concept 2]
- [Key concept 3]

## Prerequisites

- Speechmatics API key ([Get one here](https://portal.speechmatics.com/))
- [Any other requirements]

## Quick Start

### Python

```bash
cd python
pip install -r requirements.txt
cp ../.env.example .env
# Add your API key to .env
python main.py
```

### TypeScript

```bash
cd typescript
npm install
cp ../.env.example .env
# Add your API key to .env
npm start
```

## How It Works

[Step-by-step explanation of the code]

1. **[Step 1 Name]**: [Description]
2. **[Step 2 Name]**: [Description]
3. **[Step 3 Name]**: [Description]

## Key Features Demonstrated

- **[Feature 1]**: [Brief explanation]
- **[Feature 2]**: [Brief explanation]
- **[Feature 3]**: [Brief explanation]

## Expected Output

```
[Show sample output]
```

## Next Steps

- Try modifying [X] to [Y]
- Explore [related example link]
- Read more about [feature] in [docs link]

## Troubleshooting

**Issue**: [Common problem]
**Solution**: [How to fix it]

## Resources

- [Speechmatics Docs](https://docs.speechmatics.com)
- [API Reference](https://docs.speechmatics.com/api)
- [Related Example](../other-example/)
```

## Code File Requirements

### Python (main.py)

```python
"""
[Example Title]

[Brief description]
"""

import os
from dotenv import load_dotenv
from speechmatics.batch import AsyncClient, TranscriptionConfig

# Load environment variables
load_dotenv()

async def main():
    """[Function description]"""
    api_key = os.getenv("SPEECHMATICS_API_KEY")

    if not api_key:
        raise ValueError("SPEECHMATICS_API_KEY not set")

    # Your code here
    pass

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
```

### TypeScript (index.ts)

```typescript
/**
 * [Example Title]
 *
 * [Brief description]
 */

import * as dotenv from 'dotenv';
import { BatchClient } from 'speechmatics';

dotenv.config();

async function main(): Promise<void> {
  const apiKey = process.env.SPEECHMATICS_API_KEY;

  if (!apiKey) {
    throw new Error('SPEECHMATICS_API_KEY not set');
  }

  // Your code here
}

main().catch(console.error);
```

## .env.example Template

```bash
# Speechmatics API Key (required)
# Get yours at: https://portal.speechmatics.com/
SPEECHMATICS_API_KEY=your_api_key_here

# Optional: Custom endpoint (for on-premise deployments)
# SPEECHMATICS_URL=https://your-custom-endpoint.com

# Example-specific environment variables
# [Add any example-specific variables here]
```

## requirements.txt Template

```txt
# Speechmatics SDK
speechmatics-batch>=0.5.0

# Environment variables
python-dotenv>=1.0.0

# Example-specific dependencies
# [Add any example-specific dependencies here]
```

## package.json Template

```json
{
  "name": "speechmatics-example-[name]",
  "version": "1.0.0",
  "description": "[Example description]",
  "main": "index.ts",
  "scripts": {
    "start": "ts-node index.ts",
    "build": "tsc",
    "dev": "ts-node-dev --respawn index.ts"
  },
  "dependencies": {
    "speechmatics": "^0.5.0",
    "dotenv": "^16.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0",
    "ts-node": "^10.9.0",
    "ts-node-dev": "^2.0.0"
  }
}
```

## Metadata Entry (index.yaml)

Add your example to `docs/index.yaml`:

```yaml
- id: "your-example-id"
  title: "Your Example Title"
  description: "One-line description"
  category: "basics|integrations|use-cases"
  difficulty: "beginner|intermediate|advanced"
  languages: ["python", "typescript"]
  features:
    - "batch-transcription"
    - "realtime-transcription"
  integrations: []  # Or ["livekit", "pipecat", etc.]
  path: "category/your-example-id"
  readme: "category/your-example-id/README.md"
  tags: ["tag1", "tag2", "tag3"]
  last_updated: "YYYY-MM-DD"
  estimated_time: "X minutes"
```

## Quality Checklist

Before submitting your example:

- [ ] README.md is clear and language-agnostic
- [ ] Both Python and TypeScript implementations work
- [ ] .env.example includes all required variables
- [ ] requirements.txt and package.json are complete
- [ ] Code includes comments explaining key steps
- [ ] Example has been tested end-to-end
- [ ] Screenshots/demo.gif added to assets/ (if applicable)
- [ ] Metadata added to docs/index.yaml
- [ ] No hardcoded API keys or secrets
- [ ] Error handling is demonstrated
- [ ] Code follows SDK best practices

## Best Practices

1. **Keep it simple** - Examples should be easy to understand
2. **Show one thing well** - Focus on a single feature or integration
3. **Use real-world scenarios** - Make examples practical
4. **Include error handling** - Show how to handle common errors
5. **Add helpful comments** - Explain what each section does
6. **Test thoroughly** - Ensure it works before submitting
7. **Be language-agnostic** - Main README shouldn't favor one language
8. **Link to docs** - Reference official documentation where relevant

## Example Naming Convention

- Use **kebab-case** for directory names
- Be **descriptive** but **concise**
- Follow pattern: `[feature]-[context]`

**Good Examples:**
- `voice-agent-basic`
- `fastapi-realtime-transcription`
- `call-center-analytics`

**Bad Examples:**
- `example1`
- `test`
- `my_cool_thing`

## Need Help?

- Check existing examples for reference
- Ask in [Community Discussions](https://github.com/speechmatics/community/discussions/categories/academy)
