# Word lists

| File | What it is |
| --- | --- |
| `answers.txt` | All possible answers (1,714). The **Daily** walks a fixed shuffle of this file — never reorder or edit it without a storage migration. |
| `answers_easy.txt` / `answers_medium.txt` / `answers_hard.txt` | The same 1,714 answers split by how common they are. Used only by **Journey** (see `lib/logic/journey_ramp.dart`). Together they must equal `answers.txt` exactly (tested). |
| `allowed.txt` | Every word accepted as a guess (12,400). Must be a superset of `answers.txt` (tested). |

## How the tiers were made

- **Ranking signal:** the English Speller Database (ESDB, formerly SCOWL) by
  Kevin Atkinson — <https://github.com/en-wl/wordlist>. A word counts as
  "common" when ESDB lists it at its most common size (35) with its core or
  frequency source tags.
  - **easy (459):** ESDB's core common words, plus a hand-picked set of everyday
    words a casual US player knows. Hand-reviewed: no plurals, proper nouns,
    British-only spellings or offensive words.
  - **medium (625):** the rest of ESDB's common words.
  - **hard (630):** everything else (QUALM, WRACK, IMBUE, TWIXT…).
- The Google 10k / Norvig frequency lists were NOT used: their terms allow
  non-commercial use only.

## Licenses

`allowed.txt` includes the ENABLE word list (public domain).

The difficulty tiers are word lists created from ESDB, which requires this notice:

> Copyright 2000-2026 by Kevin Atkinson
>
> Permission to use, copy, modify, distribute, and sell any part of the English
> Speller Database (ESDB, previously known as SCOWLv2), or word lists
> created from it, is hereby granted without fee, provided that the above
> copyright notice appears in all copies and that both the above copyright
> notice and this notice appear in supporting documentation.  Kevin Atkinson
> makes no representations about the suitability of this database for any
> purpose.  It is provided "as is" without express or implied warranty.
