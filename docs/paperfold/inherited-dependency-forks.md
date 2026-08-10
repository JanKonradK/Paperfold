# Inherited dependency forks

Milestone 0 action from `plan.md` Section 3.6. Recorded on 2026-08-10 against
`pubspec.yaml`, `pubspec.lock`, and the GitHub API.

## Correction to the plan

`plan.md` Section 3.6 says **four** dependencies point at Anxcye's personal
forks. The true number is **eleven**. Paperfold inherits maintenance of all of
them.

## The full list

| Package | Pinned ref | Resolved commit | Upstream parent | Files in `lib/` | Fate |
|---|---|---|---|---|---|
| `flutter_inappwebview` | `4a275c3` | `4a275c353281` | `pichillilorenzo/flutter_inappwebview` | 8 | **Keep. Load-bearing.** |
| `webdav_client` | **none** | `3c6d0eb21baf` | `flymzero/webdav_client` | 2 | Keep, disabled |
| `contentsize_tabbarview` | `feat/animation` | `def3fab2fdf5` | `Ultranmus/contentsize_tabbarview` | 1 | Keep for now |
| `flutter_tts` | `88d20d28...` | `88d20d282354` | `dlutton/flutter_tts` | 1 | Keep. TTS stays |
| `flutter_heatmap_calendar` | **none** | `c14e6ebb29c2` | `devappmin/flutter_heatmap_calendar` | 1 | Keep for now |
| `share_handler` | `eeaa04d2...` | `eeaa04d22e7e` | `ShoutSocial/share_handler` | 1 | Keep for now |
| `staggered_reorderable` | `2ac799a6...` | `2ac799a6eeb5` | `jingluoguo/staggered_reorderable` | 2 | Keep for now |
| `langchain` | `310fb6b3` | `310fb6b3e9f7` | `Anxcye/langchain_dart` | 1 | **Removed with AI** |
| `langchain_core` | `310fb6b3` | `310fb6b3e9f7` | `Anxcye/langchain_dart` | — | **Removed with AI** |
| `langchain_openai` | `310fb6b3` | `310fb6b3e9f7` | `Anxcye/langchain_dart` | — | **Removed with AI** |
| `langchain_anthropic` | `310fb6b3` | `310fb6b3e9f7` | `Anxcye/langchain_dart` | — | **Removed with AI** |

The four `langchain_*` entries are one repository, `Anxcye/langchain_dart`, at
one commit, imported through four package paths.

## The most important risk: two forks are not pinned

`webdav_client` and `flutter_heatmap_calendar` declare a git URL with **no
`ref`**. They track the default branch.

Why this matters:

1. A new commit on that branch changes the Paperfold build with no change in
   Paperfold. The build is not reproducible.
2. A force-push rewrites what those commits mean.
3. These are personal repositories with one maintainer. There is no review gate.

**Action: pin both to their current resolved commits.** `pubspec.lock` already
records `3c6d0eb21baf` and `c14e6ebb29c2`. Copy them into `pubspec.yaml`.
This is a small edit with a large benefit, and it belongs in Milestone 0.

## Load-bearing rank

1. **`flutter_inappwebview` — 8 files. Cannot be dropped.** It hosts
   foliate-js, so it carries the whole reader. `plan.md` Section 4.2 depends on
   its screenshot method for the page curl. Any move back to the public package
   must be tested against the curl, not only against the reader.
2. `webdav_client` and `staggered_reorderable` — 2 files each.
3. Everything else — 1 file each. A single-file dependency on a personal fork
   is a poor trade. Each is a candidate to replace with the public package or
   with local code.

## Fork activity

No fork is archived. Last push per fork:

| Fork | Last push |
|---|---|
| `flutter_tts` | 2026-01-23 |
| `share_handler` | 2025-12-05 |
| `staggered_reorderable` | 2025-11-14 |
| `flutter_inappwebview` | 2025-09-23 |
| `webdav_client` | 2025-04-13 |
| `flutter_heatmap_calendar` | 2025-01-20 |
| `contentsize_tabbarview` | 2024-05-17 |

`contentsize_tabbarview` has had no push for more than two years, and it is
pinned to a feature branch named `feat/animation`. A feature branch that never
merged is an abandoned change. One file imports it.

## What each fork changes

UNCONFIRMED. This record establishes the inventory, the pins, and the risk.
A diff of each fork against its public parent is a separate task. Do it before
Milestone 9, and start with `flutter_inappwebview`, because it is the one that
cannot be dropped.

## Recommended actions

| Priority | Action | Milestone |
|---|---|---|
| High | Pin `webdav_client` and `flutter_heatmap_calendar` to their resolved commits | 0 |
| High | Delete the four `langchain_*` entries with the AI subsystem | 0 |
| Medium | Diff `flutter_inappwebview` against its parent. Test the curl after any move | 1 |
| Medium | Replace the single-file forks with public packages where the change has merged | 6 |
| Low | Decide whether `contentsize_tabbarview` earns a two-year-old feature branch | 6 |
