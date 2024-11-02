shader_type sky;

group_uniforms Directions;
uniform vec3 _SunDir;
uniform vec3 _MoonDir;

group_uniforms SkyGradients;
/** The gradient texture that is sampled using the Sun-Zenith angle */
uniform sampler2D _SunZenithGrad : source_color, repeat_disable;
/** The gradient texture that is sampled using the View-Zenith angle */
uniform sampler2D _ViewZenithGrad : source_color, repeat_disable;
/** The gradient texture that is sampled using the Sun-View angle */
uniform sampler2D _SunViewGrad : source_color, repeat_disable;

void sky() {
	vec3 viewDir = EYEDIR;
	
	// Main angles
	float sunViewDot = dot(_SunDir, viewDir);
	float sunZenithDot = _SunDir.y;
	float viewZenithDot = viewDir.y;
	float sunMoonDot = dot(_SunDir, _MoonDir);
	
	float sunViewDot01 = (sunViewDot + 1.0) * 0.5;
	float sunZenithDot01 = (sunZenithDot + 1.0) * 0.5;
	
	// Sky colours
	vec3 sunZenithColor = texture(_SunZenithGrad, vec2(sunZenithDot01, 0.5)).rgb;

	vec3 skyColor = sunZenithColor;

	vec3 col = skyColor;

	COLOR = col;
}