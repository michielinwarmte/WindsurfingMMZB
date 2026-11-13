extends SceneTree
## Runs NativeSeaBench in the editor engine: tools/native.sh test [-- --seconds=10].


func _initialize() -> void:
	var seconds: float = 10.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			seconds = arg.get_slice("=", 1).to_float()
	NativeSeaBench.run(seconds)
	quit(0)
