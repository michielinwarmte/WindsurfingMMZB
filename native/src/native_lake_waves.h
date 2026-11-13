// NativeLakeWaves: Lake Silvaplana's wave query (LakeWaveField.sample_at, PHYSICS_SPEC.md 9.17)
// in C++, for the test of 13 November 2026: is the physics faster in native code, and does it give
// the same answers to the last bit?
//
// It copies a LakeWaveField's numbers once (setup_from) and then answers sample_at as the GDScript
// does: the same sums in the same order, rounded in the same places. GDScript's float is a 64-bit
// double here too; GDScript's Vector2 and Vector3 hold 32-bit floats, so where the GDScript keeps a
// sum in a vector this keeps it in a godot::Vector2 or Vector3 (rounded to 32 bits after every
// addition), and everywhere else in doubles.
//
// The answers go into the object's own records (SAMPLE_SIZE numbers per point, the layout of
// WaterSurface.SAMPLE_*), because a packed array handed over from GDScript is a copy here.

#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

#include <vector>

namespace godot {

class NativeLakeWaves : public RefCounted {
	GDCLASS(NativeLakeWaves, RefCounted)

public:
	// WaterSurface's record layout and WaveField's solver (the same numbers as the GDScript).
	static constexpr int SAMPLE_X = 0;
	static constexpr int SAMPLE_Z = 1;
	static constexpr int SAMPLE_TIME_S = 2;
	static constexpr int SAMPLE_IS_SET = 3;
	static constexpr int SAMPLE_REST_X = 4;
	static constexpr int SAMPLE_REST_Z = 5;
	static constexpr int SAMPLE_HEIGHT_M = 6;
	static constexpr int SAMPLE_NORMAL = 7;
	static constexpr int SAMPLE_VELOCITY_MS = 10;
	static constexpr int SAMPLE_SIZE = 13;
	static constexpr double SOLVE_TOLERANCE_M = 0.001;
	static constexpr int SOLVE_MAX_ITERATIONS = 8;

	// Copies the trains, the grid and the footprint of a LakeWaveField (read through its properties).
	void setup_from(Object *field, double max_steepness);
	// Room for this many points' records, all forgotten (WaterSurface.new_samples).
	void new_samples(int points);
	// LakeWaveField.sample_at into record `index`.
	void sample_at(double x, double z, double time_s, int index);
	// sample_at for every point of a substep in one call: xz holds x0, z0, x1, z1, ... for records
	// 0, 1, ... (what a hull written in C++ would do: no call from GDScript per point).
	void sample_points(const PackedFloat64Array &xz, double time_s);
	// All the records (a copy, for GDScript to read).
	PackedFloat64Array samples() const;

protected:
	static void _bind_methods();

private:
	int count = 0;
	double base_height_m = 0.0;
	double max_steepness = 0.0;
	std::vector<double> k, omega, c, dir_x, dir_z, phase, footprint_factor;
	// The grid, as LakeWaveField copies it.
	int64_t columns = 0;
	int64_t rows = 0;
	double x0_m = 0.0;
	double z0_m = 0.0;
	double per_cell = 1.0;
	int64_t stride = 1;
	std::vector<float> grid;
	// The trains' values at the last point asked, and their phases for the last time asked.
	std::vector<double> amplitude, steepness, theta;
	double theta_time = 0.0;
	bool theta_set = false;
	std::vector<double> records;

	void amplitudes_for(double x, double z);
	void thetas_at(double t);
	void answers_at_rest(double x, double z, double t, Vector2 rest, int index);
	void write_sample(int index, double x, double z, double time_s, Vector2 rest, double height_m, Vector3 normal, Vector3 velocity_ms);
};

} // namespace godot
