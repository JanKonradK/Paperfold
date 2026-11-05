# Paperfold agent instructions

## Ponytail

For code tasks, read `.agents/skills/ponytail/SKILL.md` and apply full mode by
default. Obey an explicit request to change the mode or stop Ponytail.

Read the affected code and its callers before you edit it. Reuse the existing
Dart, Flutter, and project functions before you add code or packages.
Keep required behavior, validation, error handling, security, and accessibility.
Use the project test framework for necessary checks.

The user's requirements take precedence over Ponytail preferences. Keep the
STE writing rules and use Impeccable for interface work. Ponytail does not
authorize a repository audit, code deletion, or a refactor outside the task.

The six skills are in `.agents/skills/ponytail*/SKILL.md`. Claude Code has
identical copies in `.claude/skills/`. See `docs/ponytail.md` for use and source
details. This installation uses skills and instructions, without plugin hooks.
Mode changes apply to the conversation. Environment and global plugin settings
do not control these project instructions.

## Checks

- Use `flutter pub get` if dependencies change.
- Run `dart run build_runner build --delete-conflicting-outputs` if a Riverpod
  source file or a Freezed source file changes.
- Run the relevant tests. For the full suite, use `flutter test --concurrency=1`.
- Preserve unrelated changes in the workspace and the Git index.
