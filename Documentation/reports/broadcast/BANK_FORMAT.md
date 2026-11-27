# The commentary bank: the file between the streams and the game

The bank is one JSON file, `Game/race/commentary/commentary_bank.json`. The tools in `tools/broadcast/` write it from the streams' transcripts; the game's commentary director reads it and never changes it. Backlog: E16.S06. The plan: [PLAN.md](PLAN.md), phases P3 and P6.

A **line** is what the commentator says in one go: one sentence, or two or three short ones that belong together ("Oh no. Amado has just nearly took out Pierre."). The words are his, exactly as said on the stream, with only these changes:

- a real rider's name becomes a slot (`{rider}`), so the game puts in its own sailor;
- a real maker's name becomes a slot (`{brand}`), because the game has its own brands;
- "PWA" becomes "VWA", the game's tour (Max, 27 November 2026);
- the speech-to-text's spelling is set right ("jibe" is written "gybe", "sale" is "sail").

## The file

```json
{
  "format": 1,
  "made": "2026-11-27",
  "source": "World Cup Fuerteventura 2026, Slalom-X: 5 stream days and 11 heat replays",
  "moments": {
    "gybe_good": {"about": "a clean, fast or brave gybe at a mark", "lines": 41}
  },
  "lines": [
    {
      "id": "L000123",
      "moment": "gybe_good",
      "text": "Oh, what a gybe from {rider}.",
      "slots": ["rider"],
      "level": 3,
      "seconds": 2.4,
      "count": 6,
      "needs": [],
      "src": "2FJY7lpVYDA@459.2"
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `id` | never reused; a line keeps its id when the bank is rebuilt, so "used lately" survives an update |
| `moment` | one moment id from the list below |
| `text` | the words, with slots in braces |
| `slots` | the slots in the text, in order. A line whose slots the game can't fill at that moment is skipped. |
| `level` | how excited he says it: 1 calm, 2 normal race voice, 3 lifted, 4 shouting. From the measured pitch of his voice against his usual pitch (and the loudness). The director uses it to fit the line to how big the moment is. |
| `seconds` | how long he takes to say it, measured. The subtitle stays up about this long (plus reading time), and the next line waits for it. |
| `count` | how often he said this line (the same words after the slots) in the streams read so far. A high count is a staple of his. |
| `needs` | conditions beyond the moment, each a short word the director checks: see below. Empty = no extra condition. |
| `src` | where it was said: video id `@` seconds. For checking the words against the stream, and later for cutting his voice. Not shown in the game. |

### The slots

| Slot | The game fills in |
|---|---|
| `{rider}` | the name of the board the line is about (the board the moment happened to) |
| `{rider2}` | the other board in the moment: the one overtaken, the one chasing, the one nearly hit |
| `{place}` | the board's place as he says it: "first", "second", "third", "fourth" ... |
| `{brand}` | the board's sail brand, as the game names it |
| `{colour}` | the board's sail colour as a word ("red", "blue"), when the game can name it |
| `{mark}` | which mark: "first", "second", "last" |
| `{leg}` | "first", "second", "last", "penultimate" (he says "on this penultimate reach") |
| `{national}` | the sailor's nationality as a noun, the way he uses it for a rider: "the {national}" = "the Italian", "the Frenchman". The game's sailors have no country yet, so until they do these lines are skipped (the data is kept). |
| `{nation_adj}` | the same as an adjective: "the {nation_adj} rider" = "the Polish rider". Skipped for the same reason. |

### `needs`

Short words; the director knows what each means. The bank's builders use only the ones in this list (a new one is added here first):

| Word | The line fits only when |
|---|---|
| `leader` | `{rider}` is in first place |
| `not_leader` | `{rider}` isn't first |
| `podium` | `{rider}` is in the first three |
| `big_lead` | the leader is clear of second (no board near) |
| `close` | the boards in the moment are close together |
| `camera_wide` | the picture is a wide shot (boards small) |
| `camera_close` | the picture is close on the board |
| `many` | at least 6 boards race |
| `pair` | exactly two boards are in the moment (`{rider2}` is filled) |
| `last_lap` | the board is on its last leg |

## The moments

Each moment is something the race can tell the commentary director. The list comes from the plan and from reading the heats; it grows only when the streams show a kind of line that fits none of these. There are 35: the 28 of the first list, three added from the eleven replays (`trouble`, `wow`, `oh_no`), and four added on Max's word of 27 November 2026 after a sample of the lines that fitted no moment (`tactics`, `tension`, `form`, `conditions`).

**Before and at the start**

| Moment | When | He says, for example |
|---|---|---|
| `pre_start` | the last minute before the gun: boards lining up | "All lined up." "Tight line down the pin end." |
| `start_gun` | the gun | "Here we go." |
| `start_good` | a board is at the line at speed at the gun | "Good start down this bottom end from one of the {brand} boys." |
| `start_bad` | a board is late or slow at the gun | "Just had a shocker in the middle." |
| `over_early` | a board is over the line early, or a general recall | |

**On a leg**

| Moment | When | He says, for example |
|---|---|---|
| `identify` | the camera settles on a board; nothing else happening | "You've got {rider} in the middle on that {brand}." |
| `speed` | a board is fast, in control, gaining | "He is flying over this chop." "He's eating up the chop." |
| `leader` | the leader is shown or named, with no change | "But out in the lead." "{rider}. Leading this race." |
| `rundown` | going through the order: one line per board, in order of place | "So {rider} in first." "Then we've got {rider}." |
| `lead_change` | a new board takes first place | "No. No. It's {rider} that's now taking the lead." |
| `overtake` | a board passes another, not for first | |
| `chase` | a board is closing on the one ahead | "{rider} though putting the hammer down." |
| `fight` | two boards side by side or nose to tail for a while | "Head to head." "Keep your eye on that battle for second place." |
| `airtime` | a board leaves the water off the chop and lands it | "Gets airborne on this penultimate reach and he's holding on." |
| `filler` | racing, but nothing new for a while | "Hardcore racing." |
| `tactics` | the line a board takes against the others or the mark: higher, lower, above, below, inside, in clear wind | "He's got a lower line." "Pushing hard above {rider} though." |
| `tension` | it isn't decided yet and it could go either way: a small gap late in the race, a leader who can still lose it | "Could he do it?" "It's going to be sweaty." "Needs to keep it together though." |
| `form` | the state a rider is in: confident, hungry, enjoying it, on a run | "He means business." "And again, he loves it. He's having fun." |
| `conditions` | the wind, the water and the course on the day: how hard it blows, the gusts, the chop, which leg is the long one | "It's a huge port tack leg on the way out." |

**At a mark**

| Moment | When | He says, for example |
|---|---|---|
| `mark_approach` | the front boards come up to a mark | "{rider}'s going to try and go in tight." |
| `gybe_good` | a clean, fast or brave gybe | "Oh, what a gybe from {rider}." "What a gybe under pressure." |
| `gybe_safe` | a gybe that is simply made | "Rounds safely." "So the leaders round safely." |
| `gybe_bad` | wide, slow, a wobble, off the plane | "A little bit of a wayward gybe." |

**When it goes wrong**

| Moment | When | He says, for example |
|---|---|---|
| `fall` | a board is down | "Someone is in the drink." "{rider}'s gone." |
| `near_miss` | two boards nearly touch | "Oh no. {rider} has just nearly took out {rider2}." |
| `trouble` | a board loses speed or places without falling: a mistake, a spin-out, backing off, stuck in someone's wind | "{rider} mistake." "And {rider} has had to back off here." "Just had a shocker in the middle." |

**His reactions** (added 27 November 2026, from the eleven replays: he says these all the time, on their own, right before or after the line that says what happened)

| Moment | When | He says, for example |
|---|---|---|
| `wow` | a reaction to something spectacular, of any kind: a pass, a save, a gybe, the speed. Said first, the line about what happened follows. | "Wow." "Oh my life." "Look at this." |
| `oh_no` | a reaction to something going wrong for a board: a fall, a near miss, trouble | "Oh no." "No." |

**The finish and after**

| Moment | When | He says, for example |
|---|---|---|
| `last_leg` | the leader starts the last leg | |
| `finish_win` | the winner crosses, or is sure to | "{rider} will win it." "{rider} gets the bullet." |
| `finish_place` | a later board crosses | "{rider} has to settle for third." "And {rider} will get the second place." |
| `photo_finish` | two boards cross nearly together | "But who will get second?" |
| `after_race` | the heat is over: a verdict on it or on a board | "Ridiculous stuff from the young Frenchman." |

**About the picture**

| Moment | When | He says, for example |
|---|---|---|
| `camera` | the picture can't show what he wants, or just changed for the better | "The drones can't even keep up." "That's a better angle." |
| `unsure` | he can't tell who it is (the game can use this on a wide shot, for the feel of the stream) | "Is that {rider}?" "Can't quite see from here." |

## What stays out of the bank

- Talk tied to that day: the event, the year, a rider's weight, the title race, a sponsor.
- The interviews and the other voices (the bank is the main commentator only, for now).
- A line that can't be understood without the line before it, unless the two are kept together as one line.
- Anything the speech-to-text wasn't sure of (its certainty per word is in the transcript) until someone has listened to it.

The raw transcripts, with the riders' real names, stay outside git in `C:/Users/Max de Dikke/source/pwa_broadcast/`.
