class_name SimConfig
extends Resource
## Settings of the simulation itself, not of the physics: how finely time is cut up,
## and gravity. Change values in the .tres file.

## (3 since 20 October 2026, Michiel's decision after the Session 51 measurements: the reach
## check the same as 4 within 0.1 %, a quarter of the cost; 2 makes the 24 kt broad reach fall.)
## The physics tick (1/60 s in this project) is split into this many substeps, so the
## integrator runs at 240 Hz by default. Buoyancy is stiff (a bobbing period of about 0.6 s)
## and semi-implicit Euler wants small steps.
@export var substeps: int = 3
## Gravity.
@export var gravity_ms2: float = 9.81
