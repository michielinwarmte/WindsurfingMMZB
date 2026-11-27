"""The starter bank: lines picked by hand from one heat (Men's Elimination 7, Fuerteventura 2026).

It gives the game's commentary director real lines to work with before the full bank is
built from all the streams (bank.py). Each entry names the transcript sentence(s) by their
exact text; the time, the length and the level are read from that heat's sentences.jsonl.

    python -E -P tools/broadcast/starter_bank.py <media folder of 2FJY7lpVYDA> <out.json>
"""
import json
import os
import sys

# (moment, the transcript's sentence or sentences, the line as the bank keeps it, needs)
PICKS = [
    ("pre_start", ["All lined up.", "Super spread."], "All lined up. Super spread.", ["camera_wide"]),
    ("pre_start", ["Tight line down the pin end."], "Tight line down the pin end.", []),
    ("pre_start", ["All fleet race and they're getting ready."], "All fleet race and they're getting ready.", ["many"]),
    ("start_gun", ["Here we go.", "Look at that."], "Here we go. Look at that.", []),
    ("start_good", ["Good start down this bottom end from one of the GA boys."],
     "Good start down this bottom end from one of the {brand} boys.", []),
    ("start_bad", ["Just had a shocker in the middle."], "Just had a shocker in the middle.", []),
    ("unsure", ["It's hard to pick out where everyone is."], "It's hard to pick out where everyone is.", ["camera_wide"]),
    ("camera", ["We're just getting an overall view at the moment."],
     "We're just getting an overall view at the moment.", ["camera_wide"]),
    ("identify", ["It looks like Macek is down here."], "It looks like {rider} is down here.", []),
    ("identify", ["You've got Geordie Vonk in the middle on that Duotone."],
     "You've got {rider} in the middle on that {brand}.", []),
    ("identify", ["The red Severne looking okay."], "The {colour} {brand} looking okay.", []),
    ("identify", ["Then there's a North coming through."], "Then there's a {brand} coming through.", []),
    ("identify", ["This looks like Brendan Loho."], "This looks like {rider}.", []),
    ("identify", ["But that's definitely Brendan."], "But that's definitely {rider}.", []),
    ("unsure", ["Who's on that?"], "Who's on that?", []),
    ("unsure", ["Is that Nico Preen?", "Can't quite see from here."], "Is that {rider}? Can't quite see from here.", ["camera_wide"]),
    ("camera", ["We're going to have to get a closer view."], "We're going to have to get a closer view.", ["camera_wide"]),
    ("camera", ["That's a better angle."], "That's a better angle.", ["camera_close"]),
    ("camera", ["The drones are getting left behind."], "The drones are getting left behind.", []),
    ("camera", ["Look at the boys.", "They've got some serious speed.", "The drones can't even keep up."],
     "Look at the boys. They've got some serious speed. The drones can't even keep up.", []),
    ("speed", ["He is flying over this chop."], "He is flying over this chop.", []),
    ("speed", ["He's got just such good control over the chop."], "He's got just such good control over the chop.", []),
    ("speed", ["He's eating up the chop."], "He's eating up the chop.", []),
    ("speed", ["He is in the money here."], "He is in the money here.", ["podium"]),
    ("speed", ["Don't count this fella out.", "He is right in the game."], "Don't count this fella out. He is right in the game.", ["not_leader"]),
    ("speed", ["Hitting a bit of chop there on the North."], "Hitting a bit of chop there on the {brand}.", []),
    ("speed", ["What the hell is going on?"], "What the hell is going on?", []),
    ("leader", ["Leading this race.", "What a race he is having."], "Leading this race. What a race he is having.", ["leader"]),
    ("leader", ["But Pierre Macquaert is still leading this."], "But {rider} is still leading this.", ["leader"]),
    ("leader", ["But out in the lead."], "But out in the lead.", ["leader"]),
    ("leader", ["Out in front."], "Out in front.", ["leader"]),
    ("leader", ["Look at this from Matteo Iachino."], "Look at this from {rider}.", ["leader"]),
    ("leader", ["On a heater right now."], "On a heater right now.", ["leader"]),
    ("lead_change", ["No.", "No.", "It's Miacchino that's now taking the lead."],
     "No. No. It's {rider} that's now taking the lead.", ["leader"]),
    ("lead_change", ["He did well to hold him off all the way down."], "He did well to hold him off all the way down.", []),
    ("rundown", ["So Matteo Iachino in first."], "So {rider} in {place}.", []),
    ("rundown", ["Then it looks like Pierre Mortefon."], "Then it looks like {rider}.", ["not_leader"]),
    ("rundown", ["Then we've got Brendan Loho."], "Then we've got {rider}.", ["not_leader"]),
    ("rundown", ["Maciek Rakowski in third place."], "{rider} in {place} place.", []),
    ("rundown", ["Then Brendan Loho in fourth place."], "Then {rider} in {place} place.", ["not_leader"]),
    ("rundown", ["Brendan Loho's in there."], "{rider}'s in there.", ["not_leader"]),
    ("rundown", ["He's right up there in the top five."], "He's right up there in the top five.", ["not_leader"]),
    ("chase", ["But he's got Matteo Yachino chasing him down."], "But he's got {rider} chasing him down.", ["close"]),
    ("chase", ["He is making a bid for this."], "He is making a bid for this.", ["not_leader"]),
    ("chase", ["Pierre Mortefon though putting the hammer down."], "{rider} though putting the hammer down.", ["not_leader"]),
    ("chase", ["And putting the pressure on."], "And putting the pressure on.", ["close"]),
    ("chase", ["But there you can see Pierre Mortefon closing in a little bit further back."],
     "But there you can see {rider} closing in a little bit further back.", ["not_leader"]),
    ("fight", ["Look at this.", "Head to head."], "Look at this. Head to head.", ["close", "pair"]),
    ("fight", ["Keep your eye on that battle for second place.", "It's a big one."],
     "Keep your eye on that battle for {place} place. It's a big one.", ["close", "pair"]),
    ("fight", ["This is going to be an out and out speed battle for Mortafon and Maciek Rukowski."],
     "This is going to be an out and out speed battle for {rider} and {rider2}.", ["close", "pair"]),
    ("fight", ["Rukowski needs to hold off Pierre Mortafon."], "{rider} needs to hold off {rider2}.", ["close", "pair"]),
    ("airtime", ["Gets airborne on this penultimate reach and he's holding on Maciek Rakowski."],
     "Gets airborne on this {leg} reach and he's holding on, {rider}.", []),
    ("mark_approach", ["But it will be the Italian who's going to go around this mark in first place."],
     "But it will be {rider} who's going to go around this mark in first place.", ["leader"]),
    ("mark_approach", ["Mortafon's going to try and go in tight."], "{rider}'s going to try and go in tight.", ["close"]),
    ("mark_approach", ["These are tricky right now."], "These are tricky right now.", []),
    ("gybe_safe", ["Jibes first.", "Round safely."], "Gybes first. Round safely.", ["leader"]),
    ("gybe_safe", ["So the leaders round safely."], "So the leaders round safely.", ["leader"]),
    ("gybe_safe", ["And he does."], "And he does.", []),
    ("gybe_bad", ["A little bit of a wayward jibe."], "A little bit of a wayward gybe.", []),
    ("gybe_good", ["Oh, what a jibe from Maciek Rukowski."], "Oh, what a gybe from {rider}.", []),
    ("gybe_good", ["What a jibe under pressure."], "What a gybe under pressure.", ["close"]),
    ("near_miss", ["Oh no.", "Amado Vrieswijk has just nearly took out Pierre Mortefon."],
     "Oh no. {rider} has just nearly took out {rider2}.", ["pair"]),
    ("fall", ["Someone is in the drink."], "Someone is in the drink.", []),
    ("fall", ["Brendan Loho's gone inside the water."], "{rider}'s gone inside the water.", []),
    ("finish_win", ["Iachino will win it."], "{rider} will win it.", ["leader"]),
    ("finish_win", ["Iachino gets the bullet."], "{rider} gets the bullet.", ["leader"]),
    ("photo_finish", ["But who will get second?"], "But who will get second?", ["close"]),
    ("finish_place", ["And Pierre will get the second place."], "And {rider} will get the {place} place.", ["not_leader"]),
    ("finish_place", ["Maciek has to settle for third."], "{rider} has to settle for {place}.", ["not_leader"]),
    ("finish_place", ["In fourth it will be Pierre Macquart."], "In {place} it will be {rider}.", ["not_leader"]),
    ("after_race", ["Hardcore racing."], "Hardcore racing.", []),
    ("after_race", ["Absolutely ridiculous."], "Absolutely ridiculous.", []),
    ("after_race", ["What a race he is having."], "What a race he is having.", []),
    # Added with the four moments of 27 November 2026 (new picks go at the end: the ids are by position).
    ("tactics", ["He's got a lower line."], "He's got a lower line.", []),
    ("tactics", ["Pushing hard above Pierre Mortefon though."], "Pushing hard above {rider2} though.", ["close", "pair"]),
    ("form", ["And again, he loves it.", "He's having fun."], "And again, he loves it. He's having fun.", ["leader"]),
]


def level(pitch_rel, loud_db):
    score = pitch_rel + max(loud_db, 0.0)
    return 1 if score < -2.0 else (2 if score < 1.5 else (3 if score < 4.0 else 4))


def main():
    folder, out = sys.argv[1], sys.argv[2]
    with open(os.path.join(folder, "sentences.jsonl"), encoding="utf-8") as f:
        rows = [json.loads(l) for l in f]
    lines, moments, missing = [], {}, []
    for n, (moment, texts, line, needs) in enumerate(PICKS, 1):
        # The first run of sentences that matches the texts in order.
        hit = None
        for i in range(len(rows) - len(texts) + 1):
            if all(rows[i + k]["text"] == t for k, t in enumerate(texts)):
                hit = rows[i:i + len(texts)]
                break
        if hit is None:
            missing.append(texts[0])
            continue
        voiced = [r for r in hit if r["pitch_hz"] > 0] or hit
        slots = []
        rest = line
        while "{" in rest:
            a, b = rest.index("{"), rest.index("}")
            slots.append(rest[a + 1:b])
            rest = rest[b + 1:]
        lines.append({"id": "S%04d" % n, "moment": moment, "text": line, "slots": slots,
                      "level": level(max(r["pitch_rel"] for r in voiced), max(r["loud_db"] for r in voiced)),
                      "seconds": round(hit[-1]["end"] - hit[0]["start"], 1), "count": 1, "needs": needs,
                      "src": "%s@%.1f" % (os.path.basename(folder.rstrip("/\\")), hit[0]["start"])})
        moments[moment] = moments.get(moment, 0) + 1
    bank = {"format": 1, "made": "2026-11-27",
            "source": "starter bank: picked by hand from the replay of Men's Elimination 7, World Cup Fuerteventura 2026 (Slalom-X)",
            "moments": {m: {"lines": c} for m, c in sorted(moments.items())}, "lines": lines}
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(bank, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print("%d lines in %d moments" % (len(lines), len(moments)))
    for t in missing:
        print("NOT FOUND:", t)


if __name__ == "__main__":
    main()
