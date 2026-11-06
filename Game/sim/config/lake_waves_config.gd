class_name LakeWavesConfig
extends Resource
## A lake's own waves, grown by its wind over its fetch (PHYSICS_SPEC.md 9.17; PH44). The waves are
## a few wave trains of fixed lengths and directions, the same over the whole lake (so their crests
## run on without a jump), whose heights change from place to place: nothing at the upwind shore,
## growing downwind with the open water the wind has blown over (the fetch), less in a lee and in
## the shallows. LakeWaves builds them for a lake from its depth grid and its wind; LakeWaveField is
## the water the physics asks. Change values in the .tres.

## Which law turns the wind and the fetch into the waves' height and period (9.17, step 3).
## SPM: the Shore Protection Manual (1984), from JONSWAP, with the wind at 10 m as it is (what
## WindWaves does, 9.16). CEM: the Coastal Engineering Manual (2002, Resio, Bratos and Thompson
## 2003), from the friction velocity. They agree on the height within 7 % and differ by 25 % on the
## period (the research, wave_system_research.md 1.3).
enum GrowthLaw { SPM, CEM }

@export var growth_law: GrowthLaw = GrowthLaw.SPM

@export_group("Waves")
## The lake's wave trains, longest first: their lengths (m) and their directions as offsets from
## downwind (degrees, positive = clockwise seen from above). Each train stands for one octave of the
## spectrum: from its length / sqrt(2) to its length x sqrt(2). At most four (the shader's slots and
## the query's cost, 9.17). Trains of about 1 m and longer: the hull's buoyancy rows are about 0.4 m
## apart, so a shorter wave would alias in the physics (the research, 1.7).
@export var wavelengths_m: PackedFloat32Array = PackedFloat32Array([8.0, 4.0, 2.0, 1.0])
@export var offsets_deg: PackedFloat32Array = PackedFloat32Array([0.0, -7.0, 10.0, -14.0])
## How many of the trains (the longest) the physics floats on; the picture draws the rest as shading
## only (their slopes, not their shape), so the shape you see is the shape the board floats on. All
## four (9.18): the hull feels each train averaged over its wet bottom (LakeWaveField.set_footprint()),
## so it bridges the chop shorter than it, as a real planing board does. Last night's two (8 m and
## 4 m) were measured before the hull did that: all four then halved the beam reach's speed (10.7
## against 20.3 kt at the start in the map's 18 kt), the strips meeting every 1 m and 2 m crest as
## if the hull were as short as a strip (PH10).
@export_range(0, 4) var physics_trains: int = 4
## A shorter train for the picture only (the shader): the physics never sees it.
@export var look_wavelength_m: float = 0.5
@export var look_offset_deg: float = 18.0
## The spectrum's peak enhancement (JONSWAP, Hasselmann et al. 1973: 3.3 on average).
@export var peak_enhancement: float = 3.3
## Every train's height times this (1 = the growth law's). For a later measurement on the water:
## lake measurements found the laws too high in light wind (the research, 1.3).
@export var height_scale: float = 1.0

## The phases of the trains at the origin at time 0 come from Godot's random numbers with this seed
## (the research's "seeded phases"): the same sea on every PC and in every run with the same seed.
@export var phase_seed: int = 44
## The depth the trains travel in, m (omega^2 = g k tanh(k h), 9.18): 0 takes the median depth of
## the lake's nodes from its depth grid (Silvaplana: deep water for every train).
@export var reference_depth_m: float = 0.0

@export_group("Fetch")
## The map's cells: the fetch and the wave heights are worked out at the corners of squares this
## big over the lake, and read in between (bilinear). Small next to how fast the waves change
## along the lake, big next to a wave.
@export var cell_m: float = 16.0
## The fetch at a point: the open water upwind along rays this many degrees apart around the wind,
## averaged with a weight of the cosine of each ray's angle off the wind (the Shore Protection
## Manual's method, 1984: 9 rays 6 degrees apart).
@export var ray_count: int = 9
@export var ray_spacing_deg: float = 6.0

@export_group("Depth")
## In shallow water the waves break when they get too high for the depth: the significant height
## stays below this share of the depth (WindWaves, 9.16; Coastal Engineering Manual 2002).
@export var depth_limited_height_ratio: float = 0.6
