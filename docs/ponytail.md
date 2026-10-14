# Ponytail in Paperfold

Ponytail supplies instructions for code agents. It is a development tool.
It adds no Flutter package or application feature.

## Use

The project instructions select full mode for code tasks. To change the mode,
tell the agent `Use Ponytail lite` or `Use Ponytail ultra`.
To stop the mode, say `stop ponytail`.

The skills will be available on the next Codex turn. If an existing Claude Code
session does not show the skills, start a new session in this directory.

Use these skill names in a request. Claude Code also accepts the slash commands.

| Skill | Function |
| --- | --- |
| `ponytail` | Select the simplest correct implementation. |
| `ponytail-review` | Review the current diff for unnecessary complexity. |
| `ponytail-audit` | Review the repository for unnecessary complexity. |
| `ponytail-debt` | List the deliberate shortcuts in `ponytail:` comments. |
| `ponytail-gain` | Show the upstream benchmark figures. |
| `ponytail-help` | Show the upstream command reference. |

Example: `Use ponytail-review on the current diff`.
The review and audit skills report findings. They do not apply changes.

This installation has no lifecycle hooks or global configuration. Mode changes
apply to the conversation. The plugin configuration and update commands in the
upstream help skill do not apply to this installation.

The gain skill contains older benchmark figures. The upstream README gives
newer results and their limits. These figures do not measure Paperfold.

## Source

- Repository: [DietrichGebert/ponytail](https://github.com/dietrichgebert/ponytail).
- Version: `4.9.0`.
- Commit: `356918eba965ee1eac64bd3a7f0dd02108350de5`.
- Canonical copies: `.agents/skills/ponytail*/SKILL.md`.
- Claude Code copies: `.claude/skills/ponytail*/SKILL.md`.
- License: [MIT](../.agents/skills/ponytail/LICENSE).

All six skill files match this upstream commit. Each skill directory contains
the upstream license. The project instructions are specific to Paperfold.

To update, review the new upstream commit first. Replace both sets of skill
files from that commit. Keep the license files and update the version and
commit above. Confirm that both sets of skill files are identical.
