# Brains

A brain is a trained neural network that sails a board: the learned skipper's
(RACING_PLAN.md, "The learned skipper", decision RD4). Like the Blender models in
`Game/assets/models/`, a brain is a built file: it is made by a program from the
physics as it was at one commit, and it is made again with one command when the
physics changes.

## What is in a brain file

Each `<name>.json` holds:

- `layers`: the network itself. Each layer has `w` (one row of weights per neuron,
  one weight per input), `b` (one bias per neuron) and `act` (`tanh` or `linear`). A
  neuron adds up its inputs times its weights, adds its bias and squashes the sum with
  tanh into -1 to 1 (`linear` leaves the sum as it is: the trainer's brains end with a
  linear layer, and the game clips each output to -1 to 1 as it uses it). The first
  layer takes the observation, the last gives the three actions.
- `obs_names`: what each input is, in order (`Game/race/race_observation.gd`). The
  game picks the brain's inputs out of the observation **by these names**, so a brain
  made before a number was added to the observation still sails (the night brains of
  October 2026 take 58 of today's 68 numbers).
- `obs_scale`: a number per input that multiplies it before the first layer (all
  ones for the brains made here; the observation is already scaled).
- `action_names`: what the three outputs (each -1 to 1) mean, which depends on the
  brain's action mode, `meta.actions`:
  - `twa` (the trainers' default): `twa`, `sheet`, `hold`. The first is the wind
    angle the board should sail at: 180 degrees times the output, positive with the
    wind from starboard (0.25 is close-hauled on starboard, -0.83 a broad reach on
    port). The hands steer for that angle every tick and let the controller's heading
    hold do the steady part; when the angle wanted is on the other tack they ask for
    a tack or gybe (the controller chooses which), at most every 3 s. The third is
    the hold-back skill (AI_FLEET_PLAN.md, D1): above 0 the sheet is eased until the
    board sails no faster than 8 m/s (just above 0) down to 1.5 m/s (at 1), so a
    board can wait for the gun without stopping. A brain whose third output is called
    `unused` (the night brains) never holds back.
  - `stick`: `steer`, `sheet`, `tack`. Steer is the stick of the beginner controller
    itself; a tack or gybe is asked for when tack rises above 0.5.
  In both, the sheet only takes over from the auto-sheet beyond 0.5 either way.
  `LearnedSkipper` reads a brain in the mode it was trained in (no `meta.actions`
  means `stick`, as the first brains were).
- `meta`: where the brain came from: the training run, the stage or course, the
  generation, its reward or fitness, how far it got, the date, the physics commit,
  the action mode, `decision_ticks` (how many ticks of 1/60 s between two decisions:
  30 for the trainer's brains, a decision every half second; 6 for the night brains),
  and the settings of the training.

`NeuralNet.load_file(path)` reads one; `LearnedSkipper` sails a board with it.

## How they are made: PPO over the bridge (F5, the trainer of the AI fleet)

The head of the AI fleet (AI_FLEET_PLAN.md, D6b) is trained by PPO from
Stable-Baselines3 in Python, on races Godot sails headless over a local socket
(`tools/train/`, `Game/race/train_bridge.gd`, `Game/dev/train_worker.gd`), one
curriculum stage at a time on random courses in random winds
(`Game/race/training_drops.gd`: S1 the beat, S2 the rounding, S3 the run and the
gates, S4 full laps, S5 the start, S6 company). The reward is the fall of the
sailing distance still to go round the course (`Game/race/sailing_distance.gd`), so
going out to a layline pays like pointing at the mark, a detour pays nothing and the
rounding itself pays. Needs once: `pip install torch stable-baselines3`.

    tools/train.sh --stage=S1 --hours=3                      the first stage, run "s1"
    tools/train.sh --stage=S2 --hours=3 --resume=Game/race/brains/s1_best.json
    tools/train.sh --evaluate=Game/race/brains/s1_best.json --stage=S1 --episodes=20 --reference=allrounder

It writes, every half hour and at the end:

- `<run>_gen<N>.json`: the brain at that moment (N counting up), so `tools/gens.sh
  --run=<run>` can show a night's generations racing;
- `<run>_best.json`: the one with the best mean reward over its last 300 episodes;
- `<run>_latest.json`: the last one;
- `.sim_output/train/<run>/curve.csv` (one line per rollout: the reward, the share
  of episodes that reached their goal, the speed made good, falls and manoeuvres)
  and `model.zip` (to continue the run with the same command).

To race one in the game or headless: `brain:<run>_best` as a skipper's name
(`tools/race.sh --skippers=brain:s4_best,allrounder`, `tools/release.sh
--race=t1_loop --skippers=brain:s4_best,allrounder,rookie`).

## How the first brains were made: neuroevolution (the nights of 19 to 21 October 2026)

By neuroevolution (`Game/dev/evolve.gd`): a population of networks with random
weights sails the T1 training loop, one board each, every network the same race. The
best few are kept, the rest are replaced by copies of the best with small random
changes to their weights, and this repeats, generation after generation. No Python is
needed; the races run on all the cores.

The command, from the repository's folder:

    tools/race_evolve.sh --run=<name> [--hours=6] [options]

To see how a brain sails, without a window (one line per race, and the first race's
track in `.sim_output/evolve/evaluate.csv`):

    tools/race_evolve.sh --evaluate=Game/race/brains/<name>.json --races=5 [race options]

It writes:

- `<name>_best.json`: the best brain so far, each time a generation beats it;
- `<name>_gen<N>.json`: the best of generation 1 and of every 10th generation, so the
  rookie and the veteran of one run can be watched side by side;
- `.sim_output/evolve/<name>.csv`: one line per generation (best, mean and median
  fitness, how far the best got, the time it took).

The options (population, noise, episode length, the start, the threads) are explained
at the top of `Game/dev/evolve.gd`.
