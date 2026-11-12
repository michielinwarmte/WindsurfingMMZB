class_name WindShadowConfig
extends Resource
## The shape and strength of the wind shadow a sail casts (AI_FLEET_PLAN.md, D5: "a sail leaves a
## cone of slower and disturbed wind behind it"). The numbers are Michiel's to set (decision 1 of
## the plan); the defaults are from the sailing tactics books: about five to seven mast heights
## of disturbed air downwind, strongest within two, some 30 % less wind close behind the sail.
## The values live in Game/config/wind_shadow_default.tres.

## How far downwind of the sail the shadow reaches, metres (a windsurfer's mast is about 4.9 m: four
## mast heights; Max, 13 November 2026: "this needs to be less, make it 20 m"; 30 m before; the research's
## 20 to 25 m for a planing board, Documentation/reports/racing/dirty_wind_13nov/RESEARCH.md).
@export var length_m: float = 20.0
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
## The shadow as it is on the water (Max, 12 November 2026: "implement it like real life"; WindShadowTrail): the air a
## sail disturbs drifts off with the wind, so seen from the moving board its shadow lies along its apparent wind and
## swings back as it speeds up. False: the cone straight down the true wind from where the sail is now (until 12
## November 2026).
@export var follows_apparent_wind: bool = true
## A sail that is up leaves a puff of disturbed air this often, seconds (the trail's points).
@export var puff_every_s: float = 0.25
## The wake bends this much further toward the stern of the board that casts it than its apparent wind, degrees
## (Richards et al. 2012, wind tunnel: about 5 upwind, 9 on a reach).
@export var stern_bend_deg: float = 7.0
