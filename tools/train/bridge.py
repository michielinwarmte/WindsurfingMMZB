"""The Python side of the bridge to Godot (RACING_PLAN.md, RD3; AI_FLEET_PLAN.md, D6b).

GodotWorkers is a Stable-Baselines3 VecEnv: it starts one headless Godot per worker, each running
one race of a curriculum stage with several boards (Game/dev/train_worker.gd, TrainBridge), and
talks to each over a TCP socket, one JSON line per message. Every board of every worker is one
environment of the vector: with 14 workers of 4 boards the trainer sees 56 environments, all sailed
by the one network it is learning.

The protocol (the worker's side is documented in TrainBridge):
  worker -> trainer   {"hello": {...}}                               once, after connecting
  trainer -> worker   {"cmd": "reset", "seed": n}                    -> {"obs": [[...]], "race": {...}}
  trainer -> worker   {"cmd": "step", "actions": [[...]], "seed": n} -> {"obs", "rew", "done", "trunc",
                                                                         "info", "terminal_obs"}
  trainer -> worker   {"cmd": "close"}
"""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import numpy as np
from gymnasium import spaces
from stable_baselines3.common.vec_env import VecEnv

REPO_ROOT = Path(__file__).resolve().parents[2]
GAME_DIR = REPO_ROOT / "Game"
WORKER_SCRIPT = "res://dev/train_worker.gd"
# The observation is scaled to about -1 to 1 and clipped at 2 (RaceObservation.CLIP); 3 is safe.
OBS_BOUND = 3.0
CONNECT_TIMEOUT_S = 120.0
REPLY_TIMEOUT_S = 600.0


def find_godot() -> str:
    """The Godot executable: $GODOT, or the one tools/install_godot.sh puts in ~/.local/opt."""
    candidate = os.environ.get("GODOT")
    if candidate and Path(candidate).exists():
        return candidate
    installed = Path.home() / ".local/opt/godot/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64"
    if installed.exists():
        return str(installed)
    raise RuntimeError("Godot was not found: set GODOT to the Godot 4.7.2 executable (tools/common.sh says where).")


class Worker:
    """One Godot process and its socket."""

    def __init__(self, index: int, process: subprocess.Popen, log: Any) -> None:
        self.index = index
        self.process = process
        self.log = log
        self.connection: socket.socket | None = None
        self.reader: Any = None
        self.hello: dict = {}
        self.boards = 0
        self.race: dict = {}

    def send(self, message: dict) -> None:
        assert self.connection is not None
        self.connection.sendall((json.dumps(message, separators=(",", ":")) + "\n").encode("utf-8"))

    def receive(self) -> dict:
        line = self.reader.readline()
        if not line:
            raise RuntimeError(f"worker {self.index} closed its connection (see its log)")
        return json.loads(line)

    def close(self) -> None:
        try:
            if self.connection is not None:
                self.send({"cmd": "close"})
                self.connection.close()
        except OSError:
            pass
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.kill()
        if self.log is not None:
            self.log.close()


class GodotWorkers(VecEnv):
    """A vector of environments: every board of every Godot worker."""

    def __init__(self, stage: str, workers: int, boards: int, log_dir: Path, seed: int = 1,
                 godot: str | None = None, verbose: bool = True) -> None:
        self.stage = stage
        self.worker_count = workers
        self.boards_per_worker = boards
        self.log_dir = log_dir
        self.base_seed = seed
        self.godot = godot or find_godot()
        self.verbose = verbose
        self.workers: list[Worker] = []
        self.hello: dict = {}
        self._step_counter = 0
        self._actions: np.ndarray | None = None
        self._episode_rewards: np.ndarray | None = None
        self._episode_lengths: np.ndarray | None = None
        self.episodes_done = 0
        self._launch()
        obs_size = int(self.hello["obs_size"])
        action_size = int(self.hello["action_size"])
        observation_space = spaces.Box(-OBS_BOUND, OBS_BOUND, shape=(obs_size,), dtype=np.float32)
        action_space = spaces.Box(-1.0, 1.0, shape=(action_size,), dtype=np.float32)
        total = sum(w.boards for w in self.workers)
        super().__init__(total, observation_space, action_space)
        self._episode_rewards = np.zeros(total, dtype=np.float64)
        self._episode_lengths = np.zeros(total, dtype=np.int64)

    # ------------------------------------------------------------------ starting the workers

    def _launch(self) -> None:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.bind(("127.0.0.1", 0))
        server.listen(self.worker_count)
        port = server.getsockname()[1]
        self.log_dir.mkdir(parents=True, exist_ok=True)
        for i in range(self.worker_count):
            log = open(self.log_dir / f"worker_{i}.log", "w", encoding="utf-8")
            arguments = [self.godot, "--headless", "--no-header", "--path", str(GAME_DIR), "-s", WORKER_SCRIPT, "--",
                         f"--port={port}", f"--worker={i}", f"--stage={self.stage}", f"--boards={self.boards_per_worker}"]
            process = subprocess.Popen(arguments, stdout=log, stderr=subprocess.STDOUT, cwd=str(GAME_DIR))
            self.workers.append(Worker(i, process, log))
        server.settimeout(CONNECT_TIMEOUT_S)
        by_index: dict[int, Worker] = {w.index: w for w in self.workers}
        connected = 0
        started = time.time()
        while connected < self.worker_count:
            try:
                connection, _ = server.accept()
            except socket.timeout as error:
                raise RuntimeError(f"only {connected} of {self.worker_count} workers connected within {CONNECT_TIMEOUT_S:.0f} s "
                                   f"(see {self.log_dir}/worker_*.log)") from error
            connection.settimeout(REPLY_TIMEOUT_S)
            connection.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            reader = connection.makefile("rb")
            line = reader.readline()
            hello = json.loads(line)["hello"]
            worker = by_index[int(hello["worker"])]
            worker.connection = connection
            worker.reader = reader
            worker.hello = hello
            worker.boards = int(hello["boards"])
            connected += 1
        server.close()
        self.workers.sort(key=lambda w: w.index)
        self.hello = self.workers[0].hello
        if self.verbose:
            print(f"{self.worker_count} workers connected in {time.time() - started:.1f} s: {self.hello['stage_description']}; "
                  f"{sum(w.boards for w in self.workers)} boards in all, {self.hello['obs_size']} numbers seen, "
                  f"a decision every {self.hello['decision_s']:.2f} s", flush=True)

    # ------------------------------------------------------------------ the VecEnv

    def reset(self) -> np.ndarray:
        self._step_counter += 1
        for k, worker in enumerate(self.workers):
            worker.send({"cmd": "reset", "seed": self._seed_for(k)})
        rows: list[list[float]] = []
        for worker in self.workers:
            reply = worker.receive()
            worker.race = reply.get("race", {})
            rows.extend(reply["obs"])
        self._episode_rewards[:] = 0.0
        self._episode_lengths[:] = 0
        return np.asarray(rows, dtype=np.float32)

    def step_async(self, actions: np.ndarray) -> None:
        self._actions = np.asarray(actions, dtype=np.float32)

    def step_wait(self):
        assert self._actions is not None
        self._step_counter += 1
        offset = 0
        for k, worker in enumerate(self.workers):
            chunk = self._actions[offset:offset + worker.boards]
            offset += worker.boards
            worker.send({"cmd": "step", "actions": chunk.tolist(), "seed": self._seed_for(k)})
        rows: list[list[float]] = []
        rewards: list[float] = []
        dones: list[bool] = []
        infos: list[dict] = []
        offset = 0
        for worker in self.workers:
            reply = worker.receive()
            if "error" in reply:
                raise RuntimeError(f"worker {worker.index}: {reply['error']}")
            if "race" in reply:
                worker.race = reply["race"]
            for i in range(worker.boards):
                env_index = offset + i
                reward = float(reply["rew"][i])
                done = bool(reply["done"][i])
                self._episode_rewards[env_index] += reward
                self._episode_lengths[env_index] += 1
                info: dict = {}
                if done:
                    stats = reply["info"][i] or {}
                    info.update(stats)
                    info["terminal_observation"] = np.asarray(reply["terminal_obs"][i], dtype=np.float32)
                    if reply["trunc"][i]:
                        info["TimeLimit.truncated"] = True
                    info["episode"] = {"r": float(self._episode_rewards[env_index]), "l": int(self._episode_lengths[env_index]),
                                       "t": time.time()}
                    info["race"] = worker.race
                    self._episode_rewards[env_index] = 0.0
                    self._episode_lengths[env_index] = 0
                    self.episodes_done += 1
                rows.append(reply["obs"][i])
                rewards.append(reward)
                dones.append(done)
                infos.append(info)
            offset += worker.boards
        return (np.asarray(rows, dtype=np.float32), np.asarray(rewards, dtype=np.float32),
                np.asarray(dones, dtype=bool), infos)

    def close(self) -> None:
        for worker in self.workers:
            worker.close()
        self.workers = []

    def _seed_for(self, worker_index: int) -> int:
        return self.base_seed * 1_000_000 + self._step_counter * 100 + worker_index

    # The rest of the VecEnv interface: nothing to get or set on the Godot side.
    def get_attr(self, attr_name: str, indices=None):
        return [getattr(self, attr_name, None)] * self.num_envs

    def set_attr(self, attr_name: str, value, indices=None) -> None:
        pass

    def env_method(self, method_name: str, *method_args, indices=None, **method_kwargs):
        return [None] * self.num_envs

    def env_is_wrapped(self, wrapper_class, indices=None):
        return [False] * self.num_envs

    def seed(self, seed=None):
        if seed is not None:
            self.base_seed = int(seed)
        return [self.base_seed] * self.num_envs


if __name__ == "__main__":
    # A smoke test: two workers, a reset and ten random steps.
    workers = GodotWorkers(stage=sys.argv[1] if len(sys.argv) > 1 else "S1", workers=2, boards=2,
                           log_dir=REPO_ROOT / ".sim_output/train/smoke")
    obs = workers.reset()
    print("obs", obs.shape)
    for k in range(10):
        workers.step_async(np.random.uniform(-1, 1, size=(workers.num_envs, 3)))
        obs, rew, done, infos = workers.step_wait()
        print(k, rew.round(3), done)
    workers.close()
