# Inherited fonts — license check

Milestone 0 action from `plan.md` Sections 3.6 and 5.5. Checked on 2026-08-10.

## What ships in the fork

| File | Size | Family (name ID 1) |
|---|---|---|
| `assets/fonts/SourceHanSerifSC-Regular.otf` | 1.22 MB | Source Han Serif CN |
| `assets/fonts/SourceHanSerifSC-Bold.otf` | 1.22 MB | Source Han Serif CN Bold |

Both are declared in `pubspec.yaml` under family `SourceHanSerif`, at weight 400
and weight 700.

## Copyright string, read from the OpenType name table

```
Copyright (c) 2017 Adobe Systems Incorporated (http://www.adobe.com/),
with Reserved Font Name 'Source'.
```

## Result

**Embedding is permitted. There is no license problem.** Source Han Serif is
Adobe's open-source CJK typeface, released under the SIL Open Font License 1.1.
The phrase "with Reserved Font Name" is the OFL Reserved Font Name clause.

Two constraints follow from the OFL:

1. **Do not rename a modified font to "Source ...".** The Reserved Font Name is
   'Source'. If Paperfold ever subsets or modifies these files, the result must
   carry a different family name.
2. **The license text must travel with the font.** OFL 1.1 requires this.

## Defect found — fix it in Milestone 0

**The fork does not ship the OFL text for these fonts.** The repository holds
only `LICENSE` (Anx Reader, MIT) and three foliate-js license files. There is no
`OFL.txt` next to `assets/fonts/`.

Action: add `assets/fonts/OFL.txt` with the SIL Open Font License 1.1 text, and
name Source Han Serif in the Paperfold third-party notices.

## Unresolved, and separate from this check

`plan.md` Section 5.5 names "Adobe Elegant Script Fonts" from the design slides.
That is a different question. Adobe Fonts subscription licenses do not always
permit application embedding. The two fonts checked here are open source and are
not affected. Confirm the script font before Milestone 3, or use an OFL
alternative: EB Garamond, Cormorant Garamond, or Playfair Display.

## Note on evidence

Name ID 13 (License Description) and name ID 14 (License URL) are absent from
both files. The OFL is established by the Reserved Font Name clause in the
copyright string and by Adobe's published release terms, not by a license field
inside the file.
