class_name WindShadowConfig
extends Resource
## The shape and strength of the wind shadow a sail casts (AI_FLEET_PLAN.md, D5: "a sail leaves a
## cone of slower and disturbed wind behind it"). The numbers are Michiel's to set (decision 1 of
## the plan). Until 13 November 2026 they came from the sailing tactics books (30 % less wind close
## behind); since then from a wind tunnel on the GPU with the game's own rig in it (PH15,
## Documentation/reports/ph15_wind_tunnel/wind_tunnel.md): a board behind loses about 5 % of its
## wind at 5 m, 4 % at 10 m and 3 % at 20 m. The values live in Game/config/wind_shadow_default.tres.

## How far downwind of the sail the shadow reaches, metres (a windsurfer's mast is about 4.9 m: four
## mast heights; Max, 13 November 2026: "this needs to be less, make it 20 m"; 30 m before; the research's
## 20 to 25 m for a planing board, Documentation/reports/racing/dirty_wind_13nov/RESEARCH.md).
@export var length_m: float = 20.0
## The share of the wind missing right behind the sail (0.075: 7.5 % less; the wind tunnel, PH15. A
## sail can only take out of the air the momentum of its own drag, about 90 N for the 8.0 at 18 kt,
## which over a wake the size of the sail is a few percent of the wind. 0.3 until 13 November 2026).
@export var deficit: float = 0.075
## Half the shadow's width right behind the sail, metres (about the sail's chord and the eddies
## off it; the wind tunnel's widths within 20 m match this and spread_deg, PH15).
@export var half_width_m: float = 2.5
## The shadow widens downwind at this half-angle, degrees.
@export var spread_deg: float = 8.0
## The deficit is at its full strength this far downwind of the sail, metres, then fades to
## nothing at length_m (1: the wind tunnel's shadow is strongest right behind the sail and fades
## from there, PH15; 5 until 13 November 2026).
@export var full_until_m: float = 1.0
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
## (the game's wind tunnel, PH15: 2.5 to 5 on the fast cases, -3 on the slow broad reaches; yachts in Richards et
## al. 2012's tunnel: about 5 upwind, 9 on a reach; 7 until 13 November 2026).
@export var stern_bend_deg: float = 3.0
