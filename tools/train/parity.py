"""Makes the parity fixture (RACING_PLAN.md, RD4): a small brain exported from a torch policy the
way train.py exports them, 20 random inputs, and the outputs torch gives for them. The unit test
Game/tests/unit/test_neural_net.gd runs the same brain in GDScript on the same inputs and checks
the outputs agree to 1e-5. Run it again only when the export changes:

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
from export import brain_from_policy, forward_numpy  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURE = REPO_ROOT / "Game/tests/unit/fixtures/brain_parity.json"
INPUTS = 70
HIDDEN = 16
OUTPUTS = 3
SAMPLES = 20


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
    brain = brain_from_policy(policy, obs_names, ["twa", "sheet", "hold"], {"trainer": "parity fixture", "actions": "twa"})
    rng = np.random.default_rng(5)
    inputs = rng.uniform(-1.5, 1.5, size=(SAMPLES, INPUTS)).astype(np.float32)
    with torch.no_grad():
        outputs = policy.forward(torch.tensor(inputs)).numpy()
    numpy_outputs = forward_numpy(brain, inputs)
    assert np.max(np.abs(outputs - numpy_outputs)) < 1e-5, "the numpy forward pass disagrees with torch"
    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    with open(FIXTURE, "w", encoding="utf-8", newline="\n") as file:
        json.dump({"brain": brain, "inputs": inputs.tolist(), "outputs": outputs.tolist()}, file)
    print(f"wrote {FIXTURE}: {SAMPLES} inputs of {INPUTS}, outputs within {np.max(np.abs(outputs - numpy_outputs)):.2e} of numpy")


if __name__ == "__main__":
    main()
