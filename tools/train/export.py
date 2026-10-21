"""A brain file from a Stable-Baselines3 policy, and a policy from a brain file (RACING_PLAN.md,
RD4: a brain is a built artefact; Game/race/brains/README.md says what is in the file).

The policy's action network (the "pi" side of the MlpPolicy: hidden layers with tanh, then a linear
layer giving the mean of each action) is exactly a NeuralNet: one layer per Linear, "tanh" after the
hidden ones and "linear" after the last. The game clips each output to -1 to 1 as it uses it, as the
trainer clips the sampled actions. The value network is not exported: the game never needs it.
"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path

import numpy as np
import torch
from torch import nn

FORMAT = "windsurfing-brain-1"


def policy_layers(policy) -> list[nn.Linear]:
    """The Linear layers of the action side of an SB3 MlpPolicy, in order."""
    layers = [m for m in policy.mlp_extractor.policy_net if isinstance(m, nn.Linear)]
    layers.append(policy.action_net)
    return layers


def brain_from_policy(policy, obs_names: list[str], action_names: list[str], meta: dict) -> dict:
    """The brain file's contents for a policy."""
    linears = policy_layers(policy)
    layers = []
    for n, linear in enumerate(linears):
        weights = linear.weight.detach().cpu().numpy().astype(np.float64)
        biases = linear.bias.detach().cpu().numpy().astype(np.float64)
        layers.append({"w": [[float(v) for v in row] for row in weights], "b": [float(v) for v in biases],
                       "act": "linear" if n == len(linears) - 1 else "tanh"})
    return {
        "format": FORMAT,
        "meta": meta,
        "action_names": list(action_names),
        "obs_names": list(obs_names),
        "obs_scale": [1.0] * len(obs_names),
        "layers": layers,
    }


def save_brain(brain: dict, path: Path) -> None:
    """Writes a brain file the way NeuralNet.save() does: the note and the names first, then one
    line per neuron, so that a person can open it and see what it is."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        file.write("{\n")
        for key in ["format", "meta", "action_names", "obs_names", "obs_scale"]:
            file.write(f"\t{json.dumps(key)}: {json.dumps(brain[key])},\n")
        file.write('\t"layers": [\n')
        for n, layer in enumerate(brain["layers"]):
            file.write(f'\t\t{{"act": {json.dumps(layer["act"])}, "b": {json.dumps(layer["b"])}, "w": [\n')
            rows = layer["w"]
            for o, row in enumerate(rows):
                file.write("\t\t\t" + json.dumps(row) + ("," if o < len(rows) - 1 else "") + "\n")
            file.write("\t\t]}" + ("," if n < len(brain["layers"]) - 1 else "") + "\n")
        file.write("\t]\n}\n")


def load_brain(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as file:
        return json.load(file)


def policy_from_brain(policy, brain: dict, obs_names: list[str]) -> None:
    """Copies a brain file's weights into a policy's action network (the value network and the
    noise are left as they are). The brain must have been made for the same inputs, in the same
    order, and the same layer sizes; otherwise a ValueError says what differs."""
    if list(brain.get("obs_names", [])) != list(obs_names):
        theirs = brain.get("obs_names", [])
        raise ValueError(f"the brain was made for {len(theirs)} inputs and the observation now has {len(obs_names)}: "
                         "a brain cannot be resumed across a change of the observation (train from scratch, "
                         "or export the old brain's stage again).")
    linears = policy_layers(policy)
    layers = brain["layers"]
    if len(layers) != len(linears):
        raise ValueError(f"the brain has {len(layers)} layers and the policy {len(linears)}")
    with torch.no_grad():
        for linear, layer in zip(linears, layers):
            weights = torch.tensor(np.asarray(layer["w"], dtype=np.float32))
            biases = torch.tensor(np.asarray(layer["b"], dtype=np.float32))
            if tuple(weights.shape) != tuple(linear.weight.shape):
                raise ValueError(f"a layer of the brain is {tuple(weights.shape)} and the policy's {tuple(linear.weight.shape)}")
            linear.weight.copy_(weights)
            linear.bias.copy_(biases)


def forward_numpy(brain: dict, inputs: np.ndarray) -> np.ndarray:
    """The brain's outputs for inputs, in plain numpy (the parity fixture's reference)."""
    values = np.asarray(inputs, dtype=np.float32) * np.asarray(brain["obs_scale"], dtype=np.float32)
    for layer in brain["layers"]:
        values = values @ np.asarray(layer["w"], dtype=np.float32).T + np.asarray(layer["b"], dtype=np.float32)
        if layer["act"] == "tanh":
            values = np.tanh(values)
    return values


def meta_for(run: str, stage: str, generation: int, timesteps: int, episodes: int, hours: float, stats: dict,
             physics_commit: str, extra: dict | None = None) -> dict:
    meta = {
        "run": run,
        "stage": stage,
        "generation": generation,
        "timesteps": int(timesteps),
        "episodes": int(episodes),
        "hours": round(hours, 3),
        "date": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "physics_commit": physics_commit,
        "trainer": "PPO (Stable-Baselines3) over the bridge (tools/train/train.py)",
        "actions": "twa",
        "decision_ticks": 30,
        "course": "random (RandomCourses)",
    }
    meta.update({k: (round(v, 4) if isinstance(v, float) else v) for k, v in stats.items()})
    if extra:
        meta.update(extra)
    return meta
