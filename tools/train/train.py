"""The trainer of the learned head (AI_FLEET_PLAN.md, D6b): PPO from Stable-Baselines3 on the races
Godot sails over the bridge (bridge.py), one curriculum stage at a time, with a brain file written
every so often for the game and for tools/gens.sh. Use tools/train.sh; it finds Godot and runs this.

    python tools/train/train.py --stage=S1 --run=s1 --hours=3 [options]

Options (the defaults in brackets):
  --stage=S1            the curriculum stage (Game/race/training_drops.gd: S1 to S6, and C1 and C2
                        on the plan's two courses, T1 and T2 at 12 to 24 kt: C1 a leg or two, C2
                        the whole course alone against the clock)
  --stages=C1,C2        the nights unattended: the stages one after another, each run named after
                        its stage (c1, c2, ...; with --run_prefix=tk: tk_c1, tk_c2, ...); each
                        continues its own model if it has one, else starts from the best brain of
                        the stage before it (STAGE_BEFORE: S2 from S1, ..., C2 from C1; the first
                        stage listed from --resume=<brain> if given, else afresh); each ended when
                        its "done when" number holds at a check (--check_every_min, --check_episodes:
                        the brain on a fixed set of drops of its own, CHECK_SEED, against the
                        all-rounder on the same drops, whose number is kept in the run's folder) or
                        after --hours_each. The bars are shares of the all-rounder's own numbers
                        (RA14; stage_done()): S1 its speed made good (100 %); S2 and S3 90 % of its
                        roundings within 1.1 times its time; S4 90 % of its laps within 1.3 times;
                        C1 90 % of its goals and of its speed made good; C2 as many finishes as it,
                        no slower. S5 starts 90 % within 10 s of the gun with OCS under 10 %; S6
                        only ends by the hours.
  --run_prefix=<name>   with --stages: the runs are <name>_s1, <name>_s2, ... (the brains
                        <name>_s1_best.json, ...), so a new curriculum does not write over the
                        brains of an earlier one (Game/race/brains/s1_*.json are 21 October's)
  --run=<name>          [the stage, lower case] the run's name: the brains are <run>_gen<N>.json and
                        <run>_best.json in Game/race/brains, the logs and the model .sim_output/train/<run>/
  --hours=<h>           [6] stop after this long (also --minutes=<m> for a short try)
  --hours_each=<h>      [4] with --stages: the most a stage gets (also --minutes_each=<m>)
  --stage_hours=C1:6,C2:14  with --stages: the most these stages get, in place of --hours_each
  --check_every_min=<m> [60] with --stages: how often a stage's number is checked (S4 to S6: twice that)
  --check_episodes=<n>  [20] with --stages: the drops of a check (S4 and S5: 8, S6: 6)
  --resume=auto|<file>  [auto] continue from this run's own model if it has one; a brain .json from
                        another run (the stage before) to start from its weights; a model .zip; or
                        "none" to start from scratch
  --workers=<n>         [the cores, at most 16] Godot processes, one race each
  --boards=<n>          [the stage's] boards per race
  --seed=<n>            [1]
  --save_every_min=<m>  [30] a brain file (<run>_gen<N>.json, N counting up) and the model this often
  --n_steps=128 --batch=512 --epochs=10 --lr=3e-4 --gamma=auto --gae=0.95 --clip=0.2 --ent=0.0
  --log_std_init=-1.5   how much the policy explores at first (the log of the noise on each action:
                        0.22 of the -1 to 1 range; a wider noise crosses 0 on the wind-angle output,
                        which is a tack, every few seconds)
  --twa_bias=0.3        a fresh policy's wind-angle output starts here (54 degrees on starboard, a
                        close reach), not at 0, which is head to wind: a board that starts in irons
                        learns nothing. Not used when resuming from a brain or a model.
  --push_start=auto     a fresh policy's push output (the push slider, the fourth output since
                        Session 64) starts here: "auto" is the slider level of the autopilot's own
                        margin (hike share 1.1, about 78 %), where the fleet sails today, as the
                        worker says in its hello; or a number from -1 (0 %) to 1 (100 %). Also for a
                        brain resumed without a push output. Not used when resuming a model.
  --hidden=64,64        the policy's hidden layers (the game's NeuralNet runs whatever is exported)
  --device=cpu          where the network learns: cpu, cuda (the graphics card) or auto (cuda if
                        torch has it). Measured in Session 64 (training.md): the physics in Godot is
                        the cost; the network is tiny.
  --manoeuvre_gap_s=auto  the tack discipline (RA14, LearnedSkipper): the least time between two
                        manoeuvres the hands allow, seconds; auto is the stage's (MANOEUVRE_GAP_S,
                        20 s). The brain's note keeps it, so the game sails the brain by the same rule.
  --manoeuvre_cost_m=auto  what a tack or gybe costs in the reward, metres; auto is the stage's (5)
  --recent=300          the line's and the curve's means are over this many of the last episodes
                        (a short try: fewer, to see a trend in a few hundred episodes)
  --own_conditions=0    1: in the blind stages that set boards down at once (S1 to S4, C1, C2) each
                        board sails its own conditions (its own wind, and in S1 to S4 its own sea,
                        gusts and shifts) instead of its race's (TrainingDrops.weather_for())

To stop a run cleanly (the model and a brain saved, the workers closed, the nights not going on to
the next stage): create the file .sim_output/train/STOP (touch .sim_output/train/STOP), or press
Ctrl-C once. The next start removes the file.

Every rollout prints one line: the wall time, the timesteps and episodes done, the speed (decisions
a second), the mean reward and length of the last episodes, how many reached their goal, their
speed made good, falls and manoeuvres per episode, the policy's noise, the mean push slider level
the policy asked for in the rollout, how long the network's update took ("learn") and the share
of the workers' time spent sailing ("busy": the rest they waited for the slowest worker, whose
race may be in a rough sea while another's is flat). The same goes to .sim_output/train/<run>/
curve.csv (without learn and busy).
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
from collections import deque
from pathlib import Path

import numpy as np
import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bridge import REPO_ROOT, GodotWorkers  # noqa: E402
from export import brain_from_policy, load_brain, meta_for, policy_from_brain, save_brain  # noqa: E402

from stable_baselines3 import PPO  # noqa: E402
from stable_baselines3.common.callbacks import BaseCallback  # noqa: E402
from stable_baselines3.common.vec_env import VecNormalize  # noqa: E402

BRAINS_DIR = REPO_ROOT / "Game/race/brains"
OUTPUT_DIR = REPO_ROOT / ".sim_output/train"
# The stages' discount: the short stages look about 100 s ahead, the long ones about 250 s (a
# decision is half a second): C1's legs (180 s episodes) 100 s, C2's whole course about a leg, the
# span over which a tack now pays off or costs.
GAMMA_BY_STAGE = {"S1": 0.995, "S2": 0.99, "S3": 0.99, "S4": 0.998, "S5": 0.997, "S6": 0.998, "C1": 0.995, "C2": 0.998}
# The stage whose best brain a stage of the nights starts from when it has no model of its own. C1
# has none: it starts from --resume (the brain the lead chooses), or afresh.
STAGE_BEFORE = {"S2": "S1", "S3": "S2", "S4": "S3", "S5": "S4", "S6": "S5", "C2": "C1"}
RECENT_EPISODES = 300
# The file that stops a run cleanly at the next decision (see the top).
STOP_FILE = OUTPUT_DIR / "STOP"
# Set when a run was stopped by hand (the file or Ctrl-C): the nights do not go on.
stopped_by_hand = False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--stage", default="S1")
    parser.add_argument("--run", default="")
    parser.add_argument("--hours", type=float, default=6.0)
    parser.add_argument("--minutes", type=float, default=0.0)
    parser.add_argument("--stages", default="")
    parser.add_argument("--run_prefix", default="")
    parser.add_argument("--hours_each", type=float, default=4.0)
    parser.add_argument("--minutes_each", type=float, default=0.0)
    parser.add_argument("--stage_hours", default="")
    parser.add_argument("--check_every_min", type=float, default=60.0)
    parser.add_argument("--check_episodes", type=int, default=20)
    parser.add_argument("--resume", default="auto")
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--boards", type=int, default=0)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--save_every_min", type=float, default=30.0)
    parser.add_argument("--n_steps", type=int, default=128)
    parser.add_argument("--batch", type=int, default=512)
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--gamma", default="auto")
    parser.add_argument("--gae", type=float, default=0.95)
    parser.add_argument("--clip", type=float, default=0.2)
    parser.add_argument("--ent", type=float, default=0.0)
    parser.add_argument("--log_std_init", type=float, default=-1.5)
    parser.add_argument("--twa_bias", type=float, default=0.3)
    parser.add_argument("--push_start", default="auto")
    parser.add_argument("--hidden", default="64,64")
    parser.add_argument("--device", default="cpu", choices=["cpu", "cuda", "auto"])
    parser.add_argument("--manoeuvre_gap_s", default="auto")
    parser.add_argument("--manoeuvre_cost_m", default="auto")
    parser.add_argument("--own_conditions", type=int, default=0)
    parser.add_argument("--recent", type=int, default=RECENT_EPISODES)
    args = parser.parse_args()
    args.stage = args.stage.upper()
    if not args.run:
        args.run = args.stage.lower()
    if args.minutes > 0.0:
        args.hours = args.minutes / 60.0
    if args.minutes_each > 0.0:
        args.hours_each = args.minutes_each / 60.0
    if args.workers <= 0:
        args.workers = min(os.cpu_count() or 4, 16)
    args.gamma = GAMMA_BY_STAGE.get(args.stage, 0.995) if args.gamma == "auto" else float(args.gamma)
    if args.device == "auto":
        args.device = "cuda" if torch.cuda.is_available() else "cpu"
    elif args.device == "cuda" and not torch.cuda.is_available():
        print("torch has no CUDA here: learning on the CPU", flush=True)
        args.device = "cpu"
    return args


def stage_run(prefix: str, stage: str) -> str:
    """The run of a stage in the nights: s1, or with a prefix all_s1."""
    return f"{prefix}_{stage.lower()}" if prefix else stage.lower()


def stage_hours(text: str) -> dict[str, float]:
    """--stage_hours=C1:6,C2:14 as {"C1": 6.0, "C2": 14.0}."""
    hours: dict[str, float] = {}
    for part in text.split(","):
        if ":" in part:
            name, value = part.split(":", 1)
            hours[name.strip().upper()] = float(value)
    return hours


def worker_args(args: argparse.Namespace) -> list[str]:
    """The worker's options the trainer sets: the tack discipline and the manoeuvre's cost, when
    not the stage's own ("auto")."""
    extra = []
    for name in ("manoeuvre_gap_s", "manoeuvre_cost_m"):
        value = getattr(args, name, "auto")
        if value != "auto":
            extra.append(f"--{name}={float(value)}")
    if getattr(args, "own_conditions", 0):
        extra.append("--own_conditions=1")
    return extra


def push_start_output(choice: str, hello: dict) -> float:
    """The push output a fresh policy starts at: the worker's (the autopilot's own margin) for
    "auto", else the number given."""
    if choice == "auto":
        return float(hello.get("push_start_output", 0.5))
    return max(-1.0, min(1.0, float(choice)))


def physics_commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=str(REPO_ROOT), text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


# ---------------------------------------------------------------- a stage's "done when" number

# The drops of every check of a stage (a set of their own, not the morning's seed 1): the same each
# time, so the checks of a night can be compared, and the all-rounder sails them once per run.
CHECK_SEED = 1001
SUMMARY_LINE = re.compile(r"^(?P<who>\w+): (?P<episodes>\d+) episodes, mean reward (?P<reward>-?[\d.]+), goal reached in "
                          r"(?P<goals>\d+) \((?P<goal_share>[\d.]+) %, mean (?P<goal_s>[\d.]+) s\), speed made good "
                          r"(?P<vmg>-?[\d.]+) m/s, (?P<falls>[\d.]+) falls and (?P<manoeuvres>[\d.]+) manoeuvres per episode"
                          r"(?:, started in (?P<starts>\d+) of (?P<with_start>\d+) \(mean (?P<start_s>[\d.]+) s after the gun\), "
                          r"OCS (?P<ocs>\d+) \((?P<ocs_share>[\d.]+) %\))?")
# How much longer between checks and on how many drops, for the stages whose episodes take minutes.
# (C2: a whole course is 3 to 15 minutes; a check stops the training while it runs, about 20
# minutes for 6 drops on a loaded machine, so every 2 hours.)
CHECK_SCALE = {"S4": (2.0, 8), "S5": (2.0, 8), "S6": (2.0, 6), "C2": (2.0, 6)}


# The stages' bars (RA14, Session 65): the brain's number as a share of the all-rounder's own on the
# same drops, never a fixed share of the drops. The all-rounder itself rounds 70 % of S3's drops and
# finishes 38 % of S4's laps (nights_review.md), so the old 80 and 90 % were out of anyone's reach,
# and S1's 80 % ended it after an hour while it was still improving.
VMG_BAR = {"S1": 1.0, "C1": 0.9}        # the speed made good, a share of the all-rounder's
GOAL_BAR = {"S2": 0.9, "S3": 0.9, "S4": 0.9, "C1": 0.9, "C2": 1.0}  # the goals reached, a share of its
TIME_BAR = {"S2": 1.1, "S3": 1.1, "S4": 1.3, "C2": 1.0}  # the mean time to the goal, at most this times its


def needs_reference(stage: str) -> bool:
    return stage in VMG_BAR or stage in GOAL_BAR


def run_evaluation(brain: str, stage: str, episodes: int, reference: str | None, seed: int) -> subprocess.Popen:
    """Starts the worker's evaluation (Game/dev/train_worker.gd --evaluate) of a brain file, or with
    brain "none" of the reference character alone."""
    from bridge import GAME_DIR, find_godot
    arguments = [find_godot(), "--headless", "--no-header", "--path", str(GAME_DIR), "-s", "res://dev/train_worker.gd", "--",
                 f"--evaluate={brain}", f"--stage={stage}", f"--episodes={episodes}", "--boards=1", f"--seed={seed}"]
    if reference:
        arguments.append(f"--reference={reference}")
    return subprocess.Popen(arguments, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, cwd=str(GAME_DIR))


def parse_summaries(output: str) -> dict:
    """The summary lines of an evaluation: {"brain": {...}, "allrounder": {...}}."""
    result: dict = {}
    for line in output.splitlines():
        match = SUMMARY_LINE.match(line.strip())
        if match:
            row = {k: (v if k == "who" else (float(v) if v is not None else None)) for k, v in match.groupdict().items()}
            result[match.group("who")] = row
    return result


def evaluate(brain_path: Path, stage: str, episodes: int, reference: str | None, log: Path, seed: int = CHECK_SEED) -> dict:
    """A brain on a stage's drops and, with a reference, that character on the same drops, in two
    Godot processes side by side; the reference's summary is kept in the log's folder for the same
    stage, drops and seed (the scripted character sails them the same way every time). Returns
    {"brain": {...}, "allrounder": {...}, "share": P}, P the brain's speed made good in % of the
    reference's."""
    kept = log.parent / f"reference_{stage}_{reference}_{episodes}_{seed}.json" if reference else None
    reference_row = None
    if kept is not None and kept.exists():
        reference_row = json.loads(kept.read_text())
    brain_run = run_evaluation(str(brain_path), stage, episodes, None, seed)
    reference_run = run_evaluation("none", stage, episodes, reference, seed) if reference and reference_row is None else None
    output = brain_run.communicate(timeout=7200)[0]
    if reference_run is not None:
        reference_output = reference_run.communicate(timeout=7200)[0]
        output += "\n" + reference_output
        reference_row = parse_summaries(reference_output).get(reference)
        if reference_row is not None and kept is not None:
            kept.write_text(json.dumps(reference_row))
    with open(log, "a", encoding="utf-8") as file:
        file.write(output + "\n")
    result = parse_summaries(output)
    if reference_row is not None:
        result[reference] = reference_row
        if "brain" in result:
            result["share"] = 100.0 * result["brain"]["vmg"] / max(reference_row["vmg"], 0.01)
    return result


def stage_done(stage: str, result: dict) -> tuple[bool, str]:
    """Whether a stage's "done when" number holds, and the number in words: the brain's speed made
    good, goals and time to the goal against the all-rounder's on the same drops (VMG_BAR, GOAL_BAR,
    TIME_BAR); S5's starts as they are; S6 by its hours."""
    brain = result.get("brain")
    if brain is None:
        return False, "no summary (the evaluation failed; see checks.log)"
    if needs_reference(stage):
        other = result.get("allrounder")
        if other is None:
            return False, "no summary of the all-rounder (see checks.log)"
        done = True
        words = []
        if stage in VMG_BAR:
            share = brain["vmg"] / max(other["vmg"], 0.01)
            done = done and share >= VMG_BAR[stage]
            words.append(f"speed made good {brain['vmg']:.2f} m/s, {100 * share:.0f} % of the all-rounder's {other['vmg']:.2f} "
                         f"(done at {100 * VMG_BAR[stage]:.0f})")
        if stage in GOAL_BAR:
            if other["goal_share"] <= 0.0:
                return False, "the all-rounder reached no goal on these drops: they cannot be a bar"
            share = brain["goal_share"] / other["goal_share"]
            done = done and share >= GOAL_BAR[stage]
            words.append(f"goal {brain['goal_share']:.0f} % against the all-rounder's {other['goal_share']:.0f} % "
                         f"({100 * share:.0f} %, done at {100 * GOAL_BAR[stage]:.0f})")
        if stage in TIME_BAR:
            ratio = brain["goal_s"] / max(other["goal_s"], 1.0) if brain["goals"] > 0 else 9.9
            done = done and ratio <= TIME_BAR[stage]
            words.append(f"in {brain['goal_s']:.0f} s, {ratio:.2f} times its {other['goal_s']:.0f} s (done at {TIME_BAR[stage]:.2f})")
        words.append(f"{brain['manoeuvres']:.1f} manoeuvres per episode against its {other['manoeuvres']:.1f}")
        return done, "; ".join(words)
    if stage == "S5":
        starts = brain.get("starts")
        with_start = brain.get("with_start") or 0.0
        if starts is None or with_start <= 0.0:
            return False, "no starts seen"
        started_share = 100.0 * starts / with_start
        ocs_share = brain.get("ocs_share") or 0.0
        return (started_share >= 90.0 and brain["start_s"] <= 10.0 and ocs_share <= 10.0,
                f"starts {started_share:.0f} % of the time, {brain['start_s']:.1f} s after the gun on average, OCS {ocs_share:.0f} % "
                f"(done at 90 % within 10 s and OCS under 10 %)")
    return False, f"reward {brain['reward']:.2f}, goal {brain['goal_share']:.0f} % (S6 ends by its hours)"


class Progress(BaseCallback):
    """Prints a line per rollout, keeps the curve, writes the brains and stops when the time is up
    or the stage's number holds at a check."""

    def __init__(self, args: argparse.Namespace, run_dir: Path, env: GodotWorkers, obs_names: list[str],
                 action_names: list[str], started_generation: int) -> None:
        super().__init__(verbose=0)
        self.args = args
        self.run_dir = run_dir
        self.stage_is_done = False
        self.last_check = time.time()
        self.check_note = ""
        self.workers = env
        self.obs_names = obs_names
        self.action_names = action_names
        self.started = time.time()
        self.last_save = time.time()
        self.generation = started_generation
        self.recent: deque[dict] = deque(maxlen=max(1, args.recent))
        self.best_reward = -float("inf")
        self.rollouts = 0
        self.last_rollout_time = time.time()
        self.last_rollout_steps = 0
        # How long the last update of the network took (between a rollout's end and the next
        # one's start): the part the graphics card could speed up.
        self.learn_s = 0.0
        self.curve_path = run_dir / "curve.csv"
        new_file = not self.curve_path.exists()
        self.curve = open(self.curve_path, "a", encoding="utf-8", newline="")
        self.writer = csv.writer(self.curve)
        if new_file:
            self.writer.writerow(["hours", "timesteps", "episodes", "steps_per_s", "reward_mean", "length_mean_s", "goal_share",
                                  "vmg_ms", "falls_per_episode", "manoeuvres_per_episode", "policy_std", "generation", "push_mean"])
        self.commit = physics_commit()

    def _on_step(self) -> bool:
        for info in self.locals.get("infos", []):
            if "episode" in info:
                self.recent.append({
                    "reward": info["episode"]["r"],
                    "length_s": info.get("episode_s", info["episode"]["l"] * 0.5),
                    "goal": 1.0 if info.get("finished") else 0.0,
                    "progress_m": info.get("progress_m", 0.0),
                    "falls": info.get("falls", 0),
                    "manoeuvres": info.get("manoeuvres", 0),
                })
        global stopped_by_hand
        if STOP_FILE.exists():
            print(f"stopped by hand ({STOP_FILE} is there)", flush=True)
            stopped_by_hand = True
            return False
        return time.time() - self.started < self.args.hours * 3600.0 and not self.stage_is_done

    def _on_rollout_start(self) -> None:
        if self.rollouts > 0:
            self.learn_s = time.time() - self.last_rollout_time

    def check_stage(self) -> None:
        """With --stages: the latest brain on fresh drops; the stage is done when its number holds."""
        scale, episodes = CHECK_SCALE.get(self.args.stage, (1.0, self.args.check_episodes))
        episodes = min(episodes, self.args.check_episodes)  # a short try asks for fewer
        if time.time() - self.last_check < self.args.check_every_min * 60.0 * scale:
            return
        self.last_check = time.time()
        started = time.time()
        result = evaluate(BRAINS_DIR / f"{self.args.run}_latest.json", self.args.stage, episodes,
                          "allrounder" if needs_reference(self.args.stage) else None, self.run_dir / "checks.log")
        done, note = stage_done(self.args.stage, result)
        self.check_note = note
        print(f"  check ({episodes} drops, {(time.time() - started) / 60.0:.1f} min): {note}{' -- DONE' if done else ''}", flush=True)
        if done:
            self.stage_is_done = True

    def stats(self) -> dict:
        if not self.recent:
            return {"reward_mean": 0.0, "length_mean_s": 0.0, "goal_share": 0.0, "vmg_ms": 0.0,
                    "falls_per_episode": 0.0, "manoeuvres_per_episode": 0.0}
        rows = list(self.recent)
        time_s = sum(r["length_s"] for r in rows)
        return {
            "reward_mean": float(np.mean([r["reward"] for r in rows])),
            "length_mean_s": float(np.mean([r["length_s"] for r in rows])),
            "goal_share": float(np.mean([r["goal"] for r in rows])),
            "vmg_ms": float(sum(r["progress_m"] for r in rows) / max(time_s, 0.1)),
            "falls_per_episode": float(np.mean([r["falls"] for r in rows])),
            "manoeuvres_per_episode": float(np.mean([r["manoeuvres"] for r in rows])),
        }

    def policy_std(self) -> float:
        try:
            return float(torch.exp(self.model.policy.log_std.detach()).mean())
        except AttributeError:
            return 0.0

    def push_mean(self) -> float:
        """The mean push slider level (0 to 1) the policy asked for in the last rollout; -1 for a
        policy without a push output."""
        if "push" not in self.action_names:
            return -1.0
        actions = np.asarray(self.model.rollout_buffer.actions)[..., self.action_names.index("push")]
        return float(np.mean(np.clip(0.5 * (actions + 1.0), 0.0, 1.0)))

    def _on_rollout_end(self) -> None:
        self.rollouts += 1
        now = time.time()
        hours = (now - self.started) / 3600.0
        steps = self.model.num_timesteps
        speed = (steps - self.last_rollout_steps) / max(now - self.last_rollout_time, 1e-3)
        self.last_rollout_time = now
        self.last_rollout_steps = steps
        s = self.stats()
        std = self.policy_std()
        push = self.push_mean()
        busy = self.workers.busy_share()
        print(f"{hours:6.2f} h  {steps:9d} steps  {self.workers.episodes_done:6d} episodes  {speed:5.0f}/s  "
              f"reward {s['reward_mean']:7.2f}  length {s['length_mean_s']:5.1f} s  goal {100 * s['goal_share']:3.0f} %  "
              f"vmg {s['vmg_ms']:4.2f} m/s  falls {s['falls_per_episode']:4.2f}  manoeuvres {s['manoeuvres_per_episode']:4.1f}  "
              f"std {std:.2f}" + (f"  push {100 * push:3.0f} %" if push >= 0.0 else "") + f"  learn {self.learn_s:.2f} s  busy {100 * busy:3.0f} %"
              + (f"  ({self.workers.bad_numbers} numbers were not numbers)" if self.workers.bad_numbers else ""), flush=True)
        self.writer.writerow([f"{hours:.3f}", steps, self.workers.episodes_done, f"{speed:.0f}", f"{s['reward_mean']:.4f}",
                              f"{s['length_mean_s']:.1f}", f"{s['goal_share']:.3f}", f"{s['vmg_ms']:.3f}",
                              f"{s['falls_per_episode']:.3f}", f"{s['manoeuvres_per_episode']:.2f}", f"{std:.3f}", self.generation,
                              f"{push:.3f}"])
        self.curve.flush()
        if now - self.last_save >= self.args.save_every_min * 60.0:
            self.last_save = now
            self.save_generation()
            if self.args.stages:
                self.check_stage()

    def save_generation(self, final: bool = False) -> None:
        """The model (to resume from) and a brain file for the game; the best so far kept apart."""
        self.generation += 1
        s = self.stats()
        hours = (time.time() - self.started) / 3600.0
        # The tack discipline and the manoeuvre's cost it learned with (RA14): the game sails it by
        # the same rule (LearnedSkipper.gap_of()).
        rules = {key: self.workers.hello[key] for key in ("manoeuvre_gap_s", "closest_twa_deg", "manoeuvre_cost_m", "own_conditions")
                 if key in self.workers.hello}
        meta = meta_for(self.args.run, self.args.stage, self.generation, self.model.num_timesteps, self.workers.episodes_done,
                        hours, s, self.commit, {"policy_std": round(self.policy_std(), 4), "ent_coef": self.args.ent, **rules})
        brain = brain_from_policy(self.model.policy, self.obs_names, self.action_names, meta)
        save_brain(brain, BRAINS_DIR / f"{self.args.run}_gen{self.generation}.json")
        save_brain(brain, BRAINS_DIR / f"{self.args.run}_latest.json")
        if self.recent and s["reward_mean"] > self.best_reward:
            self.best_reward = s["reward_mean"]
            save_brain(brain, BRAINS_DIR / f"{self.args.run}_best.json")
        self.model.save(self.run_dir / "model.zip")
        venv = self.model.get_env()
        if isinstance(venv, VecNormalize):
            venv.save(str(self.run_dir / "vecnormalize.pkl"))
        with open(self.run_dir / "generation.txt", "w", encoding="utf-8") as file:
            file.write(str(self.generation))
        print(f"  saved generation {self.generation}: {self.args.run}_gen{self.generation}.json"
              f"{' (the best so far)' if s['reward_mean'] >= self.best_reward and self.recent else ''}"
              f"{' (final)' if final else ''}", flush=True)


def main() -> None:
    args = parse_args()
    if STOP_FILE.exists():
        STOP_FILE.unlink()
        print(f"removed {STOP_FILE} (left from the last stop)", flush=True)
    if args.stages:
        stages = [part.strip().upper() for part in args.stages.split(",") if part.strip()]
        # A brain given with --resume starts the first stage listed (when it has no model of its
        # own and the stage before it no best brain).
        first_brain = args.resume if args.resume.endswith(".json") else ""
        hours_of = stage_hours(args.stage_hours)
        for stage in stages:
            args.stage = stage
            args.run = stage_run(args.run_prefix, stage)
            args.hours = hours_of.get(stage, args.hours_each)
            args.gamma = GAMMA_BY_STAGE.get(stage, 0.995)
            own_model = OUTPUT_DIR / args.run / "model.zip"
            # The stage before in the curriculum, whichever stages were listed: a stage always goes
            # on from the one before's best brain.
            before = STAGE_BEFORE.get(stage, "")
            before_best = BRAINS_DIR / f"{stage_run(args.run_prefix, before)}_best.json" if before else None
            if own_model.exists():
                args.resume = "auto"
            elif before_best is not None and before_best.exists():
                args.resume = str(before_best)
            elif stage == stages[0] and first_brain:
                args.resume = first_brain
            else:
                args.resume = "none"
            print(f"\n=== stage {stage} (run {args.run}, up to {args.hours:.2f} h, from {args.resume}) ===", flush=True)
            note = train_stage_with_retries(args)
            print(f"=== stage {stage} over: {note} ===", flush=True)
            if stopped_by_hand:
                print(f"=== the nights stop here (stopped by hand); to go on, run the command again with --stages= from "
                      f"{stage} on: each stage continues its own model, or starts from the best brain of the one before ===", flush=True)
                return
        return
    train_one(args)


# How often a stage of the unattended nights is started again after its training stopped on an
# error (a Godot worker that crashed or stopped answering), each time from the model it saved.
STAGE_ATTEMPTS = 4


def train_stage_with_retries(args: argparse.Namespace) -> str:
    """One stage of the nights: if the training stops on an error, the stage goes on from the
    model it saved on the way out (train_one saves it whatever happens), for the hours it has left,
    up to STAGE_ATTEMPTS times; then the error stops the nights."""
    started = time.time()
    hours = args.hours
    for attempt in range(1, STAGE_ATTEMPTS + 1):
        try:
            return train_one(args)
        except Exception as error:  # noqa: BLE001 - any error of a worker or the bridge
            left_h = hours - (time.time() - started) / 3600.0
            print(f"=== stage {args.stage}: the training stopped on an error (attempt {attempt} of {STAGE_ATTEMPTS}): "
                  f"{type(error).__name__}: {error} ===", flush=True)
            if attempt == STAGE_ATTEMPTS or left_h < 0.05:
                raise
            args.resume = "auto"
            args.hours = left_h
            print(f"=== stage {args.stage}: going on from its saved model for {left_h:.2f} h ===", flush=True)
    return ""


def train_one(args: argparse.Namespace) -> str:
    """One run of one stage; returns the last check's note (or the hours)."""
    run_dir = OUTPUT_DIR / args.run
    run_dir.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(max(1, min(4, (os.cpu_count() or 4) // 4)))
    print(f"run {args.run}: stage {args.stage}, {args.hours:.2f} h, {args.workers} workers, seed {args.seed}, "
          f"gamma {args.gamma}, n_steps {args.n_steps}, batch {args.batch}, lr {args.lr}, ent {args.ent}, on the {args.device}", flush=True)
    workers = GodotWorkers(stage=args.stage, workers=args.workers, boards=args.boards, log_dir=run_dir, seed=args.seed,
                           extra_args=worker_args(args))
    obs_names = list(workers.hello["obs_names"])
    action_names = list(workers.hello["action_names"])
    hidden = [int(part) for part in args.hidden.split(",") if part.strip()]
    policy_kwargs = dict(net_arch=dict(pi=hidden, vf=hidden), activation_fn=nn.Tanh, log_std_init=args.log_std_init)
    venv = VecNormalize(workers, norm_obs=False, norm_reward=True, gamma=args.gamma)

    model_path = run_dir / "model.zip"
    generation = 0
    resumed = False
    if args.resume == "auto" and model_path.exists():
        args.resume = str(model_path)
    if args.resume.endswith(".zip") and Path(args.resume).exists():
        stats_path = Path(args.resume).parent / "vecnormalize.pkl"
        if stats_path.exists():
            venv = VecNormalize.load(str(stats_path), workers)
            venv.norm_obs = False
        model = PPO.load(args.resume, env=venv, device=args.device)
        resumed = True
        generation_file = Path(args.resume).parent / "generation.txt"
        if generation_file.exists():
            generation = int(generation_file.read_text().strip() or "0")
        print(f"resumed from {args.resume} at {model.num_timesteps} timesteps, generation {generation}", flush=True)
    else:
        model = PPO("MlpPolicy", venv, n_steps=args.n_steps, batch_size=args.batch, n_epochs=args.epochs, learning_rate=args.lr,
                    gamma=args.gamma, gae_lambda=args.gae, clip_range=args.clip, ent_coef=args.ent, policy_kwargs=policy_kwargs,
                    seed=args.seed, device=args.device, verbose=0)
        # A fresh policy's starting answers (SB3 starts the last layer's weights near zero, so its
        # outputs are its biases): the wind angle a close reach on starboard (0 would be head to
        # wind, in irons), the push the autopilot's own margin (the fleet as it sails today).
        push_start = push_start_output(args.push_start, workers.hello)
        with torch.no_grad():
            if args.twa_bias != 0.0 and "twa" in action_names:
                model.policy.action_net.bias[action_names.index("twa")] = args.twa_bias
            if "push" in action_names:
                model.policy.action_net.bias[action_names.index("push")] = push_start
        if "push" in action_names:
            print(f"the push output starts at {push_start:.3f}: the slider at {50.0 * (push_start + 1.0):.0f} %", flush=True)
        if args.resume.endswith(".json"):
            brain_path = Path(args.resume)
            if not brain_path.is_absolute():
                brain_path = REPO_ROOT / brain_path
            new_names, new_outputs = policy_from_brain(model.policy, load_brain(brain_path), obs_names, action_names)
            print(f"the policy starts from the brain {brain_path.name}"
                  + (f" ({len(new_names)} new inputs start at zero weight: {', '.join(new_names)})" if new_names else "")
                  + (f" (new outputs start fresh: {', '.join(new_outputs)})" if new_outputs else ""), flush=True)
        elif args.resume not in ("auto", "none", ""):
            print(f"nothing to resume from at {args.resume}: starting from scratch", flush=True)
    print(f"the policy: {hidden} hidden, {sum(p.numel() for p in model.policy.parameters())} parameters in all "
          f"(the value network included)", flush=True)

    progress = Progress(args, run_dir, workers, obs_names, action_names, generation)
    try:
        model.learn(total_timesteps=10**12, callback=progress, reset_num_timesteps=not resumed)
    except KeyboardInterrupt:
        global stopped_by_hand
        stopped_by_hand = True
        print("stopped by hand", flush=True)
    finally:
        progress.save_generation(final=True)
        progress.curve.close()
        workers.close()
    print(f"done: {model.num_timesteps} timesteps, {workers.episodes_done} episodes, the curve in {progress.curve_path}, "
          f"the brains {args.run}_gen<N>.json, {args.run}_best.json and {args.run}_latest.json in {BRAINS_DIR}", flush=True)
    return progress.check_note if progress.check_note else f"{args.hours:.1f} h"


if __name__ == "__main__":
    main()
