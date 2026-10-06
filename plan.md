# Paperfold — project plan

> Living document. Change it freely. Nothing is locked until Milestone 1 ends.
> Text follows ASD-STE100 Issue 9 (Strict STE). Code identifiers stay unchanged.
> Research date: 2026-08-09. Version numbers are correct on that date.

---

## 1. Context

You start a book journal, reader, and note application. The slides give the concept:
a personal reading journal that opens and turns pages like a real book.

The project directory holds only tool configuration:

- [.claude/settings.local.json](.claude/settings.local.json) — Impeccable design hook
- [.codex/hooks.json](.codex/hooks.json) — Impeccable design hook for Codex
- `.claude/skills/impeccable/`, `.agents/skills/impeccable/` — design skill

There is no product code and no git repository yet.

**Your four decisions (2026-08-09):**

| Decision | Choice |
|---|---|
| Version 1 scope | EPUB and PDF reader **plus** Journal |
| Stack | Expo (React Native) |
| Page turn | Build the real curl |
| Research | Add Luna to the allowlist, then run a deeper pass |

---

## 2. Market research — what exists

Method: F-Droid catalog, GitHub API, npm registry, pub.dev. Primary sources only.
Search engines returned advertisements and unrelated pages, so I did not use them.

### 2.1 The market splits in two, and nothing bridges it

**Readers — mature and strong**

| Application | Stars | Stack | License | Last push |
|---|---|---|---|---|
| KOReader | 28,846 | Lua | AGPL-3.0 | 2026-08-09 |
| Anx Reader | 8,645 | Flutter | MIT | 2026-06-07 |
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

### 2.2 What the strong applications do well

- **KOReader** — page layout control, dictionary, highlights, statistics.
- **Openreads** — clean book cards, custom shelves, Open Library metadata, no account.
- **Book's Story** — Material You theme, many formats, deep customization.
- **Anx Reader** — modern interface, notes, cross-platform.

### 2.3 What nobody does — your opening

1. **No emotional design.** Every tracker is a list, a grid, or a spreadsheet.
2. **Notes are second-class.** Readers keep highlights. Trackers keep star ratings.
   Almost nothing gives you a free page for your own thoughts.
3. **No true book metaphor.** Nothing in this list turns pages like paper.
4. **Reader and journal stay apart.** You read in one application, record in another.
5. **Weak first run.** Most start with an empty list and a plus button.

**Thesis:** make the journal the product, and make it feel like paper.
Your combined scope (read **and** journal in one book) sits in the empty space
between the two columns above.

### 2.4 The page-turn problem — no library exists anywhere

| Option | State | Verdict |
|---|---|---|
| `page-flip` (StPageFlip), npm | v2.0.7, published 2021-04-18 | Mature, but web only |
| `page_flip`, pub.dev (Flutter) | v0.2.5+1, 180 likes, **98 downloads** | Effectively dead |
| React Native | No package exists | Must be built |
| `erayakartuna/pdf-flipbook` (Java) | 451 stars, last push 2024-01-18 | Reference only |

You build the curl. This is settled, and Section 6 says how.

### 2.5 Distribution risk — confirm this early

The Book's Story README carries this notice, quoted from the repository:

> Starting in September 2026, Android will require all apps to be registered by
> verified developers in order to be installed on certified Android devices.

Source: `https://github.com/Acclorite/book-story`, which links to
`https://keepandroidopen.org/`.

This is a claim by that project's author. It is **not** verified against Google.
**Action in Milestone 0:** confirm it in Google's official documentation.
If true, it changes how you ship outside the Play Store. It does not change
the build plan.

---

## 3. Architecture — the one hard problem

Your two choices fight each other, and the plan must solve this first.

- A **real Skia curl** needs each page as a GPU texture.
- **EPUB** renders inside a WebView (epub.js). **PDF** renders inside a native view.
- Skia cannot draw a WebView or a native view directly.

### 3.1 The answer: snapshot and curl

```
   live view (WebView / PDF view)        Skia canvas
   ─────────────────────────────         ───────────────────────
   page N     rendered, visible   ──┐
   page N+1   rendered offscreen  ──┼──> capture to bitmap ──> curl shader
   page N-1   rendered offscreen  ──┘         (both faces)      (60 fps, UI thread)

   finger down  -> hide live view, show Skia canvas with the two textures
   finger moves -> shader fold position follows the finger
   finger up    -> settle, swap page N, show live view again, re-prime N+1 / N-1
```

**The load-bearing rule: always keep the next and previous page captured
before the finger touches the screen.** A capture during the gesture is too slow.

### 3.2 What this costs and gives

- **PDF is easy.** A PDF page is already a fixed bitmap. It maps to a texture directly.
- **EPUB is harder.** Text reflows, so you must paginate first, then capture.
- **Journal pages are easiest.** You draw them yourself, so Skia can render them
  natively with no capture at all.

This means the journal gets the best page turn, and that is the right order:
the journal is the product.

### 3.3 Consequence for tooling

Skia, PDF, and the WebView all carry native code.
**Expo Go will not run this project.** Use `expo-dev-client` and EAS development
builds from the first day. Plan for it. Do not discover it in week three.

---

## 4. Stack

Versions checked 2026-08-09.

| Package | Version | Published | Role |
|---|---|---|---|
| `expo` | 57.0.11 | 2026-08-06 | framework |
| `expo-router` | 57.0.11 | 2026-08-06 | navigation |
| `expo-sqlite` | 57.0.1 | 2026-07-15 | local database |
| `drizzle-orm` | 0.45.2 | 2026-03-27 | schema and migrations |
| `@shopify/react-native-skia` | 2.11.0 | 2026-08-06 | curl shader, journal pages |
| `react-native-reanimated` | 4.5.3 | 2026-07-22 | gesture-driven animation |
| `react-native-gesture-handler` | 3.1.0 | 2026-07-17 | pan gesture |
| `react-native-view-shot` | 5.1.1 | 2026-06-20 | page capture (Section 3.1) |
| `@epubjs-react-native/core` | 1.4.7 | 2025-01-27 | EPUB render |
| `react-native-pdf` | 7.0.4 | 2026-03-19 | PDF render |

### 4.1 Health notes — read before you commit

- **`react-native-view-shot`** — 2,945 stars, 8 open issues, pushed 2026-08-02.
  Very healthy. Good, because Section 3.1 depends on it.
- **`@epubjs-react-native/core`** — npm release is 2025-01-27, but the repository
  (`victorsoares96/epubjs-react-native`, 249 stars) was pushed 2026-08-07.
  Active, with slow releases. Its engine `epubjs` is at 0.3.93 from 2022.
  **Watch this.** A fresh alternative exists: `@likecoin/epub-ts` 0.7.1,
  published 2026-08-07, which claims to be a maintained drop-in replacement.
  Evaluate it in Milestone 4. Do not adopt it before you test it.
- **`react-native-pdf`** — 1,808 stars and pushed 2026-07-27, but **400 open issues**.
  It is the standard choice and it is also the weakest link. Keep the render call
  behind a thin wrapper so you can change it.

### 4.2 PC later

Expo has no desktop target. Two routes, decide at version 2:

1. **Expo Web plus Tauri 2.11.4** — reuses the code. The Skia curl runs on
   CanvasKit in the browser.
2. **`react-native-windows` 0.84.0** — Windows only, and Expo does not support it.

Route 1 is the better fit. Design for it now: keep platform code behind
`Platform.select`, and do not call Android APIs from shared screens.

---

## 5. Design direction

### 5.1 From the slides

- Classic themed book. Warm off-white paper.
- Deep burgundy accent. Blue-grey line art.
- Elegant serif and script for display. Plain type for the interface.
- Floral engraved frames and corners inside pages.
- Bookmarks that close the book, and that you can print.
- Icon: burgundy card, floral wreath, monogram.

### 5.2 The rule that keeps it usable

Impeccable's `reference/android.md` is clear: Material Design 3 governs structure,
navigation, and interaction. Brand expresses through Material theming.

Your brief asks for strong skeuomorphic design. Both hold if you split the layers:

| Layer | Rule |
|---|---|
| **The book** — paper, curl, floral frames, script type | Full expression. This is the artifact. |
| **The chrome** — navigation, sheets, dialogs, pickers, keyboard, Back | Material 3. No exceptions. |

Non-negotiable:

- System Back always works, including the predictive Back gesture.
- Edge-to-edge layout with correct insets, **including the keyboard inset**.
- Touch targets 48 x 48 dp minimum, 8 dp apart.
- Type in `sp` units, so the system font-size setting works.
- Dark theme is a first-class scheme, not an inverted light theme.
  Proposal: "candlelight" — warm dark brown paper, cream ink, burgundy accent.

### 5.3 Asset licenses — check before you build

The slides show stock floral art marked `@FINE.ART.MUSE` and "Available on Etsy",
and a font sample labelled "Adobe Elegant Script Fonts".
**Confirm the license of every font and every ornament before Milestone 2.**
Adobe Fonts licenses do not permit application embedding in every plan.
Free alternatives with clear licenses: EB Garamond, Cormorant Garamond,
Playfair Display (all SIL Open Font License).

---

## 6. The page turn — build order

Build in three steps. Each step ships and works.

1. **Step A — Fold.** Two flat halves, one rotates on a hinge. No shader.
2. **Step B — Curl.** Skia shader. The page bends, the back face shows through,
   a soft shadow follows the fold line. **This is your target.**
3. **Step C — Paper.** Grain, warm edge, and a small settle at the end.

Rules for all steps:

- The finger position drives the fold position. Never a fixed animation.
- Obey the system "Remove animations" setting. Fall back to a cross-fade.
- Hold 60 fps on a mid-range Android phone. Measure it. Do not guess.
- Never trap text input behind the animation.

---

## 7. Data model — first sketch

Local-first. SQLite. No account and no network calls in version 1,
except optional metadata lookup.

```
book        id, title, author, cover_uri, isbn, page_count,
            status (tbr | reading | finished | abandoned),
            started_on, finished_on, rating, source
file        id, book_id, uri, format (epub | pdf), added_on   -- reader side
progress    book_id, locator, percent, updated_on             -- resume point
highlight   id, book_id, locator, text, color, created_on
review      id, book_id, verdict, characters, themes, quotes, would_reread
note        id, book_id, page_index, body, created_on         -- dot pages
shelf       id, name, sort_order
shelf_book  shelf_id, book_id, sort_order
challenge   id, year, target_count                            -- 100-book challenge
setting     key, value
```

Rules:

- Every write is local and immediate.
- `locator` holds an EPUB CFI or a PDF page number. Keep it opaque text.
- Export to JSON and import from JSON in version 1. This is your backup story,
  and the F-Droid audience expects it.
- Metadata lookup uses Open Library, the same source Openreads uses.
  It is free and needs no key. Lookup stays optional. Manual entry always works.

---

## 8. Pages, from the slides

| Page | Purpose | Repeats |
|---|---|---|
| Welcome page | Quote. Sets the tone. | No |
| Library shelves | 100-book challenge. Progress. | No |
| To-be-read list | Books you plan to read. | No |
| My reading list | Books in progress and finished. | No |
| Book cover + write page | One spread per book. | Per book |
| Book review page | Structured review fields. | Per book |
| Dot page | Free journal space. | Per book |
| **Reader spread** | EPUB or PDF content. **New — from your scope choice.** | Per book |

---

## 9. Not in version 1

- Cloud sync and accounts
- Social features, shared shelves, recommendations
- iOS release
- Text-to-speech, dictionary lookup, translation
- Comic formats (CBR, CBZ) and DjVu

---

## 10. Milestones

**Milestone 0 — Foundations. No product code.**
- Run `git init`. The directory is not a repository yet.
- Run `/impeccable init` to write `PRODUCT.md`.
- Run `/impeccable shape`, then `new-work`, for the visual world and `DESIGN.md`.
- Confirm the Android verification claim in Section 2.5.
- Confirm every font and ornament license (Section 5.3).
- Create the Expo project with `expo-dev-client`. Prove an EAS build installs.

**Milestone 1 — The curl. This is a gate.**
- One screen, two pages, Step B from Section 6.
- Prove the snapshot-and-curl loop from Section 3.1 with two static images.
- Measure frame time on a physical mid-range Android phone.
- **Go or no-go.** If it does not feel like paper, fall back to Step A and
  re-plan the product position before you build more.

**Milestone 2 — The book shell**
- Cover, welcome page, spread navigation.
- Material 3 chrome, insets, Back gesture, light and dark themes.

**Milestone 3 — Data and library**
- SQLite schema, Drizzle migrations, book add and edit.
- Open Library lookup, shelves, the 100-book challenge page.

**Milestone 4 — The reader**
- PDF first. It is easier, and it proves the capture path (Section 3.2).
- EPUB second. Paginate, then capture. Evaluate `@likecoin/epub-ts` here.
- Progress, resume, and highlights.

**Milestone 5 — The journal**
- Review page, dot page, text input on the page surface.
- **The hardest interaction in the project.** The keyboard, the insets,
  and the book metaphor all fight each other. Give it real time.

**Milestone 6 — Polish and release**
- Export and import, empty states, first run, icon, printable bookmarks.
- `/impeccable audit`, then `/impeccable polish`.

---

## 11. Delegation — Luna

On 2026-09-30 the user removed `route-guard.mjs` and the pinned model config.
No allowlist edit is needed. Use the newest Luna model at `high` or `xhigh` for the research pass.

Then run the deeper teardown:
Openreads, Anx Reader, Book's Story, and KOReader — their issue trackers and
user complaints, to find what annoys real readers.

---

## 12. Verification

**Milestone 1, the gate:**
- Run on a physical Android phone, not an emulator.
- Record the screen. Count dropped frames across a full turn.
- Turn on "Remove animations" in developer options. Confirm the cross-fade.

**Every milestone:**
- Test the system Back gesture on every screen.
- Set the system font size to the largest step. Confirm no clipped text.
- Test light theme and dark theme.
- Run `/impeccable audit` on changed screens.

**Reader (Milestone 4):**
- Open a 900-page PDF. Measure memory and turn latency.
- Open a reflowable EPUB with images and a table of contents.
- Close the application, reopen it, and confirm the resume point.

**Data:**
- Export to JSON, clear application data, import, compare row counts.
