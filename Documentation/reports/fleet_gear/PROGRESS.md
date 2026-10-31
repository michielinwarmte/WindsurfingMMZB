# The fleet's training and the gear: progress and the ledger

The plan is [PLAN.md](PLAN.md). One line per launch, report and merge, newest at the bottom; the ledger counts the agents' tokens (Michiel's Opus usage) and the lead's.

## Ledger

| Who | Part | Tokens | State |
|---|---|---|---|
| the lead (Fable) | the plan, the briefs | ~0.1 M so far | running |
| the designer (Opus) | 3, the logos | 0.20 M | done, merged |
| the researcher (Opus) | 2, the brands | 0.48 M | done, merged |

## Log

- 31 October 2026, evening: the plan written; `gear/lead` made from `gp4/time-trial` (d49d0c5); the worktrees `../WindsurfingMMZB-train` (`race/train-all`), `../WindsurfingMMZB-research` (`gear/research`), `../WindsurfingMMZB-logos` (`gear/logos`) made from it.
- 31 October 2026, evening: three Opus agents (effort xhigh) launched at once: the trainer (part 1, stops before the long run for the lead's read of the diff), the researcher (part 2, the document only) and the designer (part 3, the logos, the `Brand` resource, the test). The lead waits; no own building meanwhile.
- 31 October 2026, late evening: the designer done in 22 minutes (0.20 M tokens): the eleven logos as SVG and PNG (`Game/assets/brands/<slug>/`, drawn by `tools/brands/make_logos.py`, letters as outlines from open fonts), `Game/gear/brand.gd` with the eleven `.tres`, `test_brands.gd` (5 tests; it bites: a planted real name fails it), `brands.md`; 622 of 622 and the check green on its branch. The lead looked at the contact sheet (`.screenshots/brands.png` in its worktree): every mark reads on white and on the menu's blue. Merged into `gear/lead`. For the shaper: mipmaps on the printed textures; the colours live in the script and the `.tres` both.
- 31 October 2026, late evening: the builder (part 5, the gear page's plumbing with placeholder items, from `gear/lead` with the logos) launched in `../WindsurfingMMZB-page` on `gear/page`: three agents running again (the trainer, the researcher, the builder).
- 1 November 2026, night: the researcher done in 46 minutes (0.48 M tokens): `brand_research.md` (about 1,080 lines; the eleven brands' 2025/2026 slalom and free race lines, twelve other brands, the game's gear set with every `BoardConfig`/`SailConfig`/`FinConfig` number and the rules for the unpublished ones, the shaper's notes, eleven open questions, some 150 sources). Merged into `gear/lead`; its table scripts kept in `tools/gear/research_scripts/`. The lead's decision: the first gear set is smaller than section 3 proposes (a model file per item is about 1 MB): about four boards per board brand and five sails per sail brand, one livery per brand, the whole set under 25 MB.
