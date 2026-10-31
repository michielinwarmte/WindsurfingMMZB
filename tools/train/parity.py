"""Makes the parity fixture (RACING_PLAN.md, RD4): a small brain exported from a torch policy the
way train.py exports them, 20 random inputs, and the outputs torch gives for them. The unit test
Game/tests/unit/test_neural_net.gd runs the same brain in GDScript on the same inputs and checks
the outputs agree to 1e-5, and that the outputs' names came through (the trainer's four since
Session 64, the push among them). It also checks the way back, a brain into a policy by the
outputs' names: a brain without the push output leaves the policy's push row as it was. Run it
again only when the export changes:

    python tools/train/parity.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export import brain_from_policy, forward_numpy, policy_from_brain  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE = REPO_ROOT / "Game/tests/unit/fixtures/brain_parity.json"
INPUTS = 70
HIDDEN = 16
OUTPUTS = 4
SAMPLES = 20
# The trainer's outputs in the wind-angle mode (LearnedSkipper.TWA_ACTION_NAMES).
ACTION_NAMES = ["twa", "sheet", "hold", "push"]


class TinyPolicy:
    """The shape of an SB3 MlpPolicy's action side, enough for the export."""

    def __init__(self) -> None:
        torch.manual_seed(3)
        self.mlp_extractor = type("Extractor", (), {})()
        self.mlp_extractor.policy_net = nn.Sequential(nn.Linear(INPUTS, HIDDEN), nn.Tanh(), nn.Linear(HIDDEN, HIDDEN), nn.Tanh())
        self.action_net = nn.Linear(HIDDEN, OUTPUTS)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.action_net(self.mlp_extractor.policy_net(x))


def main() -> None:
    policy = TinyPolicy()
    obs_names = [f"in{k}" for k in range(INPUTS)]
    brain = brain_from_policy(policy, obs_names, ACTION_NAMES, {"trainer": "parity fixture", "actions": "twa"})
    rng = np.random.default_rng(5)
    inputs = rng.uniform(-1.5, 1.5, size=(SAMPLES, INPUTS)).astype(np.float32)
    with torch.no_grad():
        outputs = policy.forward(torch.tensor(inputs)).numpy()
    numpy_outputs = forward_numpy(brain, inputs)
    assert np.max(np.abs(outputs - numpy_outputs)) < 1e-5, "the numpy forward pass disagrees with torch"
    check_the_way_back(brain, obs_names)
    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    with open(FIXTURE, "w", encoding="utf-8", newline="\n") as file:
        json.dump({"brain": brain, "inputs": inputs.tolist(), "outputs": outputs.tolist()}, file)
    print(f"wrote {FIXTURE}: {SAMPLES} inputs of {INPUTS}, outputs within {np.max(np.abs(outputs - numpy_outputs)):.2e} of numpy")


def zeroed(policy: TinyPolicy) -> TinyPolicy:
    """The policy with every weight and bias at zero, so a copy into it shows."""
    with torch.no_grad():
        for module in (policy.mlp_extractor.policy_net, policy.action_net):
            for parameter in module.parameters():
                parameter.zero_()
    return policy


def check_the_way_back(brain: dict, obs_names: list[str]) -> None:
    """A brain back into a fresh policy gives the same outputs; a brain of three outputs (before the
    push) leaves the fresh policy's push row alone and fills the other three."""
    fresh = zeroed(TinyPolicy())
    new_inputs, new_outputs = policy_from_brain(fresh, brain, obs_names, ACTION_NAMES)
    assert not new_inputs and not new_outputs, (new_inputs, new_outputs)
    back = brain_from_policy(fresh, obs_names, ACTION_NAMES, {})
    assert back["action_names"] == ACTION_NAMES
    for mine, theirs in zip(back["layers"], brain["layers"]):
        assert np.allclose(mine["w"], theirs["w"]) and np.allclose(mine["b"], theirs["b"])
    old = json.loads(json.dumps(brain))
    old["action_names"] = ACTION_NAMES[:3]
    old["layers"][-1]["w"] = old["layers"][-1]["w"][:3]
    old["layers"][-1]["b"] = old["layers"][-1]["b"][:3]
    fresh = zeroed(TinyPolicy())
    with torch.no_grad():
        fresh.action_net.bias[3] = 0.567
    push_row = fresh.action_net.weight[3].detach().clone()
    _, new_outputs = policy_from_brain(fresh, old, obs_names, ACTION_NAMES)
    assert new_outputs == ["push"], new_outputs
    assert torch.equal(fresh.action_net.weight[3], push_row) and abs(float(fresh.action_net.bias[3].detach()) - 0.567) < 1e-6
    assert np.allclose(fresh.action_net.bias.detach().numpy()[:3], brain["layers"][-1]["b"][:3])


if __name__ == "__main__":
    main()
