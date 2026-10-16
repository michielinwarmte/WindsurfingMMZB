class_name SoundMixConfig
extends Resource
## The tuning numbers of the sound mix (SoundMix, sound_mix.gd): how loud each sound is,
## how its pitch and tone follow the sailing, and what counts as a splash. Change values in
## res://config/sound_mix_default.tres (or in the editor's inspector) and listen.
##
## Levels are in decibels (dB) below full scale: 0 dB is the loudest a voice may be, -6 dB
## is half the amplitude, -20 dB a tenth, -80 dB silence. The player's volume sliders come
## on top of this (on the Wind, Water and Sail buses).

@export_group("Wind in the ears")
## The wind voice reaches wind_max_db at this apparent wind speed (knots) and stays there.
@export var wind_full_kt: float = 30.0
@export var wind_max_db: float = -2.0
## How much louder the wind gets for each doubling of the apparent wind. Measured wind noise
## at the ears of cyclists rises about 13.6 dB per doubling of the speed (Seidman et al.
## 2017: 85 dB at 10 mph to 120 dB at 60 mph); a little less here so light air stays audible.
@export var wind_db_per_doubling: float = 12.0
## The low-pass filter on the wind: a dull murmur in light air, a bright roar at speed. The
## cutoff moves between these two (log scale) as the apparent wind goes from low_kt to high_kt.
@export var wind_cutoff_low_hz: float = 350.0
@export var wind_cutoff_high_hz: float = 4500.0
@export var wind_cutoff_low_kt: float = 5.0
@export var wind_cutoff_high_kt: float = 30.0
## Playback speed of the wind noise between the same two wind speeds (1 = as generated).
@export var wind_pitch_low: float = 0.85
@export var wind_pitch_high: float = 1.2
## The whistle: a narrow band of noise that comes in at speed (the wind past the ears, the
## leech and the lines). It starts at whistle_start_kt and is at whistle_max_db at wind_full_kt.
@export var whistle_start_kt: float = 16.0
@export var whistle_max_db: float = -16.0
## The whistle's band moves up with the apparent wind.
@export var whistle_low_hz: float = 1100.0
@export var whistle_high_hz: float = 2400.0

@export_group("Water: lapping and rumble (displacement)")
## The simulation's planing ratio (the share of the weight carried by planing lift) flickers
## quickly on the swell: it is smoothed over this time before the water sounds follow it.
@export var planing_smoothing_s: float = 0.7
## Its average is about 0.6 at full planing speed (the tail still floats a little), so this
## smoothed ratio counts as fully planing for the sound.
@export var planing_full_ratio: float = 0.6
## Lapping of the water on the hull with the board at rest, and at lapping_full_speed_ms.
@export var lapping_rest_db: float = -22.0
@export var lapping_max_db: float = -8.0
@export var lapping_full_speed_ms: float = 4.0
## The share of the lapping left when fully planing (the tail still touches the water).
@export var lapping_planing_residual: float = 0.15
## The lapping's low-pass cutoff at rest and at lapping_full_speed_ms.
@export var lapping_cutoff_rest_hz: float = 500.0
@export var lapping_cutoff_fast_hz: float = 1100.0
@export var lapping_pitch_rest: float = 0.9
@export var lapping_pitch_fast: float = 1.15
## The low rumble of the hull pushing water aside: none at rest, rumble_max_db at
## rumble_full_speed_ms in displacement, gone when planing.
@export var rumble_max_db: float = -10.0
@export var rumble_full_speed_ms: float = 3.5
## The nose digging in (bow immersion, m) adds rumble: this much bow depth doubles it.
@export var rumble_bow_depth_m: float = 0.08

@export_group("Water: planing hiss")
## The hiss of spray off the planing hull at hiss_ref_speed_ms, and how much louder it gets
## for each doubling of the speed (the drag that makes the spray grows about with the
## square of the speed), up to hiss_max_db.
@export var hiss_ref_speed_ms: float = 6.0
@export var hiss_ref_db: float = -14.0
@export var hiss_db_per_doubling: float = 8.0
@export var hiss_max_db: float = -4.0
## The hiss's band-pass centre, from hiss_low_hz at hiss_low_speed_ms to hiss_high_hz at
## hiss_high_speed_ms (log scale): a duller swish when slow, a fine fizz when fast.
@export var hiss_low_hz: float = 1800.0
@export var hiss_high_hz: float = 5000.0
@export var hiss_low_speed_ms: float = 3.0
@export var hiss_high_speed_ms: float = 14.0
@export var hiss_pitch_low: float = 0.9
@export var hiss_pitch_high: float = 1.3

@export_group("Sail: flutter and cracks")
## While the sail luffs (the simulation's is_luffing: an angle of attack inside the sail's
## luff zone, 5 degrees in sail_default.tres) it flaps fully below the first angle and
## fades out toward the second. A powered sail never flaps.
@export var flutter_full_below_alpha_deg: float = 1.0
@export var flutter_none_above_alpha_deg: float = 5.0
## Below this apparent wind the cloth hangs and does not flap audibly.
@export var flutter_min_aws_kt: float = 3.0
## The flutter at flutter_full_kt of apparent wind; 12 dB quieter per halving of the wind.
@export var flutter_full_kt: float = 20.0
@export var flutter_max_db: float = -4.0
@export var flutter_db_per_doubling: float = 12.0
## A flapping sheet or flag flaps at a frequency proportional to the wind speed (its
## Strouhal number f L / U stays nearly constant, Virot et al. 2013), so the flutter loop
## plays faster in more wind: pitch 1 at flutter_ref_kt.
@export var flutter_ref_kt: float = 12.0
@export var flutter_pitch_min: float = 0.5
@export var flutter_pitch_max: float = 2.0
## During a tack or a gybe the sail flaps at least this much (0 to 1).
@export var manoeuvre_flutter: float = 0.5
## The low-pass on the flutter: softer in light air, a hard rattle in a blow.
@export var flutter_cutoff_low_hz: float = 900.0
@export var flutter_cutoff_high_hz: float = 3500.0
## A crack when the sail fills again after luffing (and a softer one when it collapses),
## at crack_max_db in crack_full_kt of apparent wind or more.
@export var crack_max_db: float = -3.0
@export var crack_full_kt: float = 20.0
@export var crack_min_aws_kt: float = 6.0
## The collapse of the luff (powered to luffing) is this much softer than the fill.
@export var crack_collapse_db: float = -8.0
## The sail has to have been luffing (or powered) this long for the change to crack.
@export var crack_min_state_s: float = 0.25
## The swoosh of the rig swinging through the wind (the sail changes sides), at
## swoosh_max_db in swoosh_full_kt of apparent wind.
@export var swoosh_max_db: float = -5.0
@export var swoosh_full_kt: float = 15.0

@export_group("Splashes")
## A slam: the hull was falling onto the water faster than slam_speed_ms (relative to the
## surface) and the water stopped it (its vertical speed rose by slam_stop_ms in one step).
@export var slam_speed_ms: float = 1.0
@export var slam_stop_ms: float = 0.5
## A slam at slam_speed_ms is splash_min_db; at splash_full_speed_ms or faster splash_max_db.
@export var splash_full_speed_ms: float = 3.0
@export var splash_min_db: float = -22.0
@export var splash_max_db: float = -2.0
## The nose digging into a wave: the bow goes down into the water faster than this (m/s).
@export var bow_dig_rate_ms: float = 1.5
@export var bow_dig_db: float = -10.0
## The sailor falling in: a catapult is louder than a fall to the side.
@export var fall_catapult_db: float = 0.0
@export var fall_db: float = -3.0
## The water start: the sailor is pulled out of the water.
@export var waterstart_db: float = -14.0
## No second splash (except a fall) within this time of the last one.
@export var splash_cooldown_s: float = 0.25

@export_group("Camera and menu")
## The sounds of the board (water and sail, not the wind in the ears) get quieter when
## the camera is further than camera_near_m from the board: camera_db_per_doubling for
## each doubling of the distance, down to camera_min_db at most.
@export var camera_near_m: float = 8.0
@export var camera_db_per_doubling: float = -4.5
@export var camera_min_db: float = -12.0
## Behind the start menu everything is this much quieter.
@export var menu_db: float = -8.0

@export_group("Smoothing")
## How quickly the levels follow (time constants, seconds): a few tens of milliseconds
## means no clicks, a few hundred means no jitter.
@export var wind_smoothing_s: float = 0.25
@export var water_smoothing_s: float = 0.15
@export var flutter_attack_s: float = 0.04
@export var flutter_release_s: float = 0.15
@export var tone_smoothing_s: float = 0.2
@export var menu_fade_s: float = 1.0
