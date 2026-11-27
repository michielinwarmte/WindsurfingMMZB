# The broadcast study: progress

The plan is [PLAN.md](PLAN.md). This file is the log of the run and the "to continue" note. Newest entry first.

## The run of 27 November 2026 (evening and night)

**Max's go (17:30):** "we do the commentary and drone plan". His answers before the start:

- **How far:** the data and the build in the game (the TV director set to the measured numbers, the commentary as subtitles in watch mode), on its own branch with a play folder. He checks it all at the end. Not in this run: the stream's look (P5) and the voice (P7, which waits for the commentator's yes).
- **When:** start now, through the night.
- **Who works:** Fable leads, at most **5** Opus 5.5 workers at extra-high effort (Max typed "5"; the repo's rule of three at a time holds).
- **The commentator:** "there is mostly one commentator, Ben Proffitt".

**What Max sent:**

- Audio: the five stream days of the World Cup Fuerteventura 2026 Slalom-X, 22 to 26 July (27 h): `HXQpY4ZMkJQ`, `Z9B7WTnsJhA`, `EHg3Mo8zXxY`, `7F2VH96g3oc`, `qBUdFkAPul4`.
- Video (the audio is used too): the replays of the Men's Eliminations 1 to 11 (1 h 46 min): `Mt9gi7qP82Q`, `Q08jEfcMU9Q`, `dLbDV6jDm2s`, `6Lp_1I03OHE`, `XQMlNVPPuaw`, `ANNFWjE6JuI`, `2FJY7lpVYDA`, `ujNLUgITjpg`, `P6iCS8-o0B8`, `V73vVhTTr0E`, `CJIOFQGVrpk`.

**Where things are:**

- The branch `broadcast/study-27nov` (from main 19ec1cc) in the folder `C:/Users/Max de Dikke/source/WindsurfingMMZB-broadcast`. Not pushed.
- The streams, the text and the pictures are outside git, in `C:/Users/Max de Dikke/source/pwa_broadcast/` (`media/<video id>/`, `lists/`, `logs/`, `web/` for the PWA's entry list, `models/` for the voice-fingerprint model). The transcripts hold the riders' real names.

### Log

| Time | What |
|---|---|
| 17:30 | Both downloads started: the audio of the 5 stream days (0.55 GB, about 20 MB per hour) and the 10 replays that weren't here yet (480p). Done by 17:35. |
| 17:36 | The rider names from the PWA's entry list (39 men, 13 women) saved in `pwa_broadcast/web/riders_fuerteventura_2026.json`; a hint for Whisper made from them (`tools/broadcast/rider_hint.py`). |
| 17:38 | Speech to text timed on 3 minutes of Elimination 7, one job on 12 threads: distil-large-v3 4.6 x real time, large-v3-turbo 3.9 x. Turbo gets more words right ("my eyesight is terrible" against "eyesize is terrible"), so turbo it is. A hint written as short sentences makes it write full stops; a comma list made it write one long comma sentence. |
| 17:41 | Speech to text started: the 11 replays first, then the 5 stream days, 3 jobs x 4 threads (12 of the 16). |
| 17:42 | The cuts and the contact sheets of the 11 replays started (`tools/broadcast/shots.py`). First replay: 55 shots in 11 min 21 s, median 10 s, longest 68 s. |
