# U1 agent 4, `physics`: report

**Done on `u1/physics`** (spec 5, 7.5, 14, 16, 17.2):
- **U1.5 fixed physically, no new constant.** A sinking strip that is only partly wet (a heeled board's oblique spray root, the vee) meets more water, a rising one less: the root's existing factor, Zarnick 1978 (theory). A 1° tail vee: the median of ten measured 2024 freeride boards (surf-magazin, 0.5 to 2°; the old 2° had no source). Its wetting and chine-dry length follow Wagner and Savitsky (theory). Fixed: the gain behind the root was counted 1.5 times.
- **Flat tail back** (d55bd6a reverted); both buoyancy tests updated.
- **Target 2 is a real check**; targets 3 and 4 stay pending.
- **Grid:** 7 to 13 rows move the wet front at most 4 cm, at equal run time. Default kept at 7.

**Stop rule, U1.2.** The line runs 1.45 m from the hiked body to the grip (real: 0.30 to 0.40 m), because the pilot's weather helm tilts the rig back to 8°. Normal-stance hips give 720 N; the rig at 25° gives 684 N and a bow-down board. 415 N needs the arms to take a third of the boom force: no source. U1.3, diagnosed only: the bow-down 116 N·m is the arms' forward pull, and the legs carry 4 N.

**For Michiel:**
1. U1.2's route: the rig's lean and the helm (U1.6), or an arms' share.
2. Planing onset 13.3 kn (band 8 to 10). The baseline's 9.8 kn rode a 5.9° bouncing bow-up overshoot. Move the band, or seek hump lift?
3. 24 kt broad reach: 0.46 to 0.50° on 9 to 13 rows. A 2° vee steadies it but slows 12 kt 135° by 10 %.
4. Savitsky's limit is about 1.2°; the board is now steady above it.

| Reach check | Baseline | Now | Target |
|---|---|---|---|
| Steady cases | 4 of 9 | 9 of 9 | 4 required |
| Hips 0.15 m | bounces | 9 of 9 steady | |
| Wet front, 18/24 kt, 100°/135°, m | 1.87, 1.66, 1.82, 1.81 | 2.00, 2.24, 1.94, 1.94 | 0.6 to 1.0 |
| Trim, same cases, ° | 0.93, 0.76, 0.70, 0.37 | 1.35, 0.36, 1.25, 1.01 | 1.5 up |
| Harness, 18 kt 100° | 947 N, 91 % | 956 N, 91 % | 350 to 480 N |
| Validation | 20 of 20 | onset fails | green |
