# shader_without_gusts.py in.gdshader out.gdshader : the same water with the gust picture read as 1 everywhere (for a measurement only)
import sys
s = open(sys.argv[1], encoding="utf-8").read()
old = "float wind_ripple_factor(vec2 position) {\n"
assert s.count(old) == 1
s = s.replace(old, old + "\treturn 1.0;\n")
old = "float wind_recent_ratio(vec2 position) {\n"
s = s.replace(old, old + "\treturn 1.0;\n")
open(sys.argv[2], "w", encoding="utf-8", newline="\n").write(s)
