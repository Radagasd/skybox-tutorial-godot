shader_type sky;

uniform vec3 _SunDir;
uniform vec3 _MoonDir;

void sky() {
	vec3 viewDir = EYEDIR;
	viewDir = normalize(viewDir);

	vec3 col = vec3(step(0.9,dot(_SunDir, viewDir)), step(0.9,dot(_MoonDir, viewDir)), 0);
	COLOR = col;
}