import sys
# shader_wind_classes.py water.gdshader : the debug render of the wind classes (9 grey levels of the wind ratio); never commit the result
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "\tSPECULAR = 0.25 * darker * glassier;\n}"
new = ("\tSPECULAR = 0.25 * darker * glassier;\n\tALBEDO = vec3(0.0); SPECULAR = 0.0; ROUGHNESS = 1.0; "
       "EMISSION = vec3(0.02 + 0.04 * clamp(floor((wind_ratio_here(world_position.xz) - 0.8) / 0.05), 0.0, 8.0));\n}")
assert s.count(old) == 1
s = s.replace(old, new)
open(p, "w", encoding="utf-8", newline="\n").write(s)
