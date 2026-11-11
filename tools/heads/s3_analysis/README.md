# Phase S3 analysis helpers (11 November 2026)

Small scripts used for the day run of phase S3 (see `Documentation/AI_TRAINING_METHOD.md`, "The day's run"). They read
suite runs in `.sim_output/suite/<run>/` (results.jsonl and the boards' CSVs). Run them with `python -I <script> ...`.

| Script | What it prints |
|---|---|
| `go_timing.py <runs>` | at the go from a hold or down a slalom's dive: the time it reckoned it needed against the time it took |
| `go_grid.py <runs>` | how late the starts from a hold were, by the speed it went at, the reckoned time, and whether it tacked on the way |
| `go_turn_when.py <runs>` | of the starts that tacked on the way: was the line on the other tack already at the go, or found later |
| `go_sag.py <runs>` | how far the track ran off its aim in the first 6 s after going from a crawl |
| `over_how.py <off> <on>` | boards over early in the on run but not the off run: what each was doing just before it went over |
| `over_all.py <runs>` | every board over early at the gun: counts by what it was doing just before |
| `safe_test.py <off> <on>` | the day's "safer at no cost" measure: per board no fall and not over early, fixed against broken, sign test |
| `trace.py <run> <race> <board> [from] [to]` | one board's start in a few lines: every change of what it is doing |
