# The physics in C++: the wave test (13 November 2026)

Branch `tech/native-sea-test` (from `tech/frame-budget` 2e7b7bf). Max asked for it after the frame budget ([fleet_frame.md](../racing/fleet_frame.md), section "13 November 2026"). In a race the processor is the limit, and most of each board's physics is the water. His aim is a 0.2 release with more AI boards at full speed, through the physics in native code (C++), so he asked for the tools and one test first.

## The result

Lake Silvaplana's wave query (`LakeWaveField.sample_at`, PHYSICS_SPEC.md 9.17) was written again in C++ (`NativeLakeWaves`, `native/src/`). Both versions then got the questions a hull asks: 48 points under a hull sailing at 8 m/s from the lake's start spot, 180 substeps a second for 10 s, each point warm-started from its own last answer as `WindsurferSim` does. Each run was done twice: in the lake's own view and in the hull's view (the footprint).

| The game's release engine (Ryzen 7 5800X3D) | the lake's own view | the hull's view |
|---|---|---|
| Numbers that differ from GDScript (rest point, height, normal, velocity) | **0 of 1,123,200** | **0 of 1,123,200** |
| A query in GDScript | 4.11 µs | 4.36 µs |
| In C++, asked point by point from GDScript (the hull's code still GDScript) | 0.55 µs, **7.4 times faster** | 0.57 µs, **7.6 times** |
| In C++, all 48 points of a substep in one call (the hull in C++ too) | 0.37 µs, **11 times** | 0.37 µs, **12 times** |

In the editor engine, where GDScript is slower: 8.3 and 9.7 times point by point, 15 times a substep at once, and also 0 numbers different.

**The same to the last bit.** That is the condition for the physics: LAN play compares boards, and the tests check runs bit for bit. It holds because:

- **The same compiler as Godot's engine.** WinLibs MinGW-w64 GCC 15.2.0, msvcrt, r7, the one named inside `wsim.exe`. So sin and cos are the engine's own.
- **The same rounding.** Godot's `Vector2` and `Vector3` hold 32-bit floats and GDScript's `float` is 64 bits. The C++ keeps a sum in a 32-bit vector wherever the GDScript does, and does everything else in 64 bits, in the same order.
- **No shortcuts.** The compiler may not fuse a multiplication and an addition into one rounding (`-ffp-contract=off`), and it must call sin and cos one by one, as GDScript does, not as one combined sincos (`-fno-builtin-sin`, `-fno-builtin-cos`, `-fno-builtin-sincos`).

## What it means for the fleet

The waves are about 22 to 30 % of a board's physics on the lake (`tools/sea_bench.sh --lake=2`: 2.50 ms a tick with the waves, 1.75 ms on flat water). With them 7.5 times faster, a board's physics gets about a fifth cheaper. That is maybe 20 AI boards at 60 fps instead of 17 (an estimate, not measured in a race).

The big step is the hull's and the buoyancy's own arithmetic, another 40 % or so (the hull 48 % and the buoyancy 24 % of the physics, both including their wave questions). The plan, with estimates from 13 November:

| Step | What | GDScript lines | Share of a board's physics | Time (estimate) |
|---|---|---|---|---|
| 0 | The tools and this test | 360 | the answer: identical, 7.5 to 12 times faster | done: about 55 minutes of work (estimate 1 hour) |
| 1 | The waves used in the game (the hull's and the buoyancy's questions, the fin's) | about 800 | 22 to 30 % | half a day |
| 2 | The hull and the buoyancy, with the body's arithmetic they use | about 1,800 | about 40 % more | 1 to 2 days |
| 3 | The sail and the fin | about 700 | about 15 % more | about 1 day |
| 4 | The rest of `WindsurferSim` (the sailor, the balance, the falls) | about 2,300 | small | 2 to 3 days, probably not worth it |

Steps 1 to 3 together could give perhaps 2.5 to 3 times as many boards (an estimate). Each step needs:

- the race's state hash the same as GDScript's to the last bit (`--race_report`, [fleet_frame.md](../racing/fleet_frame.md));
- `tools/test.sh validation`;
- Michiel's review, because it is his physics.

## The costs (Max asked, 13 November)

- **Harder to change.** Michiel's tweaks to those parts would be in C++, which is harder to read. A C++ mistake can crash the game instead of showing an error.
- **A build step.** Each PC that changes the C++ needs the compiler and godot-cpp (below). A PC that only plays needs the built library (`windsurf_native.windows.template_release.x86_64.dll`) next to the game. One library per operating system, rebuilt when Godot is upgraded.
- **The GDScript stays for now.** The tests compare against it, so for a while the same physics exists twice.

## The tools (on Max's PC; nothing needs administrator rights)

- **The compiler:** WinLibs MinGW-w64 GCC 15.2.0 msvcrt r7, `winlibs-x86_64-posix-seh-gcc-15.2.0-mingw-w64msvcrt-14.0.0-r7.zip` from github.com/brechtsanders/winlibs_mingw. Its SHA-256 `9cd587d91ee7910dd8f9087e4bf9ac6b59a7ee594e1360601ba8a05355b9cefa`, the same as GitHub lists. Unpacked into `%LOCALAPPDATA%/Programs/winlibs-15.2.0-msvcrt-r7` (927 MB).
- **godot-cpp** at its `godot-4.5-stable` tag in `%LOCALAPPDATA%/Programs/godot-cpp-4.5`. A library built for Godot 4.5 loads in 4.7; godot-cpp has no 4.7 tag yet. The first build took about 10 minutes; a change to our C++ rebuilds in 11 s.
- **SCons 4.11.1**, through pip for the user.
- **`tools/native.sh`** builds the library (`native/SConstruct`, `native/src/`). It writes `Game/native/windsurf_native.gdextension` and runs the test in the editor engine. The library and that file are built files, not in git (`/Game/native/` in `.gitignore`).

## Three snags on the way

1. **WMI hangs on this PC.** Python 3.12 asks Windows Management Instrumentation for the system's version, so pip and SCons hung at start. `tools/python_no_wmi.py` runs them without asking; Python then reads the version as older Pythons did. The same hang stops `Get-CimInstance` and `tasklist`.
2. **The release engine runs no outside scripts.** Godot 4.7's export templates are built without path overrides: `--path` is refused and `-s` is ignored without a word. In the release engine the test runs through the game's own `DevCapture`: `wsim_console.exe --headless -- --native_sea_bench=10`, after `tools/release.sh build`, with the library copied next to the exe. A pack-only export does not copy the library; a full export would.
3. **C++'s "most vexing parse".** `Vector2 rest(real_t(x), real_t(z));` declared a function; it is written with `=` now.

## The tests in parallel (on the way)

`tools/test.sh` runs the 125 unit test files in one Godot, which keeps one of the 16 threads busy: 7 minutes. `tools/test_parallel.sh [unit|validation|all] [--jobs=8]` deals the files over 8 Godot processes, balanced on each file's own time from the last run (GUT's JUnit report, `.logs/tests/durations.json`): **1.7 minutes**, all 1,113 passing.

The floor is the slowest single file, `test_race_env.gd`, at about 86 s. Each process gets a GUT settings file without folders: the project's `.gutconfig.json` lists the unit and the validation folders, which GUT would otherwise run on top of the list.

## The files

- `native/SConstruct`, `native/src/native_lake_waves.h` and `.cpp`, `native/src/register_types.cpp`: the library.
- `tools/native.sh`: the build and the test.
- `tools/python_no_wmi.py`: pip and SCons without WMI.
- `Game/dev/native_sea_bench.gd` (`NativeSeaBench`) and `Game/dev/native_sea_bench_main.gd`: the test. `Game/dev/dev_capture.gd` has the `--native_sea_bench=<seconds>` option.
- `tools/test_parallel.sh` and `tools/test_parallel.py`: the parallel tests.
