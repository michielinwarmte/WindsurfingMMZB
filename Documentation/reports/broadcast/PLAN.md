# The broadcast study: real PWA commentary and drone shots in the game

Status: **plan, waiting for Max's OK** (27 November 2026). Backlog: E16.S06 (the commentary voice) and E11.S11 (the TV director).

## What Max asked

27 November 2026: "analyze drone position on these livestreams and the commentator is using a specific kind of vocabulary. and i want a fifa kind of commentating in the game", then: "you have to replicate their exact sentences. the voice we do as well. before we make it public i ask the guy, i know him. you have to train on a lot of live stream data. the drone shots you can also train on real data?"

## The goal

1. **Commentary like FIFA:** the commentator's own sentences, in his voice, said at the right moment of the race, about what the camera is showing.
2. **A TV director that films like the real streams:** which drone shots, how long, how high and how far away, and what they follow. The numbers are measured from real streams, not set by hand.
3. **The look and feel of the stream:** watching a race in the game should feel like watching the PWA stream: the same graphics on the screen, the same replays and the same pace between heats (Max, 27 November 2026: "make the in-game broadcast the same vibe and stuff like you are watching the stream").

## What we have (counted 27 November 2026)

- **The game:** the TV director (`Game/race/tv_camera.gd`, E11.S11) with chase, side, helicopter, overhead, group and mark drones, plus the committee boat at the start. Its numbers were chosen by hand: a cut every 7 to 12 s. There is also watch mode (E11.S09) and the smart leaderboard (E11.S12), which knows the places all the time.
- **The streams:** the PWA World Tour YouTube channel has 182 live streams (846 h). Of these, 36 are named slalom or foil slalom (190 h). Another 94 (378 h) don't name the discipline, and some of those are slalom days (Sylt 2024, Fuerteventura 2023, Japan 2023). The channel also has 1,446 shorter videos, among them about 135 slalom and 59 foil slalom heat replays.
- **This PC:** yt-dlp and ffmpeg (already used for the video analysis), plus two installed today: faster-whisper (speech to text, runs on this PC) and PySceneDetect (finds the cuts). The processor is a Ryzen 7 5800X3D (16 threads). The graphics card is an AMD RX 6950 XT, and most voice tools are made for NVIDIA cards. 21 GB is free on C:.
- **Done before the plan was asked:** four heat replays downloaded (300 MB, in `C:/Users/Max de Dikke/source/pwa_broadcast/media/`), and three scripts written but not yet run: `tools/broadcast/fetch.py` (download), `transcribe.py` (speech to text with a time on every word) and `shots.py` (cuts, one picture per shot, contact sheets).

## The phases

Every phase ends with a stop for Max.

### P1 · The pilot on four heat replays (one session)

Everything is tested at **Sotavento** first (the Fuerteventura World Cup), an event with a lot of streams (Max, 27 November 2026). The four replays are all Slalom-X Sotavento 2026: Men's Eliminations 7 and 11, and Women's Eliminations 11 and 15 (about 60 minutes). The Japan and Sylt replays downloaded earlier stay on the disk, unused for now.

- Turn the commentary into text, timing how fast that goes on the processor, and on the graphics card with whisper.cpp. That speed decides how many nights P2 takes.
- Split the replays into shots, then look at every shot and note:
  - what kind of shot it is (drone behind, side, overhead, helicopter, boat, beach, graphics, interview)
  - what it follows (the leader, a fight, a mark, the start line)
  - the race moment
  - a rough height and distance
- Read one heat together, as we did with the GPS races: Max points out the commentator's voice and checks the shot notes.
- The report: `Documentation/reports/broadcast/pilot.md`.

**Stop:** Max's OK on the shot notes and on the list of race moments below.

### P2 · Collect: a lot of audio, a small set of video, Sotavento first (nights, on Max's go)

Max, 27 November 2026: "we can do better a shorter stream for the drone stuff and a lot of data for the audio. and that is only an audio file", and "we are going to test it all at sotavento, an event that has a lot of streams".

**Round 1, Sotavento.** The channel has 44 Sotavento streams (183 h) and 49 slalom heat replays (12 h), counted 27 November 2026.
- **Audio, all of the slalom:**
  - 2026 Slalom-X: 5 days, 27 h
  - 2025: 4 days, 18 h
  - 2024 slalom and foil slalom: days 6 to 10, 30 h
  - 2023 Grand Slam: up to 58 h, but those days mix slalom with freestyle, so they are checked first

  The freestyle-only days are left out. That makes about 75 to 133 h, about 2 to 3 GB at YouTube's speech-quality audio (about 22 MB per hour, an estimate that P1 measures).
- **Video for the drone shots and the look, a small set:**
  - 20 of the 2026 heat replays (about 5 h)
  - one full stream day (Slalom-X, 22 July 2026, 5 h), for how the live director handles the start sequence and the waits

  That's about 4 GB at 480p. More replays only if the numbers aren't steady yet.

**Round 2, the other events,** once Sotavento works from start to end: the audio of every other slalom and foil slalom stream and replay from 2023 to 2026 (about 200 h more, about 4 to 5 GB). The days without a discipline in the title are checked by their description.
- Text for all the audio and shots for the video, run at night with the processor at about 80 %, as in the training runs.
- The voice step (P7) needs better sound than speech quality. Only the stretches where he talks alone are downloaded again at the best quality then.
- **Time:** an estimate of 2 to 4 nights, measured in P1.

### P3 · The commentary bank (sessions)

- **Who speaks:** a voice-fingerprint tool tells the commentator, the co-host and the interviews apart. Max points out his voice once.
- **Every sentence gets:**
  - its race moment
  - how excited it is (from the loudness and pitch of the audio)
  - its length in seconds
  - who says it
- **How the moments are tagged:** by rules built from the pilot, with my check on a sample each round. 300 h of commentary is about 2 million words, too much for me to read one by one.
- **Names:** a sentence with a real rider's name gets a slot, such as "{rider} takes the lead", so the game puts in its own sailor's name. Sentences without a name are used exactly as said.
- **Where it is kept:** the raw transcripts with the riders' real names stay outside git (in `pwa_broadcast/`), as the GPS races' names do in `.sim_output/`. The game's sentence file has the names replaced by slots.

**The race moments (first list; P1 corrects it):**
- before the start: the conditions, the riders
- the countdown and the gun
- over early or a black flag
- the first reach and who is ahead
- a lead change, an overtake, a close fight
- a mark rounding and the gybe
- a fall, a catapult, a missed gybe
- the last leg
- the finish and a photo finish
- who goes through to the next round, the results
- the talk while nothing is racing

**Stop:** read a sample of the bank with Max.

### P4 · The drone shots from real data (sessions and a night)

- **A shot recognizer:** trained on the P1 notes (a fingerprint per picture and a simple classifier). It is tested on shots it hasn't seen, and its score is reported before it is trusted. Then it runs on P2's video set.
- **The estimates per shot:**
  - the camera's angle, from the horizon
  - the distance, from the sail's size in the picture (the mast is about 4.9 m)
  - the height, from these two

  They are marked as estimates. Their error is measured on shots with something of known size in them (a mark buoy, the committee boat).
- **The numbers per race moment:** which shots, how long, how high and how far, and how often the leader, a fight or a mark is shown.
- **The TV director set to those numbers.** A check compares the game's director with the real streams, as the reality check does for the physics. Max checks it on his screen.

**Stop:** Max's look.

### P5 · The stream's look in the game (sessions)

- **Measured from P2's video set**, like the drone shots. Every graphic on the screen:
  - the heat card before the start
  - the countdown clock
  - the riders' names and flags
  - the tower of places and the gaps
  - the finish order, and who goes through

  For each one: where it sits on the screen, its size, its colours and type, and when it comes on and goes off, measured against the race moment.
- **The rest of the stream's feel:**
  - how one shot goes to the next (a straight cut, or the logo wipe)
  - the slow-motion replay of the finish or a crash after the heat
  - what is shown between heats (the beach, the riders waiting, the next heat lining up)
  - the sound: the commentary over the wind and the water, and the music between heats

  Each of these is measured, not guessed.
- **Built into watch mode** on top of the TV director. The graphics work at 3137 x 1263 and at any window size. The replays are made together with E11.S08 (replays and ghosts).
- **The names:** the game's tour is the **VWA, the Virtual Windsurf Association** (Max, 27 November 2026), with its own logo and colours, the same way the gear has the game's own brands. The PWA's name and logo stay out of `Game/`. The layout, the timing and the feel are the stream's. In the commentary, "PWA" becomes "VWA" wherever a sentence names the tour.
- **Q46 (the game's visual theme):** this picks option a (the race-broadcast look) for watch mode and the race screens. Whether the whole game takes that look stays open in Q46.

**Stop:** Max watches a race in watch mode on his screen.

### P6 · Commentary in the game, as subtitles first (sessions)

- **A commentary director** next to the TV director:
  - the race tells it the moments
  - it picks a sentence for that moment that hasn't been used lately
  - big moments cut in over small talk
  - it talks about the board the camera is showing
  - it uses two voices, if the streams have two
- **Subtitles first:** the exact sentences at the bottom of the screen, so the timing and the choice are tuned before there is any voice.
- Watch mode first, then the player's own races. Tests for the picking rules.

**Stop:** Max's play test.

### P7 · The voice (after the commentator's yes)

- Clean pieces of his voice, cut from the streams with P3's voice split: only him, no music, no wind.
- A voice model trained on them. Every sentence and every sailor's name is made into a sound file that ships with the game, so no AI runs inside the game.
- **The choice of tool:**
  - Open tools are free, but many want an NVIDIA card (slower on this AMD card, or through Linux), and several have a licence for non-commercial use only, which matters for a public release.
  - Paid voice services are the other option. Some of them make the speaker verify his own voice, which fits, since he is asked anyway.

**Stop:** Max listens.

### P8 · Before anything goes public

A written OK from the commentator (his voice and his sentences) and from the PWA (the words of their streams that the game uses).

## When the commentator is asked

Max will ask the commentator before the game goes public. Claude's request: ask him **before P7**, the voice training, not only before the release. Play folders go to Michiel and others, and a working copy of a real person's voice shouldn't exist without his yes. The voice is the seventh phase, so asking now costs no time. P1 to P6 go ahead meanwhile.

## Decisions for Max

1. The plan, and P1 now?
2. The commentator's name, so his voice is found in the streams.
3. Asking him before the voice step (above)?
4. Only slalom and foil slalom, or wave and freestyle too? Claude suggests slalom and foil slalom: the game is racing.

Decided: P2 takes the audio of everything and the video of a small set only (Max, 27 November 2026).

## After the OK

E16.S06 gets Max's decision written in. New stories: the commentary bank and director (E16), the voice (E16), the TV director from real streams (E11), and the stream's look in watch mode (E11, with E15's Q46 noted). This plan and its progress go into `Documentation/reports/broadcast/`.
