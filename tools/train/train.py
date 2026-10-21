"""The trainer of the learned head (AI_FLEET_PLAN.md, D6b): PPO from Stable-Baselines3 on the races
Godot sails over the bridge (bridge.py), one curriculum stage at a time, with a brain file written
every so often for the game and for tools/gens.sh. Use tools/train.sh; it finds Godot and runs this.

    python tools/train/train.py --stage=S1 --run=s1 --hours=3 [options]

Options (the defaults in brackets):
  --stage=S1            the curriculum stage (Game/race/training_drops.gd: S1 to S6)
  --stages=S1,S2,S3     the nights unattended: the stages one after another, each run named after
                        its stage (s1, s2, ...), each starting from the one before's best brain (or
                        continuing its own model if it has one), each ended when its "done when"
                        number holds at a check (--check_every_min, --check_episodes: the brain
                        evaluated on fresh drops, against the all-rounder where the number needs it)
                        or after --hours_each. AI_FLEET_PLAN.md D6b's table: S1 the speed made good
                        80 % of the all-rounder's; S2 and S3 80 % of the drops round within 40 s; S4
                        finishes 90 % within 1.3 times the all-rounder's time; S5 starts 90 % within
                        10 s of the gun with OCS under 10 %; S6 only ends by the hours.
  --run=<name>          [the stage, lower case] the run's name: the brains are <run>_gen<N>.json and
                        <run>_best.json in Game/race/brains, the logs and the model .sim_output/train/<run>/
  --hours=<h>           [6] stop after this long (also --minutes=<m> for a short try)
  --hours_each=<h>      [4] with --stages: the most a stage gets (also --minutes_each=<m>)
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
  --hidden=64,64        the policy's hidden layers (the game's NeuralNet runs whatever is exported)

Every rollout prints one line: the wall time, the timesteps and episodes done, the speed (decisions
a second), the mean reward and length of the last episodes, how many reached their goal, their
speed made good, falls and manoeuvres per episode, and the policy's noise. The same goes to
.sim_output/train/<run>/curve.csv.
"""

from __future__ import annotations

import argparse
import csv
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
# decision is half a second).
GAMMA_BY_STAGE = {"S1": 0.995, "S2": 0.99, "S3": 0.99, "S4": 0.998, "S5": 0.997, "S6": 0.998}
RECENT_EPISODES = 300


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--stage", default="S1")
    parser.add_argument("--run", default="")
    parser.add_argument("--hours", type=float, default=6.0)
    parser.add_argument("--minutes", type=float, default=0.0)
    parser.add_argument("--stages", default="")
    parser.add_argument("--hours_each", type=float, default=4.0)
    parser.add_argument("--minutes_each", type=float, default=0.0)
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
    parser.add_argument("--hidden", default="64,64")
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
    return args


def physics_commit() -> str:
    try:
        return subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=str(REPO_ROOT), text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


# ---------------------------------------------------------------- a stage's "done when" number

SUMMARY_LINE = re.compile(r"^(?P<who>\w+): (?P<episodes>\d+) episodes, mean reward (?P<reward>-?[\d.]+), goal reached in "
                          r"(?P<goals>\d+) \((?P<goal_share>[\d.]+) %, mean (?P<goal_s>[\d.]+) s\), speed made good "
                          r"(?P<vmg>-?[\d.]+) m/s, (?P<falls>[\d.]+) falls and (?P<manoeuvres>[\d.]+) manoeuvres per episode"
                          r"(?:, started in (?P<starts>\d+) of (?P<with_start>\d+) \(mean (?P<start_s>[\d.]+) s after the gun\), "
                          r"OCS (?P<ocs>\d+) \((?P<ocs_share>[\d.]+) %\))?")
SHARE_LINE = re.compile(r"^The brain's speed made good is (?P<share>-?\d+) % of the")
# How much longer between checks and on how many drops, for the stages whose episodes take minutes.
CHECK_SCALE = {"S4": (2.0, 8), "S5": (2.0, 8), "S6": (2.0, 6)}


def needs_reference(stage: str) -> bool:
    return stage in ("S1", "S4")


def evaluate(brain_path: Path, stage: str, episodes: int, reference: str | None, log: Path) -> dict:
    """Runs the worker's evaluation on a brain (Game/dev/train_worker.gd --evaluate) and returns the
    summaries as the lines parse: {"brain": {...}, "allrounder": {...}, "share": P}."""
    from bridge import GAME_DIR, find_godot
    arguments = [find_godot(), "--headless", "--no-header", "--path", str(GAME_DIR), "-s", "res://dev/train_worker.gd", "--",
                 f"--evaluate={brain_path}", f"--stage={stage}", f"--episodes={episodes}", "--boards=1",
                 f"--seed={int(time.time()) % 100000}"]
    if reference:
        arguments.append(f"--reference={reference}")
    output = subprocess.run(arguments, capture_output=True, text=True, cwd=str(GAME_DIR), timeout=7200).stdout
    with open(log, "a", encoding="utf-8") as file:
        file.write(output + "\n")
    result: dict = {}
    for line in output.splitlines():
        match = SUMMARY_LINE.match(line.strip())
        if match:
            row = {k: (v if k == "who" else (float(v) if v is not None else None)) for k, v in match.groupdict().items()}
            result[match.group("who")] = row
            continue
        match = SHARE_LINE.match(line.strip())
        if match:
            result["share"] = float(match.group("share"))
    return result


def stage_done(stage: str, result: dict) -> tuple[bool, str]:
    """Whether a stage's "done when" number holds, and the number in words."""
    brain = result.get("brain")
    if brain is None:
        return False, "no summary (the evaluation failed; see checks.log)"
    if stage == "S1":
        share = result.get("share", 0.0)
        return share >= 80.0, f"speed made good {brain['vmg']:.2f} m/s, {share:.0f} % of the all-rounder's (done at 80)"
    if stage in ("S2", "S3"):
        return (brain["goal_share"] >= 80.0 and brain["goal_s"] <= 40.0,
                f"rounds {brain['goal_share']:.0f} % of the drops, in {brain['goal_s']:.1f} s on average (done at 80 % within 40 s)")
    if stage == "S4":
        other = result.get("allrounder")
        ratio = brain["goal_s"] / max(other["goal_s"], 1.0) if other and other["goal_s"] > 0.0 else 9.9
        return (brain["goal_share"] >= 90.0 and ratio <= 1.3,
                f"finishes {brain['goal_share']:.0f} % of its laps in {brain['goal_s']:.0f} s, {ratio:.2f} times the all-rounder's "
                f"(done at 90 % within 1.3)")
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
        self.recent: deque[dict] = deque(maxlen=RECENT_EPISODES)
        self.best_reward = -float("inf")
        self.rollouts = 0
        self.last_rollout_time = time.time()
        self.last_rollout_steps = 0
        self.curve_path = run_dir / "curve.csv"
        new_file = not self.curve_path.exists()
        self.curve = open(self.curve_path, "a", encoding="utf-8", newline="")
        self.writer = csv.writer(self.curve)
        if new_file:
            self.writer.writerow(["hours", "timesteps", "episodes", "steps_per_s", "reward_mean", "length_mean_s", "goal_share",
                                  "vmg_ms", "falls_per_episode", "manoeuvres_per_episode", "policy_std", "generation"])
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
        return time.time() - self.started < self.args.hours * 3600.0 and not self.stage_is_done

    def check_stage(self) -> None:
        """With --stages: the latest brain on fresh drops; the stage is done when its number holds."""
        scale, episodes = CHECK_SCALE.get(self.args.stage, (1.0, self.args.check_episodes))
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
        print(f"{hours:6.2f} h  {steps:9d} steps  {self.workers.episodes_done:6d} episodes  {speed:5.0f}/s  "
              f"reward {s['reward_mean']:7.2f}  length {s['length_mean_s']:5.1f} s  goal {100 * s['goal_share']:3.0f} %  "
              f"vmg {s['vmg_ms']:4.2f} m/s  falls {s['falls_per_episode']:4.2f}  manoeuvres {s['manoeuvres_per_episode']:4.1f}  "
              f"std {std:.2f}", flush=True)
        self.writer.writerow([f"{hours:.3f}", steps, self.workers.episodes_done, f"{speed:.0f}", f"{s['reward_mean']:.4f}",
                              f"{s['length_mean_s']:.1f}", f"{s['goal_share']:.3f}", f"{s['vmg_ms']:.3f}",
                              f"{s['falls_per_episode']:.3f}", f"{s['manoeuvres_per_episode']:.2f}", f"{std:.3f}", self.generation])
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
        meta = meta_for(self.args.run, self.args.stage, self.generation, self.model.num_timesteps, self.workers.episodes_done,
                        hours, s, self.commit, {"policy_std": round(self.policy_std(), 4)})
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
    if args.stages:
        stages = [part.strip().upper() for part in args.stages.split(",") if part.strip()]
        previous = ""
        for stage in stages:
            args.stage = stage
            args.run = stage.lower()
            args.hours = args.hours_each
            args.gamma = GAMMA_BY_STAGE.get(stage, 0.995)
            own_model = OUTPUT_DIR / args.run / "model.zip"
            if own_model.exists():
                args.resume = "auto"
            elif previous and (BRAINS_DIR / f"{previous}_best.json").exists():
                args.resume = str(BRAINS_DIR / f"{previous}_best.json")
            else:
                args.resume = "none"
            print(f"\n=== stage {stage} (run {args.run}, up to {args.hours:.1f} h, from {args.resume}) ===", flush=True)
            note = train_one(args)
            print(f"=== stage {stage} over: {note} ===", flush=True)
            previous = args.run
        return
    train_one(args)


def train_one(args: argparse.Namespace) -> str:
    """One run of one stage; returns the last check's note (or the hours)."""
    run_dir = OUTPUT_DIR / args.run
    run_dir.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(max(1, min(4, (os.cpu_count() or 4) // 4)))
    print(f"run {args.run}: stage {args.stage}, {args.hours:.2f} h, {args.workers} workers, seed {args.seed}, "
          f"gamma {args.gamma}, n_steps {args.n_steps}, batch {args.batch}, lr {args.lr}", flush=True)
    workers = GodotWorkers(stage=args.stage, workers=args.workers, boards=args.boards, log_dir=run_dir, seed=args.seed)
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
        model = PPO.load(args.resume, env=venv, device="cpu")
        resumed = True
        generation_file = Path(args.resume).parent / "generation.txt"
        if generation_file.exists():
            generation = int(generation_file.read_text().strip() or "0")
        print(f"resumed from {args.resume} at {model.num_timesteps} timesteps, generation {generation}", flush=True)
    else:
        model = PPO("MlpPolicy", venv, n_steps=args.n_steps, batch_size=args.batch, n_epochs=args.epochs, learning_rate=args.lr,
                    gamma=args.gamma, gae_lambda=args.gae, clip_range=args.clip, ent_coef=args.ent, policy_kwargs=policy_kwargs,
                    seed=args.seed, device="cpu", verbose=0)
        if args.resume.endswith(".json"):
            brain_path = Path(args.resume)
            if not brain_path.is_absolute():
                brain_path = REPO_ROOT / brain_path
            new_names = policy_from_brain(model.policy, load_brain(brain_path), obs_names)
            print(f"the policy starts from the brain {brain_path.name}"
                  + (f" ({len(new_names)} new inputs start at zero weight: {', '.join(new_names)})" if new_names else ""), flush=True)
        else:
            if args.resume not in ("auto", "none", ""):
                print(f"nothing to resume from at {args.resume}: starting from scratch", flush=True)
            if args.twa_bias != 0.0:
                # A fresh policy's mean wind angle: a close reach on starboard, so the boards sail
                # from the first decision (0 would be head to wind).
                with torch.no_grad():
                    model.policy.action_net.bias[0] = args.twa_bias
    print(f"the policy: {hidden} hidden, {sum(p.numel() for p in model.policy.parameters())} parameters in all "
          f"(the value network included)", flush=True)

    progress = Progress(args, run_dir, workers, obs_names, action_names, generation)
    try:
        model.learn(total_timesteps=10**12, callback=progress, reset_num_timesteps=not resumed)
    except KeyboardInterrupt:
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
