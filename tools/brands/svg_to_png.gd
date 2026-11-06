extends SceneTree
## Draws SVG files as PNG pictures with Godot's own SVG renderer (ThorVG, the one the game's
## import uses): for tools/brands/make_logos.py on a computer without rsvg-convert. Each SVG's
## width and height attributes give the picture's size (make_logos.py puts the long side at
## 1024 px). Run headless, with pairs of paths after "--":
##     godot --headless --script tools/brands/svg_to_png.gd -- in.svg out.png [in2.svg out2.png ...]


func _initialize() -> void:
	var paths: PackedStringArray = OS.get_cmdline_user_args()
	var failed: int = 0
	for i: int in range(0, paths.size() - 1, 2):
		var image: Image = Image.new()
		var error: Error = image.load_svg_from_string(FileAccess.get_file_as_string(paths[i]), 1.0)
		if error == OK:
			error = image.save_png(paths[i + 1])
		if error != OK:
			printerr("Could not draw %s as %s: %s" % [paths[i], paths[i + 1], error_string(error)])
			failed += 1
	quit(1 if failed > 0 else 0)
