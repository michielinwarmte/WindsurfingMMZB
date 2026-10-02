class_name SimConfig
extends Resource
## Settings of the simulation itself, not of the physics: how finely time is cut up,
## and gravity. Change values in the .tres file.

## The physics tick (1/60 s in this project) is split into this many substeps, so the
## integrator runs at 240 Hz by default. Buoyancy is stiff (a bobbing period of about 0.6 s)
## and semi-implicit Euler wants small steps.
@export var substeps: int = 4
## Gravity.
@export var gravity_ms2: float = 9.81
