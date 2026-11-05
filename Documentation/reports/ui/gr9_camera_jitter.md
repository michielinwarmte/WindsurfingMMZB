# GR9: the camera's jitter on the rig

5 November 2026, late evening. Max: "the camera is jittery of the rig, and is moving weird; it causes a bit of a blurry thing."

## The cause

The game's cameras (`Game/camera/camera_rig.gd`) are moved in `_process`, once per rendered frame, to the board's interpolated place. But the project has physics interpolation on (`project.godot`, `common/physics_interpolation=true`), and the camera itself was left interpolated. Godot then drew the camera between its places at the last two physics ticks, while the board was drawn where it is now. Between ticks the two disagree a little, differently every frame, so the board and the rig shook in the picture. The two map cameras (`maps/fly_camera.gd`, `maps/top_camera.gd`) already switch interpolation off for this reason; the game's camera did not.

The fix is one line: `camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF` in `CameraRig._ready()`. A unit test keeps it (`tests/unit/test_camera_rig.gd`).

## The measurement

Open water, the default settings, the autopilot on a beam reach, the follow camera (close), 144 frames a second with vsync off, 12 s after a 3 s settle; physics at 60 ticks a second. Each frame, after every other node, the probe logs where the camera and the board are drawn (both interpolated) and turns that into the board's place in the camera's view. The jitter is the frame-to-frame change of that place's frame-to-frame change (the second difference), in degrees.

| | Board in the view, sideways (RMS / max) | Board in the view, up and down (RMS / max) | Camera's turn, yaw (RMS / max) |
|---|---|---|---|
| Before (the camera interpolated) | 0.0120° / 0.0355° | 0.0613° / 0.1493° | 0.0085° / 0.0312° |
| After (the fix in the game) | 0.0005° / 0.0045° | 0.0001° / 0.0005° | 0.0006° / 0.0046° |

On Max's window (1263 pixels high) a degree is about 17 pixels (the camera has Godot's default field of view, 75° across the height), so before the fix the board jumped about 1 pixel a frame on average and up to about 2.5. That fits "jittery" and "a bit blurry": the eye reads a picture that shakes by a pixel or two as blur. The slow movement (the board drifting 6° up and down in the view as the camera follows) is the same before and after; only the shake is gone.

At exactly 60 frames a second with vsync, frames and ticks line up and the shake is small; on a faster screen (100 to 144 Hz) or with vsync off it is at its worst. Max's screen rate is not known; worth asking.

To repeat it (the scripts are in `gr9_camera/`):

```
CAM_DIR="<this folder>/gr9_camera" "$GODOT" --headless --path Game -s "<this folder>/gr9_camera/cam_probe.gd" -- --settings=defaults --autopilot=1 --camera=1 --hud=0 --fps=144 --out=cam.csv [--interp_off]
python gr9_camera/cam_stats.py cam.csv
```

## Not changed, and still to check

- Not verified on Max's screen. A fix for something Max sees is only done when he has seen it: play the build, the follow camera, on waves and flat water, and look at the rig.
- The follow camera's look point (7 m ahead of the board) is not smoothed, so the board's heave and yaw on waves still turn the camera directly. That is slow movement, not the frame-to-frame shake, and it was not measurably shaky here; if Max still sees "moving weird" after this fix, that is the next thing to try (a framing choice for Max).
- Blur from the graphics settings: the game uses MSAA (Settings > Graphics), no TAA, so no temporal smearing comes from anti-aliasing.
