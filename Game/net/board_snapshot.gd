class_name BoardSnapshot
extends RefCounted
## The whole physics state of one board, so another PC can show that board exactly as its own PC
## sails it (LAN multiplayer, Documentation/reports/multiplayer/PLAN.md, D4 to D6).
##
## What travels is every number the simulation keeps: the WindsurferSim itself and its parts (the
## body, the sailor, the mass model, the buoyancy, the hull, the fin, the sail, the rig frame and the
## telemetry). On the other PC the board is a "puppet": a real WindsurferSim with the same gear that
## is never stepped. The numbers are written into it (apply()) and the normal visuals pose it, so the
## other player's rig, sail shape, sailor, falls and spray are what their physics did.
##
## The list of numbers is not written by hand: it is read from the scripts (Godot's property list
## of each object, in the scripts' own order: layout()). So it follows every change Michiel makes to
## the physics. Both PCs must run the same build; layout_hash() is compared when they connect.
##
## A state is a flat list of 32-bit floats (values()): a float, an int or a bool takes one slot, a
## Vector2 two, a Vector3 three, a Quaternion four, a Basis nine; and the few strings in a list of
## their own (texts()). Objects (the configs, the models' links to each other) and the scratch
## arrays the physics rebuilds every tick are not part of it.
##
## To keep the messages small, a board first sends one full state, its keyframe, and after that
## each state carries only the slots that differ from the keyframe (encode_diff()): the many
## numbers worked out once from the gear never travel again.

## The sim's parts that hold state, by their field name on WindsurferSim; "" is the sim itself.
const PARTS: Array[String] = ["", "body", "sailor", "mass_model", "buoyancy", "hull", "fin", "sail", "rig", "telemetry"]

## How a slot is drawn between two states (interpolate()).
enum Kind {
	LINEAR,      ## a float or a vector component: in between
	ANGLE_DEG,   ## an angle in degrees (the name ends in _deg): the short way round
	ANGLE_RAD,   ## an angle in radians (the name ends in _rad): the short way round
	STEP,        ## an int, a bool (and enums): the nearer state's value
	BASIS,       ## the first of a Basis's nine slots: a rotation by slerp, anything else in between
	BASIS_REST,  ## the other eight slots of a Basis (drawn with its first)
}


## One field of the state: which part, its name, its type and where its slots start.
class Field:
	var part: int = 0
	## As a StringName: the engine looks a property up by StringName, and a String would be
	## turned into one on every get() and set() (half the cost of capture() and apply()).
	var name: StringName = &""
	var type: int = TYPE_NIL
	## The first slot in values() (for a String: its index in texts()).
	var slot: int = 0


## The fields in order, the slots' kinds, and the sizes. Worked out once from a real simulation
## (layout()); the same on every PC with the same build.
class Layout:
	var fields: Array[Field] = []
	var kinds: PackedByteArray = PackedByteArray()
	var slot_count: int = 0
	var text_count: int = 0
	var hash_value: int = 0
	## Where the body's centre of mass (body.position) and its attitude (body.basis) start: an
	## in-between tick moves only these (body_between()).
	var body_position_slot: int = -1
	var body_basis_slot: int = -1


static var _layout: Layout = null

## The values (floats) and the strings of this state.
var values: PackedFloat32Array = PackedFloat32Array()
var texts: PackedStringArray = PackedStringArray()


# ---------------------------------------------------------------- the layout

## The layout of every board's state, worked out once from a simulation on the default gear (the
## gear changes the numbers, not which numbers there are).
static func layout() -> Layout:
	if _layout == null:
		_layout = _make_layout(WindsurferSim.create_for(EnvironmentConfig.new(), false, false))
	return _layout


## A number that is the same on two PCs exactly when their layouts are the same: compared when a
## guest connects, so two different builds never try to read each other's boards.
static func layout_hash() -> int:
	return layout().hash_value


static func _make_layout(sim: WindsurferSim) -> Layout:
	var made: Layout = Layout.new()
	var signature: PackedStringArray = PackedStringArray()
	for part: int in PARTS.size():
		var holder: Object = _part_of(sim, part)
		if holder == null:
			continue
		for property: Dictionary in holder.get_property_list():
			if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var type: int = int(property["type"])
			var size: int = _slots_of(type)
			if size == 0 and type != TYPE_STRING:
				continue  # objects and arrays do not travel
			var field: Field = Field.new()
			field.part = part
			field.name = StringName(property["name"])
			field.type = type
			if type == TYPE_STRING:
				field.slot = made.text_count
				made.text_count += 1
			else:
				field.slot = made.slot_count
				made.slot_count += size
				_add_kinds(made.kinds, field)
			made.fields.append(field)
			signature.append("%d.%s:%d" % [part, field.name, type])
			if PARTS[part] == "body" and field.name == &"position":
				made.body_position_slot = field.slot
			elif PARTS[part] == "body" and field.name == &"basis":
				made.body_basis_slot = field.slot
	made.hash_value = hash("|".join(signature))
	return made


## How many float slots a type takes; 0 for the types that do not travel.
static func _slots_of(type: int) -> int:
	match type:
		TYPE_FLOAT, TYPE_INT, TYPE_BOOL:
			return 1
		TYPE_VECTOR2:
			return 2
		TYPE_VECTOR3:
			return 3
		TYPE_QUATERNION:
			return 4
		TYPE_BASIS:
			return 9
	return 0


static func _add_kinds(kinds: PackedByteArray, field: Field) -> void:
	match field.type:
		TYPE_INT, TYPE_BOOL:
			kinds.append(Kind.STEP)
		TYPE_BASIS:
			kinds.append(Kind.BASIS)
			for i: int in 8:
				kinds.append(Kind.BASIS_REST)
		TYPE_FLOAT:
			if field.name.ends_with("_deg"):
				kinds.append(Kind.ANGLE_DEG)
			elif field.name.ends_with("_rad"):
				kinds.append(Kind.ANGLE_RAD)
			else:
				kinds.append(Kind.LINEAR)
		_:
			for i: int in _slots_of(field.type):
				kinds.append(Kind.LINEAR)


static func _part_of(sim: WindsurferSim, part: int) -> Object:
	if PARTS[part] == "":
		return sim
	return sim.get(PARTS[part]) as Object


# ---------------------------------------------------------------- reading and writing a simulation

## The state of a simulation now (about 0.2 ms: the loop over the fields is the cost; reading all
## members at once with inst_to_dict() was measured slower, Session 69).
static func capture(sim: WindsurferSim) -> BoardSnapshot:
	var shape: Layout = layout()
	var state: BoardSnapshot = BoardSnapshot.new()
	state.values.resize(shape.slot_count)
	state.texts.resize(shape.text_count)
	var holders: Array[Object] = _holders(sim)
	for field: Field in shape.fields:
		var value: Variant = holders[field.part].get(field.name)
		var s: int = field.slot
		match field.type:
			TYPE_FLOAT:
				state.values[s] = float(value)
			TYPE_INT:
				state.values[s] = float(int(value))
			TYPE_BOOL:
				state.values[s] = 1.0 if bool(value) else 0.0
			TYPE_VECTOR2:
				var v2: Vector2 = value
				state.values[s] = v2.x
				state.values[s + 1] = v2.y
			TYPE_VECTOR3:
				var v3: Vector3 = value
				state.values[s] = v3.x
				state.values[s + 1] = v3.y
				state.values[s + 2] = v3.z
			TYPE_QUATERNION:
				var q: Quaternion = value
				state.values[s] = q.x
				state.values[s + 1] = q.y
				state.values[s + 2] = q.z
				state.values[s + 3] = q.w
			TYPE_BASIS:
				var b: Basis = value
				for column: int in 3:
					var axis: Vector3 = b[column]
					state.values[s + column * 3] = axis.x
					state.values[s + column * 3 + 1] = axis.y
					state.values[s + column * 3 + 2] = axis.z
			TYPE_STRING:
				state.texts[s] = String(value)
	return state


## Writes this state into a simulation (a puppet's: it is not stepped afterwards). Its wind and
## water are its own; only the board's numbers change. With `before`, the state this simulation
## already holds, only the fields that differ from it are written: writing a field is the costly
## part (the engine's set(), about half a microsecond), and the gear's constants never change.
func apply(sim: WindsurferSim, before: BoardSnapshot = null) -> void:
	var shape: Layout = layout()
	if values.size() != shape.slot_count or texts.size() != shape.text_count:
		push_error("A board state of another layout (%d slots, %d expected)." % [values.size(), shape.slot_count])
		return
	if before != null and before.values.size() != values.size():
		before = null
	var holders: Array[Object] = _holders(sim)
	for field: Field in shape.fields:
		if before != null and _same_as(before, field):
			continue
		holders[field.part].set(field.name, _value_of(field))


## Whether a field holds the same value here as in another state.
func _same_as(other: BoardSnapshot, field: Field) -> bool:
	if field.type == TYPE_STRING:
		return texts[field.slot] == other.texts[field.slot]
	for i: int in range(field.slot, field.slot + _slots_of(field.type)):
		if values[i] != other.values[i]:
			return false
	return true


## The body's centre of mass and attitude a share t from state a to state b (positions in between,
## the attitude by slerp): what a board shown between two states moves by (NetBoards).
static func body_between(a: BoardSnapshot, b: BoardSnapshot, t: float) -> Transform3D:
	var shape: Layout = layout()
	var pa: int = shape.body_position_slot
	var ba: int = shape.body_basis_slot
	var from: Transform3D = Transform3D(_basis_at(a.values, ba), Vector3(a.values[pa], a.values[pa + 1], a.values[pa + 2]))
	if b == null or b == a or t <= 0.0:
		return from
	var to: Transform3D = Transform3D(_basis_at(b.values, ba), Vector3(b.values[pa], b.values[pa + 1], b.values[pa + 2]))
	if t >= 1.0:
		return to
	var rotation: Quaternion = from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), t)
	return Transform3D(Basis(rotation), from.origin.lerp(to.origin, t))


static func _basis_at(slots: PackedFloat32Array, i: int) -> Basis:
	return Basis(Vector3(slots[i], slots[i + 1], slots[i + 2]), Vector3(slots[i + 3], slots[i + 4], slots[i + 5]),
		Vector3(slots[i + 6], slots[i + 7], slots[i + 8]))


## A field's value from the slots, as its own type.
func _value_of(field: Field) -> Variant:
	var s: int = field.slot
	match field.type:
		TYPE_FLOAT:
			return float(values[s])
		TYPE_INT:
			return roundi(values[s])
		TYPE_BOOL:
			return values[s] >= 0.5
		TYPE_VECTOR2:
			return Vector2(values[s], values[s + 1])
		TYPE_VECTOR3:
			return Vector3(values[s], values[s + 1], values[s + 2])
		TYPE_QUATERNION:
			return Quaternion(values[s], values[s + 1], values[s + 2], values[s + 3])
		TYPE_BASIS:
			return Basis(Vector3(values[s], values[s + 1], values[s + 2]), Vector3(values[s + 3], values[s + 4], values[s + 5]),
				Vector3(values[s + 6], values[s + 7], values[s + 8]))
		TYPE_STRING:
			return texts[s]
	return null


## One field's value by its part and name (for the tests and the race's checks); null if there is
## no such field.
func get_field(part_name: String, field_name: String) -> Variant:
	var part: int = PARTS.find(part_name)
	for field: Field in layout().fields:
		if field.part == part and field.name == field_name:
			return _value_of(field)
	return null


static func _holders(sim: WindsurferSim) -> Array[Object]:
	var holders: Array[Object] = []
	for part: int in PARTS.size():
		holders.append(_part_of(sim, part))
	return holders


# ---------------------------------------------------------------- between two states

## The state a share `t` of the way from `a` to `b` (0 is a, 1 is b): in-between numbers, the
## short way round for angles, rotations by slerp, and on/off values and strings from the nearer.
static func interpolate(a: BoardSnapshot, b: BoardSnapshot, t: float) -> BoardSnapshot:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var kinds: PackedByteArray = layout().kinds
	var out: BoardSnapshot = BoardSnapshot.new()
	out.values = b.values.duplicate()
	out.texts = b.texts if t >= 0.5 else a.texts
	var i: int = 0
	var count: int = kinds.size()
	while i < count:
		var va: float = a.values[i]
		var vb: float = b.values[i]
		match kinds[i]:
			Kind.LINEAR:
				out.values[i] = lerpf(va, vb, t)
			Kind.ANGLE_DEG:
				out.values[i] = _short_way(va, vb, t, 180.0)
			Kind.ANGLE_RAD:
				out.values[i] = _short_way(va, vb, t, PI)
			Kind.STEP:
				out.values[i] = vb if t >= 0.5 else va
			Kind.BASIS:
				_basis_between(a.values, b.values, out.values, i, t)
				i += 8
		i += 1
	return out


## An angle a share t of the way from a to b the short way round (half_turn is 180 degrees or pi),
## kept in the range the angles came in: 0 to a full turn when neither is negative, else plus or
## minus a half turn. (A heading of 359 to 1 degree passes 0, not 180.)
static func _short_way(a: float, b: float, t: float, half_turn: float) -> float:
	var difference: float = wrapf(b - a, -half_turn, half_turn)
	var between: float = b - difference * (1.0 - t)
	if a < 0.0 or b < 0.0:
		return wrapf(between, -half_turn, half_turn)
	return fposmod(between, 2.0 * half_turn)


## The Basis in slots i to i+8 a share t of the way: a rotation (orthonormal) by slerp, anything
## else (an inertia) number by number.
static func _basis_between(from: PackedFloat32Array, to: PackedFloat32Array, out: PackedFloat32Array, i: int, t: float) -> void:
	var ba: Basis = Basis(Vector3(from[i], from[i + 1], from[i + 2]), Vector3(from[i + 3], from[i + 4], from[i + 5]), Vector3(from[i + 6], from[i + 7], from[i + 8]))
	var bb: Basis = Basis(Vector3(to[i], to[i + 1], to[i + 2]), Vector3(to[i + 3], to[i + 4], to[i + 5]), Vector3(to[i + 6], to[i + 7], to[i + 8]))
	var result: Basis
	if _is_rotation(ba) and _is_rotation(bb):
		result = Basis(ba.get_rotation_quaternion().slerp(bb.get_rotation_quaternion(), t))
	else:
		result = Basis(ba.x.lerp(bb.x, t), ba.y.lerp(bb.y, t), ba.z.lerp(bb.z, t))
	for column: int in 3:
		var axis: Vector3 = result[column]
		out[i + column * 3] = axis.x
		out[i + column * 3 + 1] = axis.y
		out[i + column * 3 + 2] = axis.z


static func _is_rotation(b: Basis) -> bool:
	return absf(b.determinant() - 1.0) < 1e-3 and b.is_equal_approx(b.orthonormalized())


# ---------------------------------------------------------------- on the wire

## The whole state as bytes: the keyframe (sent once per board, reliably).
func encode_full() -> PackedByteArray:
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.put_32(values.size())
	buffer.put_data(values.to_byte_array())
	_put_texts(buffer, texts)
	return buffer.data_array


static func decode_full(bytes: PackedByteArray) -> BoardSnapshot:
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = bytes
	var state: BoardSnapshot = BoardSnapshot.new()
	var count: int = buffer.get_32()
	if count != layout().slot_count:
		push_error("A keyframe of another layout (%d slots, %d expected)." % [count, layout().slot_count])
		return null
	state.values = (buffer.get_data(count * 4)[1] as PackedByteArray).to_float32_array()
	state.texts = _get_texts(buffer)
	return state


## Only what differs from the keyframe: a bit per slot (set where the slot differs), the differing
## slots' values, then the strings that differ (their index and text).
func encode_diff(keyframe: BoardSnapshot) -> PackedByteArray:
	var count: int = values.size()
	var mask: PackedByteArray = PackedByteArray()
	mask.resize((count + 7) / 8)
	var changed: PackedFloat32Array = PackedFloat32Array()
	# The comparison is on the 32-bit values as they travel, so a slot equal to the keyframe's is
	# equal on the other PC too.
	for i: int in count:
		if values[i] != keyframe.values[i]:
			mask[i >> 3] |= 1 << (i & 7)
			changed.append(values[i])
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.put_data(mask)
	buffer.put_32(changed.size())
	buffer.put_data(changed.to_byte_array())
	var text_changes: PackedInt32Array = PackedInt32Array()
	for i: int in texts.size():
		if texts[i] != keyframe.texts[i]:
			text_changes.append(i)
	buffer.put_8(text_changes.size())
	for i: int in text_changes:
		buffer.put_8(i)
		buffer.put_utf8_string(texts[i])
	return buffer.data_array


static func decode_diff(bytes: PackedByteArray, keyframe: BoardSnapshot) -> BoardSnapshot:
	var state: BoardSnapshot = BoardSnapshot.new()
	state.values = keyframe.values.duplicate()
	state.texts = keyframe.texts.duplicate()
	var count: int = state.values.size()
	var buffer: StreamPeerBuffer = StreamPeerBuffer.new()
	buffer.data_array = bytes
	var mask: PackedByteArray = buffer.get_data((count + 7) / 8)[1]
	var changed_count: int = buffer.get_32()
	var changed: PackedFloat32Array = (buffer.get_data(changed_count * 4)[1] as PackedByteArray).to_float32_array()
	var next: int = 0
	for i: int in count:
		if mask[i >> 3] & (1 << (i & 7)):
			if next >= changed.size():
				push_error("A board state cut short.")
				return null
			state.values[i] = changed[next]
			next += 1
	var text_changes: int = buffer.get_u8()
	for j: int in text_changes:
		var index: int = buffer.get_u8()
		var text: String = buffer.get_utf8_string()
		if index < state.texts.size():
			state.texts[index] = text
	return state


static func _put_texts(buffer: StreamPeerBuffer, list: PackedStringArray) -> void:
	buffer.put_8(list.size())
	for text: String in list:
		buffer.put_utf8_string(text)


static func _get_texts(buffer: StreamPeerBuffer) -> PackedStringArray:
	var list: PackedStringArray = PackedStringArray()
	var count: int = buffer.get_u8()
	for i: int in count:
		list.append(buffer.get_utf8_string())
	return list
