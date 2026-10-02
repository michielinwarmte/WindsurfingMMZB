class_name WaterConfig
extends Resource
## The water: density, viscosity, level, and the heave damping of the hull
## (PHYSICS_SPEC.md sections 6 and 9). Change values in the .tres file.

## Density of sea water. Fresh water would be about 1000.
@export var density_kg_m3: float = 1025.0
## Kinematic viscosity of water at about 15 degrees, for the Reynolds number of the friction.
@export var kinematic_viscosity_m2_s: float = 1.19e-6
## World height of the still water surface.
@export var base_height_m: float = 0.0

@export_group("Heave damping")
## Linear damping of a hull sample point moving through the surface, per unit of wet share.
## Stands in for the energy radiated as waves; a damping ratio of about 0.3 (section 6.5).
@export var damping_linear_ns_m: float = 800.0
## Quadratic damping: the drag of a flat plate pushed face-on through water (section 6.5).
@export var damping_quadratic_ns2_m2: float = 800.0
