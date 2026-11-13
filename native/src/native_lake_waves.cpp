// NativeLakeWaves: see the header. Each function names the GDScript it copies; the comments mark
// where a value is rounded to 32 bits, as GDScript's Vector2 and Vector3 round it.

#include "native_lake_waves.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>

#include <cmath>

namespace godot {

namespace {

// Copies a GDScript PackedFloat64Array property into a std::vector.
std::vector<double> doubles_of(Object *field, const char *name) {
	PackedFloat64Array values = field->get(name);
	std::vector<double> result(values.size());
	for (int64_t i = 0; i < values.size(); i++) {
		result[i] = values[i];
	}
	return result;
}

// GDScript's lerpf (Math::lerp for doubles).
inline double lerp_double(double from, double to, double weight) {
	return from + (to - from) * weight;
}

} // namespace

void NativeLakeWaves::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup_from", "field", "max_steepness"), &NativeLakeWaves::setup_from);
	ClassDB::bind_method(D_METHOD("new_samples", "points"), &NativeLakeWaves::new_samples);
	ClassDB::bind_method(D_METHOD("sample_at", "x", "z", "time_s", "index"), &NativeLakeWaves::sample_at);
	ClassDB::bind_method(D_METHOD("sample_points", "xz", "time_s"), &NativeLakeWaves::sample_points);
	ClassDB::bind_method(D_METHOD("samples"), &NativeLakeWaves::samples);
}

void NativeLakeWaves::setup_from(Object *field, double p_max_steepness) {
	count = int(field->get("count"));
	base_height_m = field->get("base_height_m");
	max_steepness = p_max_steepness;
	k = doubles_of(field, "k");
	omega = doubles_of(field, "omega");
	c = doubles_of(field, "c");
	dir_x = doubles_of(field, "dir_x");
	dir_z = doubles_of(field, "dir_z");
	phase = doubles_of(field, "phase");
	footprint_factor = doubles_of(field, "footprint_factor");
	columns = int64_t(field->get("_columns"));
	rows = int64_t(field->get("_rows"));
	x0_m = field->get("_x0_m");
	z0_m = field->get("_z0_m");
	per_cell = field->get("_per_cell");
	stride = int64_t(field->get("_stride"));
	PackedFloat32Array grid_values = field->get("_grid");
	grid.resize(grid_values.size());
	for (int64_t i = 0; i < grid_values.size(); i++) {
		grid[i] = grid_values[i];
	}
	amplitude.assign(count, 0.0);
	steepness.assign(count, 0.0);
	theta.assign(count, 0.0);
	theta_set = false;
}

void NativeLakeWaves::new_samples(int points) {
	records.assign(size_t(points) * SAMPLE_SIZE, 0.0);
}

PackedFloat64Array NativeLakeWaves::samples() const {
	PackedFloat64Array result;
	result.resize(int64_t(records.size()));
	for (size_t i = 0; i < records.size(); i++) {
		result.set(int64_t(i), records[i]);
	}
	return result;
}

// LakeWaveField.amplitudes_for.
void NativeLakeWaves::amplitudes_for(double x, double z) {
	double fx = (x - x0_m) * per_cell;
	double fz = (z - z0_m) * per_cell;
	if (fx < 0.0 || fz < 0.0 || fx >= double(columns) - 1.0 || fz >= double(rows) - 1.0) {
		std::fill(amplitude.begin(), amplitude.end(), 0.0);
		std::fill(steepness.begin(), steepness.end(), 0.0);
		return;
	}
	int64_t column = int64_t(fx);
	int64_t row = int64_t(fz);
	double tx = fx - double(column);
	double tz = fz - double(row);
	int64_t north = (row * columns + column) * stride;
	int64_t south = north + columns * stride;
	for (int i = 0; i < count; i++) {
		double top = lerp_double(grid[north + i], grid[north + stride + i], tx);
		double bottom = lerp_double(grid[south + i], grid[south + stride + i], tx);
		double wave_a = lerp_double(top, bottom, tz) * footprint_factor[i];
		amplitude[i] = wave_a;
		double wanted = k[i] * wave_a;
		steepness[i] = wanted < max_steepness ? wanted : max_steepness; // GDScript minf: MIN(a, b)
	}
}

// LakeWaveField._thetas_at.
void NativeLakeWaves::thetas_at(double t) {
	if (theta_set && t == theta_time) {
		return;
	}
	theta_set = true;
	theta_time = t;
	for (int i = 0; i < count; i++) {
		theta[i] = phase[i] - omega[i] * t;
	}
}

// LakeWaveField.sample_at.
void NativeLakeWaves::sample_at(double x, double z, double time_s, int index) {
	amplitudes_for(x, z);
	const double *record = records.data() + size_t(index) * SAMPLE_SIZE;
	Vector2 rest = Vector2(real_t(x), real_t(z)); // GDScript: Vector2(x, z), 32 bits
	if (record[SAMPLE_IS_SET] > 0.5) {
		double sideways_x = record[SAMPLE_X] - record[SAMPLE_REST_X];
		double sideways_z = record[SAMPLE_Z] - record[SAMPLE_REST_Z];
		rest = Vector2(real_t(x - sideways_x), real_t(z - sideways_z));
	}
	if (count == 0) {
		write_sample(index, x, z, time_s, rest, base_height_m, Vector3(0, 1, 0), Vector3(0, 0, 0));
		return;
	}
	thetas_at(time_s);
	for (int pass_index = 0; pass_index < SOLVE_MAX_ITERATIONS; pass_index++) {
		Vector2 sideways(0, 0);
		for (int i = 0; i < count; i++) {
			double wave_k = k[i];
			double wave_x = dir_x[i];
			double wave_z = dir_z[i];
			double horizontal = steepness[i] / wave_k * std::cos(wave_k * (wave_x * double(rest.x) + wave_z * double(rest.y)) + theta[i]);
			sideways.x = real_t(double(sideways.x) + wave_x * horizontal); // GDScript: sideways.x += ..., 32 bits
			sideways.y = real_t(double(sideways.y) + wave_z * horizontal);
		}
		Vector2 next(real_t(x - double(sideways.x)), real_t(z - double(sideways.y)));
		double moved = next.distance_to(rest); // Godot's Vector2.distance_to, in 32 bits
		rest = next;
		if (moved < SOLVE_TOLERANCE_M) {
			break;
		}
	}
	answers_at_rest(x, z, time_s, rest, index);
}

void NativeLakeWaves::sample_points(const PackedFloat64Array &xz, double time_s) {
	const int64_t points = xz.size() / 2;
	const double *values = xz.ptr();
	for (int64_t i = 0; i < points; i++) {
		sample_at(values[2 * i], values[2 * i + 1], time_s, int(i));
	}
}

// LakeWaveField._answers_at_rest.
void NativeLakeWaves::answers_at_rest(double x, double z, double t, Vector2 rest, int index) {
	thetas_at(t);
	double rest_x = rest.x;
	double rest_z = rest.y;
	Vector3 displacement(0, 0, 0); // only its vertical part, the height, is needed
	Vector3 tangent_x(1, 0, 0);
	Vector3 tangent_z(0, 0, 1);
	Vector3 velocity(0, 0, 0);
	for (int i = 0; i < count; i++) {
		double wave_k = k[i];
		double wave_x = dir_x[i];
		double wave_z = dir_z[i];
		double wave_a = amplitude[i];
		double wave_s = steepness[i];
		double wave_omega = omega[i];
		double wave_phase = wave_k * (wave_x * rest_x + wave_z * rest_z) + theta[i];
		double sin_phase = std::sin(wave_phase);
		double cos_phase = std::cos(wave_phase);
		// Each += and -= on a vector's part: computed in 64 bits, kept in 32 (as GDScript).
		displacement.y = real_t(double(displacement.y) + wave_a * sin_phase);
		double cross_term = wave_x * wave_z * wave_s * sin_phase;
		tangent_x.x = real_t(double(tangent_x.x) - wave_x * wave_x * wave_s * sin_phase);
		tangent_x.y = real_t(double(tangent_x.y) + wave_a * wave_k * wave_x * cos_phase);
		tangent_x.z = real_t(double(tangent_x.z) - cross_term);
		tangent_z.x = real_t(double(tangent_z.x) - cross_term);
		tangent_z.y = real_t(double(tangent_z.y) + wave_a * wave_k * wave_z * cos_phase);
		tangent_z.z = real_t(double(tangent_z.z) - wave_z * wave_z * wave_s * sin_phase);
		double forward = wave_s * c[i] * sin_phase;
		velocity.x = real_t(double(velocity.x) + wave_x * forward);
		velocity.z = real_t(double(velocity.z) + wave_z * forward);
		velocity.y = real_t(double(velocity.y) - wave_a * wave_omega * cos_phase);
	}
	Vector3 normal = tangent_z.cross(tangent_x).normalized(); // Godot's Vector3, in 32 bits
	write_sample(index, x, z, t, rest, base_height_m + double(displacement.y), normal, velocity);
}

// WaterSurface.write_sample.
void NativeLakeWaves::write_sample(int index, double x, double z, double time_s, Vector2 rest, double height_m, Vector3 normal, Vector3 velocity_ms) {
	double *record = records.data() + size_t(index) * SAMPLE_SIZE;
	record[SAMPLE_X] = x;
	record[SAMPLE_Z] = z;
	record[SAMPLE_TIME_S] = time_s;
	record[SAMPLE_IS_SET] = 1.0;
	record[SAMPLE_REST_X] = rest.x;
	record[SAMPLE_REST_Z] = rest.y;
	record[SAMPLE_HEIGHT_M] = height_m;
	record[SAMPLE_NORMAL] = normal.x;
	record[SAMPLE_NORMAL + 1] = normal.y;
	record[SAMPLE_NORMAL + 2] = normal.z;
	record[SAMPLE_VELOCITY_MS] = velocity_ms.x;
	record[SAMPLE_VELOCITY_MS + 1] = velocity_ms.y;
	record[SAMPLE_VELOCITY_MS + 2] = velocity_ms.z;
}

} // namespace godot
