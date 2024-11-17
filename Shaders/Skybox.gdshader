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

group_uniforms Sun;
uniform float _SunRadius : hint_range(0, 1) = 0.05;
uniform vec3 _SunColor : source_color = vec3(1.0, 1.0, 1.0);

group_uniforms Moon;
uniform float _MoonRadius : hint_range(0, 1) = 0.05;
uniform float _MoonExposure : hint_range(-16, 16) = 0;
uniform sampler2D _MoonPanorama : source_color;
uniform mat3 _MoonSpaceMatrix;

float GetSunMask(float sunViewDot, float sunRadius)
{
	float stepRadius = 1.0 - sunRadius * sunRadius;
	return step(stepRadius, sunViewDot);
}

// From Inigo Quilez, https://www.iquilezles.org/www/articles/intersectors/intersectors.htm
float sphIntersect(vec3 rayDir, vec3 spherePos, float radius)
{
    vec3 oc = -spherePos;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - radius * radius;
    float h = b * b - c;
    if(h < 0.0) return -1.0;
    h = sqrt(h);
    return -b - h;
}

// Based on Godot's calculation of SKY_COORDS (aka panorama_coords) https://github.com/godotengine/godot/blob/1bffd6c73b44b85e5889f54e14b2193940cf5bb1/drivers/gles3/shaders/sky.glsl#L176
// And Ben Golus's article for dealing with the mip-map seam https://bgolus.medium.com/distinctive-derivative-differences-cce38d36797b#24b8
vec2 NormalToEquirectangularCoords(vec3 normal)
{
	vec2 uv = vec2(atan(normal.z, normal.x), acos(normal.y));
	uv /= vec2(PI * 2.0, PI);
	
	float x_fract = fract(uv.x);
	uv.x = fwidthCoarse(uv.x) - 0.0001 < fwidthCoarse(x_fract) ? uv.x : x_fract;
	return uv;
}

vec3 GetMoonTexture(vec3 normal)
{
	normal = normal * _MoonSpaceMatrix;
	mat3 correctionMatrix = mat3( vec3(0.0, -0.24869, 0.968583), vec3(0.0, 0.968583, 0.24869), vec3(-1.0, 0.0, 0.0));
	normal = normal * correctionMatrix;
	vec2 uv = NormalToEquirectangularCoords(normal);
    return texture(_MoonPanorama, uv).rgb;
}

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
	vec3 viewZenithColor = texture(_ViewZenithGrad, vec2(sunZenithDot01, 0.5)).rgb;
	float vzMask = pow(clamp(1.0 - viewZenithDot, 0.0, 1.0), 4);
	vec3 sunViewColor = texture(_SunViewGrad, vec2(sunZenithDot01, 0.5)).rgb;
	float svMask = pow(clamp(sunViewDot, 0.0, 1.0), 4);
	
	vec3 skyColor = sunZenithColor + vzMask * viewZenithColor + svMask * sunViewColor;
	
	// The sun
	float sunMask = GetSunMask(sunViewDot, _SunRadius);
	vec3 sunColor = _SunColor * sunMask;
	
	// The moon
	float moonIntersect = sphIntersect(viewDir, _MoonDir, _MoonRadius);
	float moonMask = moonIntersect > -1.0 ? 1.0 : 0.0;
	vec3 moonNormal = normalize(viewDir * moonIntersect - _MoonDir);
	float moonNdotL = clamp(dot(moonNormal, _SunDir), 0.0, 1.0);
	vec3 moonTexture = GetMoonTexture(moonNormal);
	vec3 moonColor = moonMask * moonNdotL * exp2(_MoonExposure) * moonTexture;

	vec3 col = skyColor + sunColor + moonColor;
	
	COLOR = col;
}