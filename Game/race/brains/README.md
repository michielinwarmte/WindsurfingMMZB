# Brains

A brain is a trained neural network that sails a board: the learned skipper's
(RACING_PLAN.md, "The learned skipper", decision RD4). Like the Blender models in
`Game/assets/models/`, a brain is a built file: it is made by a program from the
physics as it was at one commit, and it is made again with one command when the
physics changes.

## What is in a brain file

Each `<name>.json` holds:

- `layers`: the network itself. Each layer has `w` (one row of weights per neuron,
  one weight per input), `b` (one bias per neuron) and `act` (`tanh`). A neuron adds
  up its inputs times its weights, adds its bias and squashes the sum with tanh into
  -1 to 1. The first layer takes the observation, the last gives the three actions.
- `obs_names`: what each input is, in order (`Game/race/race_observation.gd`).
- `obs_scale`: a number per input that multiplies it before the first layer (all
  ones for the brains made here; the observation is already scaled).
- `action_names`: what the three outputs (each -1 to 1) mean, which depends on the
  brain's action mode, `meta.actions`:
  - `twa` (the trainer's default): `twa`, `sheet`, `unused`. The first is the wind
    angle the board should sail at: 180 degrees times the output, positive with the
    wind from starboard (0.25 is close-hauled on starboard, -0.83 a broad reach on
    port). The hands steer for that angle every tick and let the controller's heading
    hold do the steady part; when the angle wanted is on the other tack they ask for
    a tack or gybe (the controller chooses which), at most every 3 s.
  - `stick`: `steer`, `sheet`, `tack`. Steer is the stick of the beginner controller
    itself; a tack or gybe is asked for when tack rises above 0.5.
  In both, the sheet only takes over from the auto-sheet beyond 0.5 either way.
  `LearnedSkipper` reads a brain in the mode it was trained in (no `meta.actions`
  means `stick`, as the first brains were).
- `meta`: where the brain came from: the course, the training run, the generation,
  its fitness (the reward it collected in its race), how far it got, the date, the
  physics commit, the action mode, and the settings of the training.

`NeuralNet.load_file(path)` reads one; `LearnedSkipper` sails a board with it.

## How they are made

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
