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
| 17:57 | Sentences: `tools/broadcast/sentences.py` rebuilds the commentator's sentences from Whisper's words and measures each one's loudness and pitch. Elimination 7: 303 sentences in 11 min. The pitch shows his excitement (calm talk about 5 semitones under his usual, "Oh no." nearly 8 over); the loudness hardly moves (the stream's sound is levelled). |
| 18:00 | The bank's format written ([BANK_FORMAT.md](BANK_FORMAT.md)) and a starter bank of 73 lines in 24 moments picked by hand from Elimination 7 (`Game/race/commentary/commentary_bank.json`). **Worker 1 of 5 started:** the commentary director and the subtitles in watch mode, on `broadcast/commentary-director` in `source/WindsurfingMMZB-commentary`. |
| 18:09 | The 11 replays are text (1 h 46 min in 28 min: 3.8 x real time with the contact sheets running beside it) and contact sheets (366 shots, 118 sheets). The 5 stream days started: 81 pieces, 26 h 56 min. |
| 18:10 | Max: "for the shots you need to define pre start, start and race and after race". The four phases are now a column of the shot notes, with their borders ([SHOT_NOTES_GUIDE.md](SHOT_NOTES_GUIDE.md)). **Workers 2 and 3 started:** the shot notes of Eliminations 1 to 6 and 7 to 11. Both read Elimination 3, apart from each other, to measure how far two readers agree. |
| 18:15 | The voices: `tools/broadcast/voices.py` gives every sentence its likeness to the main voice. The main voice found in each of the 11 replays is the same man (likeness between them 0.94 to 1.00); one reference saved for the stream days. In the replays 1,923 of 2,752 sentences are his (the rest: the interviews). |
| 18:22 | The candidate lines: `tools/broadcast/bank.py` and `names.py`. Riders' names become slots however Whisper spelled them (152 spellings of the entry list's names found in the replays, 18 capital words left unknown), makers and nationalities too; lines are counted and get a moment by rules. Replays: 1,597 distinct lines, 47 % with a moment. His most common line by far: a rider's name on its own (148 times), then the order ("{rider} in {place}.", "Then we've got {rider}."). Three moments added to the format: `trouble`, `wow`, `oh_no`. |
| 18:40 | Max: "pwa is slalom right. in the whole project of the game we focus on slalom" and "obstakle is ok": the study is slalom only (decision 4 of the plan), the obstacle heats count as slalom, and the two full-fleet long-distance races (Eliminations 6 and 7) are kept apart in the numbers. Max on the moments ("are this enough?" - "add them"): four more, `tactics`, `tension`, `form`, `conditions`: 35 in all. |
| 19:00 | **Workers 2 and 3 done:** the shot notes of all 11 replays (510 beats; in `pwa_broadcast/media/<id>/shots/`, outside git because the notes name riders). The cut detector missed about 70 cuts (dissolves, most before the start and after the finish) and made 14 false ones; the readers set them right. Two readers on Elimination 3, apart: the phase the same for 97 % of the seconds, the camera 99.8 %, the moment 89 %, what it is on 88 %, how it moves 87 %, the height 83 %, the number of boards 78 %, **from which side 58 %** (the weak one); horizon and sail height: middle difference 0 points. |
| 19:10 | The numbers: `tools/broadcast/shot_stats.py` and `director_profile.py`; results in [data/](data/) (`shot_stats_slalom.md`, `stream_profile.json`). The start phase is set by the clock for every heat (10 s before the gun to 12 s after), because the two readers drew that border differently. |
