# Every open question for Max, in one list, with his answers

30 October 2026, by the lead (Fable 5.1). Collected from `sailor_controls_plan.md`, `flying_the_board.md`, the three reviews, `hull_balance.md` sections 12 to 14, GP0's report and the roadmap's "Who is waiting on whom". The number in brackets is what the model used when the question was asked. **Max answered the same evening (30 October 2026); his answers are in bold.** Three builds followed on the branches `ph28/real-eight` (the sail), `ph28/rider-feet-body` (the rider) and `ph28/hull-suction` (the hull), from `ph28/sail-and-hull`.

## A. Your body and feet when flying the board

1. **The front foot's pull.** How hard do you pull up on the front strap when the board flies? [Not in the model; the estimate is 150 to 250 N held, about 400 N briefly.] **Max: "correct."**
2. **The back foot against the fin.** How much do you push the tail sideways against the fin, and what do you feel just before a spin-out? [Not in the model.] **Max: "when going faster than 35 to 40 km/h, all the strength I have."** (Not built yet: the plan's P1.2, the next step after the feet's couple.)
3. **The rail on the 72.** How many degrees, and from which wind angle does it go flat? [2 degrees of leeward rail, faded off the wind; a placeholder.] **Max: "crosswind a little bit, 1 to 3 degrees; upwind up to 10, I think."** Downwind flat (his earlier note: the windward rail up crosswind and upwind, the wider the board the more).
4. **The hips.** How high above the deck when fully powered, and how far behind the back foot? [0.42 m.] **Max: "cannot give you this; estimate in photos."** So the plan's photo readings stand: about 0.5 m up, 0.2 to 0.4 m behind the back foot (estimates).
5. **The body's angle** above the water when fully powered. [30 degrees.] **Max: "photos."** So 30 to 45 degrees, 35 typical (estimate).
6. **The harness lines.** Their length and where the two ends sit on the boom. [Both ends at 0.70 m from the mast; the hook about 1 m from the boom in the model.] **Max: "30 to 35 inches, around 0.6 to 0.8 m from the mast depending on sail and conditions."** So the hook 0.38 to 0.44 m from the boom, the ends about 0.7 m from the mast.
7. **The nose.** Does it come up as the fin loads at the same pull, or only with more pull? **Max: "if I push too hard and rail too hard the nose can lift up to 20 to 30 degrees, but I can lower it with my weight on the mast and load on the fin."**
8. **The boom's height** above the deck at the mast. [1.50 m.] **Max: "yes, around that; shoulder height."**
9. **The mast foot** for slalom. [1.265 m, the back of the track.] **Max: "mostly more to the back; it is a tuning setting."**
10. **Your weight** with wetsuit and harness. [80 kg.] **Max: "85 with all."**

## B. Your gear

11. **Your fin.** [A 38 cm freeride fin with a soft flex.] **Max: "a slalom fin; don't know the rest."**
12. **The sail in IMG_4743.** [An 8.0 on a 4.9 m luff and 2.0 m boom in the config.] **Max: "the real" (the Severne HGO 8.0: luff 5.22 m, boom 2.20 m, an Apex 490 mast with a 36 cm extension).**

## C. Photos

13. One photo from behind at full speed, and one from the side on flat water. **Open.**
14. Git: keep the five GSYPHOTO proofs and 121.JPG out of git? **No answer; they stay out until Max says otherwise.** Max also said the GSYPHOTO pictures are from a speed event on 40 cm wide boards.

## D. The push dial and the gameplay (GP0's open items)

15. The dial's three settings as GP1's start (eased 0.8, neutral 1.0, pushed 1.6 with the late ease). **Max: "okay."**
16. GP10, the smooth ease by hand: now or later? **Max: "later."**
17. A key in the playtest to switch the push on and off? **Max: "later; first make the physics better."**
18. GD1 to GD7, the roadmap's proposals. **Max: confirmed, with the time trial "later".**

## E. For Michiel, through you

19. The hull's strip rule (A-05). **Max: "you said it is wrong, but if it can't get helped it's okay for now."** Built as a measured, switchable option on `ph28/hull-suction`; Michiel decides.
20. The rig's pitch lag: on at 0.3 s or off? **Max: "off."** Built on `ph28/rider-feet-body`.
21. The fin at the fin box with the mast foot 2 cm from a bounce. **Max: "wtf??"** In plain words: Session 60 moved the fin's force to where your fin box is (0.18 m from the tail) and the mast foot to 1.265 m; with the mast foot 2 cm further forward (1.245 m) the 24 kt beam reach bounces, with it at 1.265 m it does not. So the shipped setup sits on an edge. Nothing for you to decide; Michiel should look at the balance with the fin at the box.
22. The sail's twist floor at 0.75 beyond the tunnel's data: keep it or follow the formula? **Max: "follow the formula."** Built on `ph28/real-eight`, with the catapult risk at 24 kt re-measured.
23. Michiel's OK or changes on the three reviews and the two plans before anything is merged. **Open.**

## F. Older items still waiting on you (from the roadmap)

24 to 30. RA1, MA1, RA5, RA4, TE2, PR1, PR2. **Max: all "later."**
