# Community Projects

**Projects built by the Speechmatics community.**

Share projects, tools, and experiments that help other developers build with Speechmatics. Include a reproducible setup and explain which APIs, models, and features the project uses.

## How to Submit

1. **Open a proposal** using the [Community Project Proposal](https://github.com/speechmatics/speechmatics-academy/issues/new?template=community-project-proposal.yml) issue template
2. **Fork the repo** and create your project under the appropriate subcategory
3. **Follow the template** in [COMMUNITY_TEMPLATE.md](COMMUNITY_TEMPLATE.md)
4. **Submit a PR** and a maintainer will review it

> [!TIP]
> You can also submit a PR directly without a proposal. Maintainers review the submission and assign **Community** or **Verified** status based on the review completed.

## Project Categories

| Directory | What goes here |
|-----------|---------------|
| `community/use-cases/` | Domain or industry-specific applications |
| `community/integrations/` | Third-party framework or service integrations |
| `community/tools/` | Utilities, CLI tools, or libraries built on Speechmatics |
| `community/experiments/` | Benchmarks, comparisons, research, and experimental work |

## Quality Tiers

| Tier | Badge | Meaning |
|------|-------|---------|
| **Verified** | ![Verified](https://img.shields.io/badge/Speechmatics_Academy-Verified-green) | Maintainer-audited, fully template-compliant, tested end-to-end |
| **Community** | ![Community](https://img.shields.io/badge/Speechmatics_Academy-Community_Project-blue) | Basic structure, working code, light review by maintainer |

Community projects can be **promoted to Verified** via a follow-up PR that brings the project into full compliance. Exceptional projects may be **graduated** into the official `use-cases/` or `integrations/` categories.

Verified describes the review performed on the submitted version. It does not guarantee compatibility with future SDK releases or establish that an application is ready for production.

The current repository-wide Python checks also run on community code, so Ruff lint and formatting failures can block a pull request. See the [current CI coverage](../docs/CONTRIBUTING.md#what-ci-currently-checks) before submitting.

## Community Projects

> [!NOTE]
> No community projects are currently included. See [How to Submit](#how-to-submit) to add one.

<!-- As projects are added, they will be listed here:
| Project | Category | Description | Language | Author | Status |
|---------|----------|-------------|----------|--------|--------|
-->

## Governance

- **Ownership**: The original author is the primary maintainer of their project
- **Updates**: Other community members can submit PRs to improve existing projects
- **Staleness**: Projects inactive for 12+ months with known issues may be marked stale
- **Deprecation**: Stale projects with no response after 90 days may be deprecated and archived
- **Quarterly review**: Maintainers periodically review, promote, or archive community projects

## Languages

Community projects can use **any language**, including Python, TypeScript, Go, Rust, and C#. See [COMMUNITY_TEMPLATE.md](COMMUNITY_TEMPLATE.md) for directory conventions, and use the [documentation terminology](../docs/CONTRIBUTING.md#use-documentation-terminology) in your README while preserving exact API identifiers in code.

---

## Feedback

- Found an issue? [Report it](https://github.com/speechmatics/speechmatics-academy/issues)
- Have suggestions? [Open a discussion](https://github.com/speechmatics/community/discussions/categories/academy)

---

[Back to Academy](../README.md)
