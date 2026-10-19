extends GutTest
## NeuralNet, a learned skipper's brain (RACING_PLAN.md, RD4): a small network with weights set by
## hand gives the outputs worked out by hand; a brain file saved and loaded again gives the same
## network; a mutated copy differs from its parent by about the noise asked for; a crossover child
## takes every neuron from one parent or the other; and the observation it is fed has one name per
## number.

const BRAIN_PATH: String = "user://test_neural_net_brain.json"


func after_all() -> void:
	if FileAccess.file_exists(BRAIN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BRAIN_PATH))


## Two inputs, two hidden neurons, one output, every weight chosen by hand:
##   hidden 0 = tanh(0.5 x0 - 1.0 x1 + 0.1)
##   hidden 1 = tanh(1.0 x0 + 2.0 x1 - 0.2)
##   output   = tanh(1.0 h0 - 0.5 h1 + 0.3)
static func _hand_net() -> NeuralNet:
	var net: NeuralNet = NeuralNet.new()
	var hidden: NeuralNet.Layer = NeuralNet.Layer.new(2, 2, "tanh")
	hidden.weights = PackedFloat32Array([0.5, -1.0, 1.0, 2.0])
	hidden.biases = PackedFloat32Array([0.1, -0.2])
	var output: NeuralNet.Layer = NeuralNet.Layer.new(2, 1, "tanh")
	output.weights = PackedFloat32Array([1.0, -0.5])
	output.biases = PackedFloat32Array([0.3])
	net.layers.append(hidden)
	net.layers.append(output)
	return net


func test_a_hand_set_network_gives_the_hand_computed_outputs() -> void:
	var net: NeuralNet = _hand_net()
	# For the input (1.0, 0.5): hidden 0 = tanh(0.1) = 0.0996680, hidden 1 = tanh(1.8) = 0.9468060,
	# output = tanh(0.0996680 - 0.4734030 + 0.3) = tanh(-0.0737350) = -0.0736017.
	var out: PackedFloat32Array = net.forward(PackedFloat32Array([1.0, 0.5]))
	assert_eq(out.size(), 1)
	assert_almost_eq(out[0], -0.0736017, 1e-6, "the output of the hand-set network")
	# Without the squashing on the output the sum itself comes out.
	net.layers[1].activation = "linear"
	assert_almost_eq(net.forward(PackedFloat32Array([1.0, 0.5]))[0], -0.0737350, 1e-6, "the linear output")
	# The input scale multiplies each input before the first layer: scaling the inputs by 2 is the
	# same as feeding (2.0, 1.0).
	net.layers[1].activation = "tanh"
	net.obs_scale = PackedFloat32Array([2.0, 2.0])
	var scaled: float = net.forward(PackedFloat32Array([1.0, 0.5]))[0]
	net.obs_scale = PackedFloat32Array([1.0, 1.0])
	assert_almost_eq(scaled, net.forward(PackedFloat32Array([2.0, 1.0]))[0], 1e-6, "the input scale")


func test_a_new_network_has_the_shape_asked_for_and_outputs_between_minus_1_and_1() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var sizes: Array[int] = [10, 8, 8, 3]
	var net: NeuralNet = NeuralNet.make(sizes, rng)
	assert_eq(net.sizes(), sizes)
	assert_eq(net.parameter_count(), 10 * 8 + 8 + 8 * 8 + 8 + 8 * 3 + 3)
	var input: PackedFloat32Array = PackedFloat32Array()
	for i: int in 10:
		input.append(rng.randf_range(-3.0, 3.0))
	var out: PackedFloat32Array = net.forward(input)
	assert_eq(out.size(), 3)
	for value: float in out:
		assert_true(value > -1.0 and value < 1.0, "tanh keeps every action within -1 and 1: %f" % value)


func test_a_brain_file_saved_and_loaded_gives_the_same_network() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var sizes: Array[int] = [RaceObservation.size(), 16, 3]
	var net: NeuralNet = NeuralNet.make(sizes, rng)
	net.obs_names = RaceObservation.names()
	net.action_names = LearnedSkipper.ACTION_NAMES
	net.meta = {"run": "test", "generation": 7, "physics_commit": "abc1234"}
	assert_eq(net.save(BRAIN_PATH), OK)
	var loaded: NeuralNet = NeuralNet.load_file(BRAIN_PATH)
	assert_not_null(loaded)
	assert_eq(loaded.sizes(), sizes)
	assert_eq(loaded.obs_names, net.obs_names)
	assert_eq(loaded.action_names, net.action_names)
	assert_eq(loaded.obs_scale.size(), RaceObservation.size())
	assert_eq(int(loaded.meta["generation"]), 7)
	assert_eq(str(loaded.meta["physics_commit"]), "abc1234")
	var worst: float = 0.0
	for n: int in net.layers.size():
		for k: int in net.layers[n].weights.size():
			worst = maxf(worst, absf(net.layers[n].weights[k] - loaded.layers[n].weights[k]))
		for k: int in net.layers[n].biases.size():
			worst = maxf(worst, absf(net.layers[n].biases[k] - loaded.layers[n].biases[k]))
	assert_true(worst < 1e-6, "every weight comes back within 1e-6 (the worst is %s)" % str(worst))
	var input: PackedFloat32Array = PackedFloat32Array()
	for i: int in RaceObservation.size():
		input.append(rng.randf_range(-1.0, 1.0))
	var before: PackedFloat32Array = net.forward(input)
	var after: PackedFloat32Array = loaded.forward(input)
	for k: int in before.size():
		assert_almost_eq(after[k], before[k], 1e-6, "the same output %d" % k)


func test_a_broken_brain_file_is_refused() -> void:
	assert_null(NeuralNet.from_dict({"layers": []}), "no layers")
	assert_null(NeuralNet.from_dict({"layers": [{"w": [[1.0, 2.0]], "b": [0.0], "act": "tanh"}, {"w": [[1.0, 2.0, 3.0]], "b": [0.0]}]}),
		"a layer that does not fit the one before")
	assert_push_error_count(2)


func test_a_mutated_copy_differs_by_about_sigma_and_leaves_the_parent_alone() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var sizes: Array[int] = [40, 32, 3]
	var parent: NeuralNet = NeuralNet.make(sizes, rng)
	var kept: NeuralNet = parent.copy()
	var child: NeuralNet = parent.mutated(0.1, rng)
	var sum_squares: float = 0.0
	var count: int = 0
	for n: int in parent.layers.size():
		for k: int in parent.layers[n].weights.size():
			sum_squares += pow(child.layers[n].weights[k] - parent.layers[n].weights[k], 2.0)
			count += 1
			assert_eq(parent.layers[n].weights[k], kept.layers[n].weights[k], "the parent is unchanged")
	var rms: float = sqrt(sum_squares / count)
	assert_almost_eq(rms, 0.1, 0.01, "the noise on the weights has the width asked for (%f)" % rms)


func test_a_crossover_child_takes_each_neuron_whole_from_one_parent() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	var sizes: Array[int] = [6, 12, 3]
	var a: NeuralNet = NeuralNet.make(sizes, rng)
	var b: NeuralNet = NeuralNet.make(sizes, rng)
	var child: NeuralNet = a.crossover(b, rng)
	var from_a: int = 0
	var from_b: int = 0
	for n: int in child.layers.size():
		var layer: NeuralNet.Layer = child.layers[n]
		for o: int in layer.out_count:
			# The parents' weights are random, so the first one says whose neuron this is (the
			# biases start at 0 in both and cannot tell).
			var like_a: bool = layer.weight(o, 0) == a.layers[n].weight(o, 0)
			var source: NeuralNet = a if like_a else b
			for i: int in layer.in_count:
				assert_eq(layer.weight(o, i), source.layers[n].weight(o, i), "neuron %d of layer %d is one parent's" % [o, n])
			assert_eq(layer.biases[o], source.layers[n].biases[o], "and so is its bias")
			if like_a:
				from_a += 1
			else:
				from_b += 1
	assert_true(from_a > 0 and from_b > 0, "both parents gave neurons (%d and %d)" % [from_a, from_b])


func test_the_observation_has_one_name_per_number() -> void:
	var names: PackedStringArray = RaceObservation.names()
	var env: RaceEnv = RaceEnv.new(RaceCourses.t1_loop(270.0, Vector2.ZERO), 1, 15.0)
	env.reset(1)
	assert_eq(env.observe(0).size(), names.size(), "names() and build() are as long")
	assert_eq(RaceObservation.size(), names.size())
	var seen: Dictionary[String, bool] = {}
	for name: String in names:
		assert_false(seen.has(name), "the name %s is used once" % name)
		seen[name] = true
