class_name NeuralNet
extends RefCounted
## A small neural network, the brain of a learned skipper (RACING_PLAN.md, "The learned skipper",
## RD4): a multilayer perceptron. The observation (RaceObservation) goes in as a list of numbers;
## each layer multiplies them by its weights, adds its biases and squashes every sum with tanh, so
## each number that comes out lies between -1 and 1; the last layer gives the three actions (steer,
## sheet, tack), which are also -1 to 1.
##
## Nothing in here knows about sailing. How the network gets good is the trainer's business
## (Game/dev/evolve.gd): it makes many networks with random weights, lets each one sail a race,
## keeps the best and makes slightly changed copies of them (mutated()), generation after
## generation. The weights are all a network is, so a brain file (save()) is the weights plus a
## note of what the inputs mean and where the brain came from.

const FORMAT: String = "windsurfing-brain-1"


## One layer of neurons. Every neuron has one weight per input and one bias. The weights are kept
## in one flat array, neuron by neuron (the in_count weights of neuron 0, then those of neuron 1,
## and so on), because a flat PackedFloat32Array is the fastest thing GDScript can loop over, and
## the forward pass runs ten times a second for every board.
class Layer:
	var in_count: int = 0
	var out_count: int = 0
	var weights: PackedFloat32Array = PackedFloat32Array()
	var biases: PackedFloat32Array = PackedFloat32Array()
	## "tanh" squashes each sum into -1 to 1; "linear" leaves it as it is.
	var activation: String = "tanh"

	func _init(inputs: int, outputs: int, act: String = "tanh") -> void:
		in_count = inputs
		out_count = outputs
		activation = act
		weights.resize(inputs * outputs)
		biases.resize(outputs)

	## The weight from input i to neuron o.
	func weight(o: int, i: int) -> float:
		return weights[o * in_count + i]

	func set_weight(o: int, i: int, value: float) -> void:
		weights[o * in_count + i] = value

	## One layer's work: for each neuron, the bias plus the sum of every input times its weight,
	## through the activation.
	func forward(input: PackedFloat32Array) -> PackedFloat32Array:
		var output: PackedFloat32Array = PackedFloat32Array()
		output.resize(out_count)
		var squash: bool = activation == "tanh"
		var row: int = 0  # where this neuron's weights start in the flat array
		for o: int in out_count:
			var sum: float = biases[o]
			for i: int in in_count:
				sum += weights[row + i] * input[i]
			output[o] = tanh(sum) if squash else sum
			row += in_count
		return output

	func copy() -> Layer:
		var layer: Layer = Layer.new(in_count, out_count, activation)
		layer.weights = weights.duplicate()
		layer.biases = biases.duplicate()
		return layer


var layers: Array[Layer] = []
## What each input is, in order (RaceObservation.names()), so a brain file says what it expects.
var obs_names: PackedStringArray = PackedStringArray()
## Each input is multiplied by its scale before the first layer. Ones for a brain made by the
## trainer here (RaceObservation already scales its numbers); a brain trained elsewhere can carry
## its own input scaling in here.
var obs_scale: PackedFloat32Array = PackedFloat32Array()
## What each output is, in order.
var action_names: PackedStringArray = PackedStringArray()
## Where the brain came from: the course, the training run, the generation, its fitness, the date,
## the physics commit. Free-form; saved and loaded as it is.
var meta: Dictionary = {}
## select_inputs()'s map from this brain's inputs to the observation's numbers, and the list of
## names it was made for.
var _input_map: PackedInt32Array = PackedInt32Array()
var _input_map_for: PackedStringArray = PackedStringArray()
var _input_map_warned: bool = false


## A new network with small random weights. sizes lists the number of neurons from the inputs to
## the outputs: [58, 64, 64, 3] is 58 inputs, two hidden layers of 64 and 3 outputs. Each weight is
## drawn from a bell curve of width 1 / sqrt(inputs of its layer), so that a sum of many inputs
## still lands mostly between -1 and 1, where tanh is not yet flat (a network whose neurons are all
## pinned at -1 or 1 cannot tell one situation from another). The biases start at 0.
## output_scale shrinks the last layer's weights: with 0.1 a new network's answers start close to 0
## (for a skipper: steer little, leave the sheet to the auto-sheet, do not tack), so it sails
## straight and fast enough to learn from, instead of throwing the helm about from the first second.
## (The same idea as the small last layer that PPO implementations start their policies with.)
static func make(sizes: Array[int], rng: RandomNumberGenerator, output_scale: float = 1.0) -> NeuralNet:
	var net: NeuralNet = NeuralNet.new()
	for n: int in sizes.size() - 1:
		var layer: Layer = Layer.new(sizes[n], sizes[n + 1], "tanh")
		var spread: float = 1.0 / sqrt(float(maxi(sizes[n], 1)))
		if n == sizes.size() - 2:
			spread *= output_scale
		for k: int in layer.weights.size():
			layer.weights[k] = rng.randfn(0.0, spread)
		net.layers.append(layer)
	net.obs_scale.resize(net.input_count())
	net.obs_scale.fill(1.0)
	return net


func input_count() -> int:
	return layers[0].in_count if not layers.is_empty() else 0


func output_count() -> int:
	return layers[-1].out_count if not layers.is_empty() else 0


## The layer sizes, from the inputs to the outputs, as make() takes them.
func sizes() -> Array[int]:
	var result: Array[int] = []
	if layers.is_empty():
		return result
	result.append(layers[0].in_count)
	for layer: Layer in layers:
		result.append(layer.out_count)
	return result


## How many numbers the network is made of: every weight and every bias.
func parameter_count() -> int:
	var count: int = 0
	for layer: Layer in layers:
		count += layer.weights.size() + layer.biases.size()
	return count


## Runs the network: the inputs (scaled by obs_scale) through every layer in turn. The input must
## have input_count() numbers.
func forward(input: PackedFloat32Array) -> PackedFloat32Array:
	var values: PackedFloat32Array = input
	if obs_scale.size() == input.size():
		values = PackedFloat32Array()
		values.resize(input.size())
		for i: int in input.size():
			values[i] = input[i] * obs_scale[i]
	for layer: Layer in layers:
		values = layer.forward(values)
	return values


## The inputs this brain wants, picked by name from an observation whose numbers are called
## `names` (RaceObservation.names()): the observation itself when the brain's inputs have the same
## names, or none; otherwise each of the brain's inputs is the observation's number of that name,
## so a brain from before a number was added to the observation still sails (a name the
## observation no longer has reads 0, with one warning). The map is worked out once per list.
func select_inputs(observation: PackedFloat32Array, names: PackedStringArray) -> PackedFloat32Array:
	if obs_names.is_empty() or obs_names == names:
		return observation
	if _input_map_for != names or _input_map.size() != obs_names.size():
		_input_map_for = names.duplicate()
		_input_map.resize(obs_names.size())
		var missing: PackedStringArray = PackedStringArray()
		for i: int in obs_names.size():
			_input_map[i] = names.find(obs_names[i])
			if _input_map[i] < 0:
				missing.append(obs_names[i])
		if not missing.is_empty() and not _input_map_warned:
			_input_map_warned = true
			push_warning("NeuralNet: the observation has no %s; those inputs read 0." % ", ".join(missing))
	var picked: PackedFloat32Array = PackedFloat32Array()
	picked.resize(_input_map.size())
	for i: int in _input_map.size():
		var k: int = _input_map[i]
		picked[i] = observation[k] if k >= 0 and k < observation.size() else 0.0
	return picked


## A copy of this network: the same weights, the names and the note.
func copy() -> NeuralNet:
	var net: NeuralNet = NeuralNet.new()
	for layer: Layer in layers:
		net.layers.append(layer.copy())
	net.obs_names = obs_names.duplicate()
	net.obs_scale = obs_scale.duplicate()
	net.action_names = action_names.duplicate()
	net.meta = meta.duplicate(true)
	return net


## A child for the next generation: a copy with a little random noise on every weight and bias,
## drawn from a bell curve of width sigma. Most children are a little worse than their parent; now
## and then one is a little better, and the trainer keeps that one. That is all the learning.
func mutated(sigma: float, rng: RandomNumberGenerator) -> NeuralNet:
	var child: NeuralNet = copy()
	for layer: Layer in child.layers:
		for k: int in layer.weights.size():
			layer.weights[k] += rng.randfn(0.0, sigma)
		for o: int in layer.biases.size():
			layer.biases[o] += rng.randfn(0.0, sigma)
	return child


## A child of two parents of the same shape: each neuron, with all its weights and its bias, comes
## from one parent or the other, as a coin says. A whole neuron is taken at a time because a neuron
## is a little detector that only works with its own weights; mixing single weights of two parents
## mostly gives a detector of nothing. The rest (names, note) is this parent's.
func crossover(other: NeuralNet, rng: RandomNumberGenerator) -> NeuralNet:
	var child: NeuralNet = copy()
	if other.sizes() != sizes():
		return child
	for n: int in child.layers.size():
		var layer: Layer = child.layers[n]
		var theirs: Layer = other.layers[n]
		for o: int in layer.out_count:
			if rng.randf() < 0.5:
				continue
			layer.biases[o] = theirs.biases[o]
			for i: int in layer.in_count:
				layer.set_weight(o, i, theirs.weight(o, i))
	return child


# ---------------------------------------------------------------- the brain file

## The brain as plain data, as the brain file holds it (RD4): the layers (the weights as one row per
## neuron, the biases, the activation), the names and scales of the inputs, the names of the
## outputs, and the note.
func to_dict() -> Dictionary:
	var layer_list: Array = []
	for layer: Layer in layers:
		var rows: Array = []
		for o: int in layer.out_count:
			var row: Array = []
			for i: int in layer.in_count:
				row.append(layer.weight(o, i))
			rows.append(row)
		layer_list.append({"w": rows, "b": Array(layer.biases), "act": layer.activation})
	return {
		"format": FORMAT,
		"layers": layer_list,
		"obs_names": Array(obs_names),
		"obs_scale": Array(obs_scale),
		"action_names": Array(action_names),
		"meta": meta,
	}


## The network a dictionary from to_dict() describes; null (with an error) if it is not one.
static func from_dict(data: Dictionary) -> NeuralNet:
	var layer_list: Array = data.get("layers", [])
	if layer_list.is_empty():
		push_error("NeuralNet: the brain has no layers.")
		return null
	var net: NeuralNet = NeuralNet.new()
	for entry: Variant in layer_list:
		var layer_data: Dictionary = entry
		var rows: Array = layer_data.get("w", [])
		var biases: Array = layer_data.get("b", [])
		if rows.is_empty() or rows.size() != biases.size():
			push_error("NeuralNet: a layer needs one row of weights and one bias per neuron.")
			return null
		var first_row: Array = rows[0]
		var layer: Layer = Layer.new(first_row.size(), rows.size(), str(layer_data.get("act", "tanh")))
		for o: int in rows.size():
			var row: Array = rows[o]
			if row.size() != layer.in_count:
				push_error("NeuralNet: the rows of a layer must all be as long.")
				return null
			for i: int in row.size():
				layer.set_weight(o, i, float(row[i]))
			layer.biases[o] = float(biases[o])
		if not net.layers.is_empty() and net.layers[-1].out_count != layer.in_count:
			push_error("NeuralNet: a layer takes %d inputs but the one before gives %d." % [layer.in_count, net.layers[-1].out_count])
			return null
		net.layers.append(layer)
	net.obs_names = PackedStringArray(data.get("obs_names", []))
	net.obs_scale = PackedFloat32Array(data.get("obs_scale", []))
	if net.obs_scale.size() != net.input_count():
		net.obs_scale.resize(net.input_count())
		net.obs_scale.fill(1.0)
	net.action_names = PackedStringArray(data.get("action_names", []))
	var note: Variant = data.get("meta", {})
	net.meta = note if note is Dictionary else {}
	return net


## Writes the brain file: JSON, the note and the names first, then one line per neuron, so that a
## person can open it and see what it is. Returns OK or the file error.
func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var data: Dictionary = to_dict()
	file.store_line("{")
	for key: String in ["format", "meta", "action_names", "obs_names", "obs_scale"]:
		file.store_line("\t%s: %s," % [JSON.stringify(key), JSON.stringify(data[key], "", false, true)])
	file.store_line("\t\"layers\": [")
	var layer_list: Array = data["layers"]
	for n: int in layer_list.size():
		var layer_data: Dictionary = layer_list[n]
		file.store_line("\t\t{\"act\": %s, \"b\": %s, \"w\": [" % [JSON.stringify(layer_data["act"]), JSON.stringify(layer_data["b"], "", false, true)])
		var rows: Array = layer_data["w"]
		for o: int in rows.size():
			file.store_line("\t\t\t%s%s" % [JSON.stringify(rows[o], "", false, true), "," if o < rows.size() - 1 else ""])
		file.store_line("\t\t]}%s" % ("," if n < layer_list.size() - 1 else ""))
	file.store_line("\t]")
	file.store_line("}")
	file.close()
	return OK


## Reads a brain file; null (with an error) if it cannot.
static func load_file(path: String) -> NeuralNet:
	if not FileAccess.file_exists(path):
		push_error("NeuralNet: no brain file at %s." % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("NeuralNet: %s is not a brain file (not a JSON object)." % path)
		return null
	return from_dict(parsed)
