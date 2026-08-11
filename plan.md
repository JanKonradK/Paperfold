# Paperfold — project plan

> Living document. Change it freely. Nothing is locked until Milestone 1 ends.
> Text follows ASD-STE100 Issue 9 (Strict STE). Code identifiers stay unchanged.
> Research date: 2026-08-09. Version numbers are correct on that date.
> **Revision 2 (2026-08-09): stack changed from Expo to Flutter. The project now
> starts as a fork of Anx Reader.**
> Revision 1 (the Expo plan) is kept at
> `C:\Users\ADA\.claude\plans\i-am-starting-this-synchronous-tiger.md`.
> There is no git history yet — Milestone 0 creates the repository.

---

## 1. Context

You start a book journal, reader, and note application. The slides give the concept:
a personal reading journal that opens and turns pages like a real book.

The project directory holds only tool configuration and this plan.
There is no product code and no git repository yet.

**Your decisions:**

| Decision | Choice | Date |
|---|---|---|
| Version 1 scope | Journal **plus** EPUB and PDF reader | 2026-08-09 |
| Text-to-speech | **Remove it completely.** Supersedes Section 3.3.2 | 2026-08-10 |
| Milestone 1 gate | **Go. The reader curls too.** See `docs/paperfold/milestone-1-gate.md` | 2026-08-11 |
| Page turn | Build the real curl | 2026-08-09 |
| Research delegation | Add Luna to the allowlist, then run a deeper pass | 2026-08-09 |
| ~~Stack~~ | ~~Expo (React Native)~~ — **superseded** | 2026-08-09 |
| **Stack** | **Flutter. Fork `anxcye/anx-reader`.** | 2026-08-09 |

**Why the stack changed.** You chose the fastest route to a working reader, so
that your time goes to design and journal features instead of to an EPUB engine.
That is a valid trade. Section 3.5 states plainly what the fork does not give you.

---

## 2. Market research — what exists

Method: F-Droid catalog, GitHub API, npm registry, pub.dev. Primary sources only.
Search engines returned advertisements, so I did not use them.

### 2.1 The market splits in two, and nothing bridges it

**Readers — mature and strong**

| Application | Stars | Stack | License | Last push |
|---|---|---|---|---|
| KOReader | 28,846 | Lua | AGPL-3.0 | 2026-08-09 |
| Anx Reader | 8,658 | Flutter | MIT | 2026-06-07 |
| Book's Story | 1,348 | Kotlin + Compose | GPL-3.0 | 2026-02-20 |
| Librera Reader | — | Java | GPL-3.0 | active |

**Trackers — weak, small, or self-hosted**

| Application | Stars | Stack | License | Last push |
|---|---|---|---|---|
| Openreads | 1,601 | Flutter | GPL-2.0 | 2026-07-20 |
| Jelu (self-hosted) | 726 | Kotlin + Vue | MIT | 2026-07-31 |
| Tome (needs Calibre) | 76 | TypeScript | MIT | 2026-06-11 |

Below Openreads the field collapses. GitHub topics `book-tracker` and
`reading-tracker` hold 87 and 78 repositories. Almost all have fewer than
40 stars and one contributor.

### 2.2 What nobody does — your opening

1. **No emotional design.** Every tracker is a list, a grid, or a spreadsheet.
2. **Notes are second-class.** Readers keep highlights. Trackers keep star ratings.
   Almost nothing gives you a free page for your own thoughts.
3. **No true book metaphor.** Nothing in this list turns pages like paper.
4. **Reader and journal stay apart.** You read in one application, record in another.
5. **Weak first run.** Most start with an empty list and a plus button.

**Thesis:** make the journal the product, and make it feel like paper.
The fork gives you column one for free. Your work is to add what column two
cannot do, and to make it look like nothing in either column.

### 2.3 The page-turn problem — no library exists anywhere

| Option | State | Verdict |
|---|---|---|
| `page-flip` (StPageFlip), npm | v2.0.7, published 2021-04-18 | Mature, but web only |
| `page_flip`, pub.dev (Flutter) | v0.2.5+1, 180 likes, **98 downloads** | Effectively dead |
| Anx Reader's own `PageTurnMode` | `simple` and `custom` only. `custom` = tap zones | **Not a curl** |
| `erayakartuna/pdf-flipbook` (Java) | 451 stars, last push 2024-01-18 | Reference only |

You build the curl. The fork does not change this.

### 2.4 Distribution risk — confirm this early

The Book's Story README carries this notice, quoted from the repository:

> Starting in September 2026, Android will require all apps to be registered by
> verified developers in order to be installed on certified Android devices.

Source: `https://github.com/Acclorite/book-story`, which links to
`https://keepandroidopen.org/`.

This is a claim by that project's author. It is **not** verified against Google.
**Action in Milestone 0:** confirm it in Google's official documentation.

---

## 3. The fork — what you get and what you must do

Upstream: `https://github.com/anxcye/anx-reader`
License: **MIT, Copyright (c) 2025 Anxcye**. Version 1.14.0+6321. Flutter SDK `>=3.5.2 <4.0.0`.
Size: 915 files. 399 Dart files, 1.79 MB of Dart.

### 3.1 What you get — the reason to fork

- **`assets/foliate-js/`** — the reader engine. MIT, upstream `johnfactotum/foliate-js`
  (1,061 stars). Supports EPUB, MOBI, KF8/AZW3, FB2, CBZ, and PDF through PDF.js.
  Includes `paginator.js` (45.6 KB), `epubcfi.js`, and `overlayer.js` for highlights.
- **A working database** at schema version 7, with a migration path.
- **Reading-time statistics**, bookmarks, table of contents, and a search index.
- **Six platform targets already built**: `android/`, `ios/`, `windows/`, `macos/`,
  `linux/`, `ohos/`. This answers "PC later" on day one, which Expo could not.

### 3.2 The existing schema — build the journal on top of it

```sql
tb_books        id, title, cover_path, file_path, last_read_position,
                reading_percentage, author, is_deleted, description,
                create_time, update_time
tb_notes        id, book_id, content, cfi, chapter, type, color,
                create_time, update_time
tb_reading_time id, book_id, date, reading_time
tb_groups       id, name, parent_id, is_deleted, create_time, update_time
tb_themes       id, background_color, text_color, background_image_path
tb_styles       id, font_size, font_family, line_height, ...
```

`currentDbVersion = 7` in `lib/dao/database.dart`.

**Important:** `tb_notes` is anchored to a CFI. It is a *highlight* table, not a
journal. Your dot pages and reviews are book-level, not location-level.
Add them as **migration version 8**. Do not overload `tb_notes`.

```sql
-- migration v8, new tables. Fields come from the review reference sheet.
tb_reviews    id, book_id,
              genre, format,              -- format: physical | ebook | audio
              rating_overall, rating_plot, rating_ending,
              rating_world, rating_characters, rating_spice,
              favorite_character, favorite_quote, thoughts,
              create_time, update_time
tb_journal    id, book_id, page_index, body, create_time, update_time
tb_shelves    id, name, sort_order        -- or reuse tb_groups
tb_challenge  id, year, target_count      -- the 100-book challenge
tb_wishlist   id, title, author, bought, sort_order, create_time
              -- "Books I want to buy" is NOT the to-be-read list. Keep it apart.
tb_daily_read id, date, pages_read        -- the circular month tracker
tb_catalogs   id, name, url, auth_type, username, sort_order, create_time
              -- OPDS. Section 9. Add it now, use it in Milestone 7.
              -- Never store the password here. Use the platform keystore.
```

All six ratings are 0-5. `rating_spice` uses the chili mark, not stars.
Store the number. The mark is a view choice, not data.

`tb_books` has no reading status column. Add `status`, `started_on`, and
`finished_on` in the same migration, or the to-be-read list cannot work.
`tb_reading_time` already stores minutes per day. `tb_daily_read` stores
*pages* per day, which the circular tracker needs. They are different measures.

### 3.3 What to remove, keep, and rework

| Subsystem | Paths | Size | Action |
|---|---|---|---|
| AI | `lib/service/ai`, `lib/widgets/ai`, `lib/enums/ai_*`, `lib/providers/ai_*` | 246 KB | **Remove** |
| In-app purchase | `lib/service/iap`, `lib/page/iap_page.dart`, `lib/providers/iap.dart` | 54 KB | **Must remove** |
| Text-to-speech | `lib/service/tts`, `lib/widgets/reading_page/tts_*` | 77 KB | **Remove.** Decision 2026-08-10. See 3.3.2 |
| Translate | `lib/service/translate` | 24 KB | **Keep.** See 3.3.1 |
| Settings | `lib/page/settings_page` | 204 KB | **Keep the function. Rebuild the interface.** |
| Locales | 15 languages in `lib/l10n` | 830 KB | **Keep all. Add Polish.** See 3.4 |

**The IAP removal is not optional.** Those product identifiers belong to Anxcye's
developer account. Shipping them in your build is broken at best.

#### 3.3.1 Translate depends on AI — remove them in the right order

`lib/service/translate` has six backends:

```
ai.dart            2.6 KB   <-- imports the AI service you are removing
deepl.dart         4.0 KB
google_api.dart    3.2 KB
microsoft_api.dart 3.6 KB
web_view.dart      3.9 KB
index.dart         6.9 KB   <-- the dispatcher, lists every backend
```

**Deleting `lib/service/ai` breaks the build through `translate/ai.dart`.**
Order the work:

1. Delete `translate/ai.dart`.
2. Remove its entry from `translate/index.dart`.
3. Build. Confirm translate still works with the other backends.
4. Only then delete `lib/service/ai`.

The remaining five backends are self-contained. DeepL, Google, and Microsoft
need user API keys. `web_view.dart` needs none, so make it the default.

#### 3.3.2 ~~Keep TTS, but decide which backends~~ — SUPERSEDED 2026-08-10

> **This section no longer applies. Text-to-speech is removed completely.**
>
> Decision on 2026-08-10: remove the whole subsystem, not only the online
> backends. The factory does not stay.
>
> **What this gains.** `flutter_tts` is one of the personal forks in Section 3.6.
> Removing TTS drops it, so the inherited fork count falls from 7 to 6.
> No book text can leave the device through a voice service.
>
> **What this costs, stated plainly.** Read-aloud is an accessibility feature.
> Removing it shuts out users who depend on listening instead of reading.
> If Paperfold adds voice later, it starts from nothing, because the factory
> abstraction goes too.
>
> The text below is kept for the record. Do not act on it.

TTS has a clean factory with pluggable backends:

```
system_tts.dart          7.3 KB   offline, free, no key
online_tts.dart         14.2 KB
azure_tts_backend.dart   5.3 KB   needs an Azure key
openai_tts_backend.dart  5.9 KB   needs an OpenAI key
aliyun/                 30.6 KB   needs an Alibaba Cloud key
tts_factory.dart         1.3 KB   the abstraction. Keep this.
```

**Recommendation: ship `system_tts` only in version 1.** Keep the factory, so
online voices return later without a rewrite.

Reasons: the online backends send the book text to a third party, which fights
your local-first position. They need keys most users will not have.
And `openai_tts_backend.dart` may share code with the AI service you are removing
— check it during step 4 above.

~~**Keeping TTS keeps a liability.**~~ Superseded. Removing TTS drops
`flutter_tts`, one of the personal forks in Section 3.6.

### 3.4 Locales

Fifteen languages ship in the fork:

```
ar  de  en  es  fr  it  ja  ko  pt  ro  ru  tr  zh-CN  zh-TW  zh-LZH
```

**Keep all fifteen.** `l10n.yaml` already sets `use-deferred-loading: true`,
so locale bundles load on demand, not at startup. **The count costs almost
nothing at runtime.** The cost is translation upkeep, not performance.

**Polish is not in the fork.** Neither is Hindi, Bengali, nor Urdu.
Against the ten most-spoken languages, the fork covers seven:

| Rank | Language | In fork |
|---|---|---|
| 1 | English | yes |
| 2 | Mandarin Chinese | yes |
| 3 | Hindi | **no** |
| 4 | Spanish | yes |
| 5 | Arabic | yes |
| 6 | French | yes |
| 7 | Bengali | **no** |
| 8 | Portuguese | yes |
| 9 | Russian | yes |
| 10 | Urdu | **no** |

**Add `app_pl.arb`.** It is about 48 KB of strings, translated from `app_en.arb`.
Add Hindi, Bengali, and Urdu only when you can get real translations.
Machine translation of 1,000 interface strings reads badly and is hard to fix later.

`docs/untranslated_messages.txt` is already generated by the build. Watch it.

#### 3.4.1 Arabic means the book must open the other way

This is a design constraint, not a translation task.

Arabic is right-to-left. **A right-to-left book opens from the other side and its
pages turn the other way.** The curl in Section 7 must mirror with the text
direction. A left-to-right curl in an Arabic interface looks broken.

Build the shader with a direction parameter from the first version. Retrofitting
a mirrored curl is much harder than planning for one.

`lib/enums/writing_mode.dart` exists in the fork, and `zh-LZH` is Literary Chinese,
so vertical writing may also be in play. Check what that enum drives before you
touch the reader layout.

### 3.5 What the fork does not give you

State this plainly, because it sets Milestone 1:

1. **No page curl.** `PageTurnMode` is `simple` or `custom`, and `custom` means
   custom tap zones. See `lib/widgets/reading_page/more_settings/page_turning/`.
2. **No journal.** No dot pages, no reviews, no shelves, no reading challenge.
   This is your whole product, and none of it exists.
3. **No visual world.** Material 3 with `flex_color_scheme`. Your classic book
   design replaces it completely.

### 3.6 Inherited liabilities — know these before you commit

~~**Four dependencies point at Anxcye's personal forks**~~ — **corrected
2026-08-10: there are eleven, not four.**

The full inventory, with resolved commits and load-bearing rank, is in
`docs/paperfold/inherited-dependency-forks.md`. Summary:

```yaml
flutter_inappwebview:      Anxcye/flutter_inappwebview   ref: 4a275c3
webdav_client:             Anxcye/webdav_client          ref: NONE  <-- unpinned
contentsize_tabbarview:    Anxcye/contentsize_tabbarview ref: feat/animation
flutter_tts:               Anxcye/flutter_tts            ref: 88d20d28...
flutter_heatmap_calendar:  Anxcye/flutter_heatmap_calendar ref: NONE <-- unpinned
share_handler:             Anxcye/share_handler          ref: eeaa04d2...
staggered_reorderable:     Anxcye/staggered_reorderable  ref: 2ac799a6...
langchain, langchain_core, langchain_openai, langchain_anthropic:
                           Anxcye/langchain_dart         ref: 310fb6b3
```

The four `langchain_*` entries left with the AI subsystem, and `flutter_tts`
left with TTS. **Six forks remain.**

**Two forks carry no `ref` at all.** `webdav_client` and
`flutter_heatmap_calendar` track the default branch of a single-maintainer
repository, so the build is not reproducible and a force-push changes it
silently. Pin both to the commits `pubspec.lock` already resolves.

`flutter_inappwebview` is load-bearing and cannot be dropped. It hosts
foliate-js, so it carries the whole reader, and Section 4.2's capture path
runs through its screenshot method.

**Action in Milestone 0:** pin the two unpinned forks. Recording why each fork
exists is done for the inventory; the per-fork diff against upstream is
deferred to Milestone 6.

**Rebranding is manual.** `rename.sh` in the repository only renames built APK
files. It does not rename the project. The Dart package is `anx_reader`, so
`package:anx_reader/...` appears in every one of the 399 Dart files.
Plan a single mechanical rename commit, separate from all feature work.

**Assets:** 100 PNG files (35 MB) and 17 JPG files (7 MB) are Anx Reader branding.
Two `.otf` fonts (2.4 MB) ship in the repository — **check their licenses**.

### 3.7 License duty

MIT permits the fork, the rebrand, and closed source. Two duties:

1. Keep the `LICENSE` file and the `Copyright (c) 2025 Anxcye` notice.
2. Do not imply that Anxcye endorses Paperfold. Say in your README that
   Paperfold is a fork of Anx Reader, and link upstream.

`assets/foliate-js/` carries its own MIT notice. Keep it too.

### 3.8 Git strategy

Keep the upstream remote. You want the reader fixes, and you do not want your
design work to fight them.

```bash
git remote add upstream https://github.com/anxcye/anx-reader.git
git fetch upstream
```

Keep your changes in files upstream does not touch where you can. Never reformat
`assets/foliate-js/` or `lib/dao/` for style, or every merge becomes a conflict.

---

## 4. Architecture — the page curl

The problem survived the stack change almost unchanged.

- A real curl needs each page as a GPU texture.
- The reader is **foliate-js inside a WebView** (`flutter_inappwebview`).
- On Android a WebView is a **platform view**. Flutter composites platform views
  outside its own layer tree.

### 4.1 The Flutter tools

Flutter's `FragmentProgram` API runs GLSL fragment shaders.
The `flutter_shaders` package adds **`AnimatedSampler`**, which captures a child
widget as a texture and feeds it to a shader. For widgets you draw yourself,
this is exactly the mechanism the curl needs, and it runs per frame.

### 4.2 The open risk — verify this first

**`AnimatedSampler` probably cannot capture a platform view.** This is a known
Flutter limitation, and the WebView is a platform view.

I could not confirm a working capture path from the documentation.
**This is the first thing Milestone 1 must test.** The likely answer is the
`InAppWebViewController` screenshot method, which gives a bitmap you curl instead
of the live view. If it exists and is fast enough, the design below works.

```
   WebView (foliate-js)                  Flutter shader
   ────────────────────                  ─────────────────────
   page N     live, visible      ──┐
   page N+1   pre-captured       ──┼──> bitmap ──> curl fragment shader
   page N-1   pre-captured       ──┘                (60 fps)

   finger down  -> hide WebView, show shader with the two textures
   finger moves -> fold position follows the finger
   finger up    -> settle, tell foliate-js to advance, show WebView, re-capture
```

**The load-bearing rule: capture the next and previous page before the finger
touches the screen.** A capture during the gesture is too slow.

### 4.3 The good news

- **Journal pages you draw in Flutter.** No platform view, so `AnimatedSampler`
  works directly and the curl is clean.
- **PDF pages are already bitmaps.**

The journal gets the best page turn. That is correct, because the journal is
the product.

---

## 5. Design direction

### 5.1 The palette

The nature palette supersedes the burgundy and blue-grey from the first slides.

| Name | Hex | Use |
|---|---|---|
| Sage Green | `#98A086` | surface, tag, shelf wood shade |
| Dusty Rose | `#A76D5E` | surface, large label, chip |
| Golden Tan | `#C4A071` | surface, rule line, ornament |
| Warm Beige | `#DFCCB1` | page tint, card, shelf |
| Terracotta Brown | `#846044` | **accent and link. The only palette color safe for body text.** |

**These five are a surface palette, not a text palette.** In the reference sheet
every color is a block with text *over* it. Measured against paper `#FAF6EE`:

| Color | Ratio | Verdict |
|---|---|---|
| Terracotta Brown `#846044` | 5.21:1 | AA body text — safe |
| Dusty Rose `#A76D5E` | 3.90:1 | Large text and UI only |
| Sage Green `#98A086` | 2.53:1 | **Never text.** Surface only |
| Golden Tan `#C4A071` | 2.26:1 | **Never text.** Surface only |
| Warm Beige `#DFCCB1` | 1.45:1 | **Never text.** Surface only |

So the palette needs an ink color it does not have. Add these:

| Role | Hex | Ratio on paper |
|---|---|---|
| Paper | `#FAF6EE` | — |
| **Ink** (body text) | `#3A2E28` | 12.17:1 AAA |
| **Ink soft** (labels, captions) | `#5C4A3F` | 7.77:1 AAA |
| Accent | `#846044` | 5.21:1 AA |

`#3A2E28` is a deep warm brown-black. It reads as sepia ink, not as black,
so it keeps the mood while passing at AAA.

**Dark theme ("candlelight") on ground `#241C17`:**
the palette inverts well, with one exception.

| Color | Ratio | Verdict |
|---|---|---|
| Cream ink `#EDE0CE` | 12.89:1 | AAA — the dark-theme body text |
| Warm Beige `#DFCCB1` | 10.70:1 | AAA |
| Golden Tan `#C4A071` | 6.87:1 | AA — **the dark-theme accent** |
| Sage Green `#98A086` | 6.15:1 | AA |
| Dusty Rose `#A76D5E` | 3.98:1 | Large and UI only |
| Terracotta Brown `#846044` | 2.98:1 | **Fails.** Do not use for text in dark. |

**Rule: the accent swaps between themes.** Terracotta in light, Golden Tan in dark.
Bind both to one Material color role so this happens once, not per screen.

### 5.2 Cover and pages are two different worlds

The journal cover references (black with gold and a moon, deep green with gold
and red florals) are much more saturated than the page palette. That is correct,
and it is how real books work. Do not average them.

| Surface | Palette |
|---|---|
| **The closed book cover** | Deep and saturated. Gold foil line art, clasp, elastic band, ribbon. |
| **The pages inside** | The warm nature palette above. Quiet. |

The contrast between the two is the reward for opening the book.

### 5.3 The rule that keeps it usable

Impeccable's `reference/android.md` is clear: Material Design 3 governs structure,
navigation, and interaction. Brand expresses through Material theming.
Anx Reader already uses `flex_color_scheme`, so the theming hook exists.

| Layer | Rule |
|---|---|
| **The book** — paper, curl, floral frames, script type | Full expression. This is the artifact. |
| **The chrome** — navigation, sheets, dialogs, pickers, keyboard, Back | Material 3. No exceptions. |

Non-negotiable:

- System Back always works, including the predictive Back gesture.
- Edge-to-edge layout with correct insets, **including the keyboard inset**.
- Touch targets 48 x 48 dp minimum, 8 dp apart.
- Text scales with the system font-size setting.
- Dark theme is a first-class scheme, not an inverted light theme.
  Proposal: "candlelight" — warm dark brown paper, cream ink, burgundy accent.

### 5.4 The ornament set — first-party assets

The floral ornaments and the application icon are **your own work**
(`@FINE.ART.MUSE`). They ship with the application. No license question.

The set you have:

| Ornament | Use |
|---|---|
| Oval floral frame | Book cover slot. Portrait photograph frame. |
| Rectangular vine frame | Full-page border. The review sheet. |
| Corner spray | Page corners. The welcome page. |
| Circular wreath | The challenge page. The icon. Empty states. |
| Bow and ribbon | Bookmark head. Section marks. |
| Icon: burgundy card, wreath, `J` monogram | Application icon |

**Prepare them as vectors, not as flat images.** Today they are raster art on a
burgundy ground. That locks one colorway and blocks the dark theme.

1. Cut each ornament from its ground. Keep the ground transparent.
2. Export to SVG.
3. Draw them with a single tint color that reads a theme token.

Then one ornament serves every surface: pale gold on the burgundy cover,
terracotta or sage on a cream page, warm beige in the candlelight theme.

**The fork has zero SVG assets today**, so add `flutter_svg` to `pubspec.yaml`.
`flutter_svg` supports `colorFilter`, which gives you the tint.

**Burgundy is not gone.** It returns as the cover and ornament color world,
exactly the split in Section 5.2: saturated cover and ornaments, quiet pages.

### 5.5 Fonts — the one real license check

The slides show a sample labelled "Adobe Elegant Script Fonts".
**Adobe Fonts licenses do not permit application embedding in every plan.**
Confirm yours before Milestone 3, or pick a font with an embedding license.
Free alternatives, all SIL Open Font License: EB Garamond, Cormorant Garamond,
Playfair Display. Also check the two `.otf` files already in the fork (Section 3.6).

---

## 6. The opening sequence

On cold start only: a closed book, a tap, the cover opens, the view moves into
the page, and the home screen arrives.

### 6.1 Why this is cheap to get right here

The cover opening **is** a page curl. It uses the same shader as Section 7, and
it draws in Flutter with no WebView. So build the opening sequence and the curl
together — one shader serves both, and the opening is the safer place to test it.

### 6.2 The rules that stop it from becoming hostile

An animation you cannot skip turns from delightful to hostile at about the
fifth launch. All of these are requirements, not options:

- **Cold start only.** Never on resume from the background. Never after a
  configuration change.
- **Tap anywhere skips it** and lands on the home screen at once. From the first
  frame, not after the cover opens.
- **A setting turns it off**, and the setting is easy to find.
- **Obey the system "Remove animations" setting.** When it is on, go straight to
  the home screen.
- **Budget 1.2 seconds** from first frame to interactive. Measure it.
- **Never block first paint.** Load the database behind the animation, so the
  home screen is ready when the sequence ends.

### 6.3 The sequence

1. Closed cover, centered. Deep saturated color, gold line art (Section 5.2).
2. Tap. The cover lifts and curls open. The spine stays fixed.
3. The view moves in toward the first page.
4. The welcome quote page settles. The chrome fades in last.

---

## 7. The page turn — build order

1. **Step A — Fold.** Two flat halves, one rotates on a hinge. No shader.
2. **Step B — Curl.** Fragment shader. The page bends, the back face shows through,
   a soft shadow follows the fold line. **This is your target.**
3. **Step C — Paper.** Grain, warm edge, and a small settle at the end.

Rules for all steps:

- The finger position drives the fold position. Never a fixed animation.
- **The curl takes a direction parameter.** Right-to-left locales open the book
  from the other side and turn pages the other way (Section 3.4.1).
  Build this in from version one. Retrofitting it is much harder.
- Obey the system "Remove animations" setting. Fall back to a cross-fade.
- Hold 60 fps on a mid-range Android phone. Measure it. Do not guess.
- **Warm the shader during the opening sequence** (Section 11.2). A fragment
  shader compiles on first use, and that stall lands on the first page turn.
- Never trap text input behind the animation.

---

## 8. Page inventory

From the slides and the reference sheets. `*` marks a page the references added.

| Page | What it is | Repeats |
|---|---|---|
| Opening cover | The closed book. Section 6. | Once per cold start |
| Welcome page | Quote. Sets the tone. | No |
| **Bookshelf challenge** | 100 numbered spines. Color one when you finish a book. | No |
| **Book tracker shelf** `*` | Shelf with numbered spines and a legend: want to read, reading, read. | No |
| **Reading log** `*` | Table: date, title, author, rating. The plain list view. | No |
| **Month tracker** `*` | Circular 31-day ring. Key by pages per day. | Per month |
| Book library grid | Cover slots, five across, each with a star row. | No |
| To-be-read list | Books you plan to read. | No |
| **Books to buy** `*` | Two-column checklist. **Not the same as to-be-read.** | No |
| My reading list | Books in progress and finished. | No |
| Book cover + write page | One spread per book. | Per book |
| Book review page | Full review sheet. Section 3.2 has the fields. | Per book |
| Dot page | Free journal space. Blank cream page. | Per book |
| Reader spread | EPUB or PDF content. **Inherited from the fork.** | Per book |

**Two lists that look alike but are not:** "to be read" is intent to read.
"Books I want to buy" is a shopping list. Keep separate tables and separate pages.

The bookshelf coloring page in the references is a printable, not a screen.
Group it with the printable bookmarks in Milestone 9.

---

## 9. OPDS catalogs

**Difficulty: medium. The hard half is already in your fork.**

### 9.1 What you already have

`assets/foliate-js/src/opds.js` (10.1 KB) is a complete OPDS feed parser.
It exports `isOPDSCatalog`, `getFeed`, `getPublication`, `getSearch`, and
`getOpenSearch`, and it handles both OPDS 1.2 (Atom XML) and OPDS 2.0 (JSON).

**Anx Reader never uses it.** A search of the tree returns one hit, the file
itself. No Dart code references OPDS. The parser rides along unused.

`dio` is already a dependency for HTTP. `html: ^0.15.4` is already there for XML.
The book import path exists in `lib/utils/import_book.dart` and `lib/service/book.dart`.

### 9.2 What you must build

| Piece | Effort | Note |
|---|---|---|
| Catalog storage | Small | One table. Put it in migration v8 with the rest. |
| Feed fetch and parse | Small | Port `opds.js` logic to Dart, or call it in a hidden WebView. **Port it.** A WebView bridge for a list screen is not worth the complexity. |
| Browse interface | Medium | Feeds nest. Handle pagination and facet groups. |
| Download and import | Small | The import path already exists. Point it at a downloaded file. |
| **Authentication** | **Medium — the real cost** | Most self-hosted catalogs use HTTP Basic auth. |
| OpenSearch | Small | Optional. Add after browse works. |

```sql
tb_catalogs  id, name, url, auth_type, username, sort_order, create_time
             -- never store the password here
```

**Store credentials in the platform keystore, not in SQLite.** Add
`flutter_secure_storage`. This is the one place where a shortcut creates a real
security problem, because these are the user's server passwords.

### 9.3 What makes it take longer than it looks

Feed variety. Calibre-Web, Kavita, Komga, Standard Ebooks, Project Gutenberg,
and Feedbooks all differ in small ways. Test against at least four real catalogs,
not one. Two of them must need authentication.

**Estimate: about one week for browse and download without auth.
About three weeks for a version you would ship.**

### 9.4 Why it is worth more than it looks

Section 2.2 lists "weak first run" as a gap in every competitor. Most start with
an empty shelf and a plus button.

OPDS fixes that. Ship one or two free public catalogs (Standard Ebooks,
Project Gutenberg) as defaults, and a new user has real books on the shelf in
one tap, before they own a single file. **The first-run problem and the OPDS
feature are the same feature.** Build them together.

---

## 10. Not in version 1

- Cloud sync and accounts (the fork has WebDAV — disable it, do not delete it yet)
- Social features, shared shelves, recommendations
- AI features of any kind
- Text-to-speech of any kind. The whole subsystem is removed. Section 3.3.2
- Hindi, Bengali, and Urdu locales, until real translations exist
- iOS release

**Kept, against the earlier draft:** translate, the settings page, and all
fifteen locales. Section 3.3 and Section 3.4. Text-to-speech was on this list
until 2026-08-10. It is now removed. Section 3.3.2.

---

## 11. Performance

You keep more features than the first draft, so performance is now a
first-class goal, not a final pass.

### 11.1 Budgets — measure, do not guess

| Measure | Budget |
|---|---|
| Frame time | 16 ms at 60 Hz. 8 ms at 120 Hz. |
| Cold start to interactive | 1.2 s (Section 6.2) |
| Page turn | No dropped frame across a full turn |
| Book list scroll | No dropped frame at 500 books |

Measure on a **physical mid-range Android phone** in `--profile` mode.
A debug build and an emulator both lie about frame time.

```bash
flutter run --profile
```

Then open DevTools, and watch the raster thread and the UI thread apart.
A shader that stutters shows on the raster thread. A rebuild storm shows on
the UI thread. The fix differs, so read the right one.

### 11.2 Where the spikes will come from

Ranked by how likely they are to bite:

1. **The curl shader.** Fragment shaders compile on first use, which causes a
   visible stall the first time a user turns a page. Warm the shader during the
   opening sequence, where a small delay is already expected.
2. **The WebView bitmap capture** (Section 4.2). This is the least known cost in
   the project. Measure it in Milestone 1 before anything depends on it.
3. **The 100-spine challenge page.** One hundred widgets on one screen.
   Build it as a single painted canvas, not as 100 laid-out widgets.
4. **The book library grid.** Cover images. Use a lazy grid, cache thumbnails at
   display size, and never decode a full cover for a small slot.
5. **The settings page.** 204 KB of Dart in one tree. Split it into lazy routes.
6. **Text input on the journal page** (Milestone 4). A rebuild on every keystroke
   across a decorated page is the classic Flutter trap.

**Locales are not on this list.** `use-deferred-loading: true` is already set,
so the fifteen bundles load on demand (Section 3.4).

### 11.3 The rule

Fix a spike when you can measure it, not when you suspect it.
Run `/impeccable optimize` on a screen that misses a budget.
Do not optimize a screen that meets one.

---

## 12. Milestones

**Milestone 0 — Fork and strip. No design work.**
- Fork `anxcye/anx-reader`. Add the `upstream` remote (Section 3.8).
- **Run code generation first. The fork does not compile without it.**
  `.gitignore` excludes `*.g.dart` and `*.freezed.dart`, and no generated file
  is in the tree. A clean checkout fails with two errors that look unrelated:
  an undefined riverpod provider, and a switch that is "not exhaustively
  matched" because its freezed union is missing. One cause, not two.

  ```bash
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs
  ```

  **Every build checkpoint below means this pair, then the build.** Any change
  to a riverpod or freezed source file needs codegen again, or the next removal
  looks like it broke a build that it did not break.
- Build it unchanged. Prove it runs on your Android phone **before** you edit.
- Remove IAP first. It is self-contained (Section 3.3).
- Then delete `translate/ai.dart`, clean `translate/index.dart`, build, and
  **only then** delete `lib/service/ai` (Section 3.3.1). Order matters.
- Keep translate and settings. Remove text-to-speech completely (Section 3.3.2).
- Build after every removal, never only at the end.
- Rename the package `anx_reader` to `paperfold` in one mechanical commit.
- Write the README fork notice and keep the MIT notice (Section 3.7).
- Record why each of the four dependency forks exists (Section 3.6).
- Confirm the Android verification claim (Section 2.4).

**Milestone 1 — The curl and the opening. This is a gate.**
- Write the curl fragment shader once. It serves both the page turn and the
  cover opening (Section 6.1).
- Build the opening sequence first. It draws in Flutter, so the capture path
  is clean and the shader is easy to judge there.
- **Then prove you can capture a WebView page to a bitmap** (Section 4.2).
  If you cannot, the reader keeps a simple turn and only the journal curls.
  Decide that here, not in Milestone 5.
- Measure frame time on a physical mid-range Android phone.
- Measure cold start to interactive. Budget 1.2 s (Section 6.2).
- **Go or no-go.**

**Milestone 2 — Data**
- Migration version 8: reviews, journal pages, shelves, challenge (Section 3.2).
- Add `status`, `started_on`, `finished_on` to `tb_books`.
- Prove the migration runs on an existing version 7 database without data loss.

**Milestone 3 — The visual world**
- Run `/impeccable init`, then `shape`, then `new-work`. Write `PRODUCT.md` and `DESIGN.md`.
- Build the color tokens from Section 5.1 **first**, including the light and dark
  accent swap. Every later screen reads tokens, never raw hex.
- Replace the theme through `flex_color_scheme`. Replace icons and branding assets.
- Cut your ornaments from their ground and export them to SVG (Section 5.4).
  Add `flutter_svg`. Prove one ornament tints correctly in both themes.
- Welcome page and spread navigation.

**Milestone 4 — The journal**
- Review page (all six ratings), dot page, text input on the page surface.
- **The hardest interaction in the project.** The keyboard, the insets,
  and the book metaphor all fight each other. Give it real time.

**Milestone 5 — Library, shelves, and logs**
- Bookshelf challenge with 100 spines. Book tracker shelf with the legend.
- Book library grid. Reading log table. Month tracker ring.
- To-be-read list and the separate books-to-buy list.
- Open Library metadata lookup. Optional. Manual entry always works.

**Milestone 6 — Settings and translate: the inherited screens**
- These screens work. They do not look like Paperfold. Restyle, do not rewrite.
- Split `lib/page/settings_page` (204 KB) into lazy routes (Section 11.2).
- Give translate the book treatment: a reading control that belongs on
  a page, not a floating panel from another application.
- Run `/impeccable critique` on each inherited screen before you touch it.
  It tells you what to change. Restyling without that step reproduces the
  original layout in new colors.

**Milestone 7 — OPDS and the first run** (Section 9)
- Catalog table, feed fetch, and the browse screen.
- Download, then hand the file to the existing import path.
- Authentication with `flutter_secure_storage`. Never store a password in SQLite.
- Test against four real catalogs. Two of them must need authentication.
- Ship Standard Ebooks and Project Gutenberg as defaults, so a new shelf is
  never empty. **This milestone is the first-run fix** (Section 9.4).

**Milestone 8 — Language**
- Write `app_pl.arb` from `app_en.arb` (Section 3.4). About 48 KB of strings.
- Rebuild the interface strings that Milestones 3 to 7 changed. Watch
  `docs/untranslated_messages.txt`.
- **Test the mirrored curl in Arabic** (Section 3.4.1). Set the device to Arabic
  and turn a page. The book must open from the other side.
- Check the longest language for clipped labels. German and Russian break layouts
  that English fits.

**Milestone 9 — Polish and release**
- Export and import, empty states, printable bookmarks and the coloring page.
- The "turn off the opening animation" switch (Section 6.2).
- Meet every budget in Section 11.1. Fix what misses. Leave what passes.
- `/impeccable audit`, then `/impeccable polish`.

---

## 13. Delegation — enable Luna first

The guard is fail-closed and it **self-tests**, so one edit is not enough.
Three coordinated changes in `C:\Users\ADA\Documents\.codex\route-guard.mjs`:

1. **`ALLOW` set, near line 20** — add `"gpt-5.6-luna:high"` and `"gpt-5.6-luna:xhigh"`.
2. **Self-test table, lines 115-116** — these rows assert that Luna is denied:
   ```js
   ["gpt-5.6-luna", "xhigh", false],
   ["luna", "xhigh", false],
   ```
   Change both to `true`. Add `["gpt-5.6-luna", "low", false]` to keep
   `low` and `medium` denied.
3. **Policy text** — both files still say "Never Terra, Luna":
   `C:\Users\ADA\.claude\CLAUDE.md` and `C:\Users\ADA\Documents\CLAUDE.md`.

Verify:

```bash
node C:\Users\ADA\Documents\.codex\route-guard.mjs --check "codex exec --model gpt-5.6-luna --effort high 'x'"
```

Exit 0 means the route works. Then the deeper teardown runs: the issue trackers
of Openreads, Anx Reader, Book's Story, and KOReader, to find what annoys real
readers. Anx Reader's 131 open issues are now **your** backlog, so read them first.

**This is your policy file, so you make the edit.**

---

## 14. Verification

**Milestone 0:**
- The unchanged fork builds and runs before any edit.
- The application builds after each subsystem removal, not only at the end.
- Search the tree for `anx_reader` and for `iap` after the rename. Expect zero hits
  outside the LICENSE and the README fork notice.

**Milestone 1, the gate:**
- Run on a physical Android phone, not an emulator.
- Record the screen. Count dropped frames across a full turn.
- Turn on "Remove animations" in developer options. Confirm the cross-fade,
  and confirm the opening sequence does not run.
- Launch, background the application, and resume. The opening must not replay.
- Tap during the opening. It must skip at once, from the first frame.
- Measure cold start to interactive against the 1.2 s budget.

**Milestone 2:**
- Copy a version 7 database. Run the migration. Compare row counts.

**Milestone 3, color:**
- Check every text and background pair against Section 5.1.
  Body text needs 4.5:1. Large text and UI need 3:1.
- Confirm no screen puts text on Sage Green, Golden Tan, or Warm Beige.
- Confirm the accent swaps to Golden Tan in dark theme. Terracotta fails there.

**Milestone 8, language:**
- Set the device to Arabic. Turn a page. The curl must mirror (Section 3.4.1).
- Set the device to German, then Russian. Look for clipped labels.
- Confirm `docs/untranslated_messages.txt` is empty for Polish and English.

**Every milestone:**
- Test the system Back gesture on every screen.
- Set the system font size to the largest step. Confirm no clipped text.
- Test light theme and dark theme.
- **Run one `--profile` pass against the Section 11.1 budgets.** A screen that
  misses a budget does not pass the milestone.
- Run `/impeccable audit` on changed screens.

**Reader:**
- Open a 900-page PDF. Measure memory and turn latency.
- Open a reflowable EPUB with images and a table of contents.
- Close the application, reopen it, and confirm the resume point.
