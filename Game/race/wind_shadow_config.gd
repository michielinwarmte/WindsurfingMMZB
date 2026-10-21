class_name WindShadowConfig
extends Resource
## The shape and strength of the wind shadow a sail casts (AI_FLEET_PLAN.md, D5: "a sail leaves a
## cone of slower and disturbed wind behind it"). The numbers are Michiel's to set (decision 1 of
## the plan); the defaults are from the sailing tactics books: about five to seven mast heights
## of disturbed air downwind, strongest within two, some 30 % less wind close behind the sail.
## The values live in Game/config/wind_shadow_default.tres.

## How far downwind of the sail the shadow reaches, metres (a windsurfer's mast is about 4.9 m:
## six mast heights).
@export var length_m: float = 30.0
## The share of the wind missing right behind the sail (0.3: 30 % less).
@export var deficit: float = 0.3
## Half the shadow's width right behind the sail, metres (about the sail's chord and the eddies
## off it).
@export var half_width_m: float = 2.5
## The shadow widens downwind at this half-angle, degrees.
@export var spread_deg: float = 8.0
## The deficit is at its full strength this far downwind of the sail, metres, then fades to
## nothing at length_m.
@export var full_until_m: float = 5.0
## Several sails' shadows add up to at most this share of the wind missing.
@export var most_deficit: float = 0.5
