# Every open question for Max, in one list

30 October 2026, by the lead (Fable 5.1). Collected from `sailor_controls_plan.md`, `flying_the_board.md`, the three reviews, `hull_balance.md` sections 12 to 14, GP0's report and the roadmap's "Who is waiting on whom". Answer by number; the number in brackets is what the model uses today, and your answer replaces it. Where a question is Michiel's, it says so.

## A. Your body and feet when flying the board

1. **The front foot's pull.** How hard do you pull up on the front strap when the board flies: a share of your weight is enough (half? all?). [Not in the model; the estimate is 150 to 250 N held, about 400 N briefly.]
2. **The back foot against the fin.** How much do you push the tail sideways against the fin, and what do you feel just before a spin-out? [Not in the model.]
3. **The rail on the 72.** You said: flat downwind, the windward rail up crosswind and upwind, more on a wider board. How many degrees on the 72, and from which wind angle does it go flat? Does it change with the wind's strength? [2 degrees of leeward rail, faded off the wind; a placeholder.]
4. **The hips.** How high above the deck are your hips when fully powered on a reach, and how far behind the back foot? [0.42 m; the photos read 0.45 to 0.6 m and 0.2 to 0.4 m behind.]
5. **The body's angle** above the water when fully powered. [30 degrees; the photos read 30 to 45.]
6. **The harness lines.** Their length (you said 30 inch) and where the two ends sit on the boom, in centimetres from the mast. [The two ends together at 0.70 m from the mast; the hook about 1 m from the boom in the model, 0.45 m in your photo.]
7. **The nose.** Does the nose come up as the fin loads at the same pull (the same sail and lean, on a smooth stretch at speed), or only with more pull, in a gust? [Section 12 of the hull report: in the model the fin's lift at the tail pushes the nose down; the hang-back against more pull lifts it.]
8. **The boom's height** above the deck at the mast, one number for your slalom setting. [1.50 m, from your 1.40 to 1.60.]
9. **The mast foot** for slalom: the centre of the pin from the tail. [1.265 m, read from "around 1.2" as the back of your track, 1.245 to 1.405 m.]
10. **Your weight** with wetsuit and harness. [80 kg.]

## B. Your gear

11. **Your fin:** maker, model, depth (you said 39 cm), area if known, and whether its flex is published. [A 38 cm freeride fin with a soft flex from a 2017 test.]
12. **The sail in IMG_4743:** which Severne and which size, and the mast and boom you rig it on. [The HGO 8.0 on a 4.9 m luff and 2.0 m boom in the config; the real 8.0 is 5.22 m and 2.20 m.]

## C. Photos

13. Can you take **one photo from behind** at full speed (the rig's lean and the rail) and **one from the side on flat water** (how much of the board is wet, how high the nose rides)? The side one is the measurement nobody has.
14. **Git:** the five GSYPHOTO proofs and 121.JPG carry a photographer's mark. Keep them out of git, as 121.JPG is now? Your own photos go in.

## D. The push dial and the gameplay (GP0's open items)

15. **The dial's three settings** as the starting point for GP1: eased `hike_share` 0.8, neutral 1.0, pushed 1.6 with the late ease (GP0's table). OK, or change?
16. **GP10, the smooth ease by hand:** build it with GP1 now, or later?
17. **A key in the playtest** to switch the push on and off?
18. **GD1 to GD7:** the roadmap proposes an answer to each. Confirm or change:
    - GD1 the dial: W pushes, S eases; gamepad right trigger pushes, left eases.
    - GD2 it springs back to neutral when you let go.
    - GD3 neutral is a little slower than 0.1's autopilot (1 to 3 %), so a good player clearly beats it.
    - GD4 the beginner mode becomes the push mode; advanced stays raw.
    - GD5 both races against the AI and a time trial.
    - GD6 the race's information stays on screen; speed, wind angles and trim readouts off by default.
    - GD7 package B: the mouse stays where you put it; try both ways for the sideways direction.

## E. For Michiel, through you

19. **The hull's strip rule (A-05):** may a strip of a rockered bottom pull, not pull, or pull up to a bound? The JP SL 72's speeds and wet lengths rest on it (`review_hull.md` finding 1, `flying_the_board.md` section 4).
20. **The rig's pitch lag:** on at 0.3 s (as shipped) or off (as every document says)?
21. **The fin at the fin box** with the mast foot 2 cm from a bounce, built in Session 60 against "for Michiel".
22. **The sail's twist floor** at 0.75 beyond the tunnel's data: keep it (a gameplay choice worth 25 % of the sail force at 24 kt) or follow the formula?
23. **The three reviews** and the two plans: his OK, or his changes, before anything on `ph28/sail-and-hull` is merged.

## F. Older items still waiting on you (from the roadmap)

24. RA1: the play-test stops left from 0.1's fleet.
25. MA1: the lake play-test.
26. RA5: which machine runs the training nights.
27. RA4: the catch-up cap for the big fleet.
28. TE2: your PC's tools.
29. PR1: the license.
30. PR2: a check of 0.1.0's GitHub release page.
