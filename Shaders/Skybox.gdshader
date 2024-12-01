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
uniform samplerCube _MoonCubemap : source_color;
uniform mat3 _MoonWorldToObject;

group_uniforms Stars;
uniform samplerCube _StarCubemap : source_color;

float getSunMask(float sunViewDot, float sunRadius)
{
	float stepRadius = 1.0 - sunRadius * sunRadius;
	return step(stepRadius, sunViewDot);
}

// From Inigo Quilez, https://iquilezles.org/articles/intersectors/
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

// Construct a rotation matrix that rotates around a particular axis by angle
// Adapted from: https://github.com/dmnsgn/glsl-rotate
mat3 rotation3d(vec3 axis, float angle) {
  axis = normalize(axis);
  float s = sin(angle);
  float c = cos(angle);
  float oc = 1.0 - c;

  return mat3(
    vec3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s),
    vec3(oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s),
    vec3(oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c));
}

vec3 getMoonTexture(vec3 dir)
{
	dir = _MoonWorldToObject * dir;
	// Rotate 180 degrees by flipping both x and z.
	dir.x = -dir.x;
	dir.z = -dir.z;
	
	return texture(_MoonCubemap, dir).rgb;
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
	float sunMask = getSunMask(sunViewDot, _SunRadius);
	vec3 sunColor = _SunColor * sunMask;
	
	// The moon
	float moonIntersect = sphIntersect(viewDir, _MoonDir, _MoonRadius);
	float moonMask = moonIntersect > -1.0 ? 1.0 : 0.0;
	vec3 moonNormal = normalize(viewDir * moonIntersect - _MoonDir);
	float moonNdotL = clamp(dot(moonNormal, _SunDir), 0.0, 1.0);
	vec3 moonTexture = getMoonTexture(moonNormal);
	vec3 moonColor = moonMask * moonNdotL * exp2(_MoonExposure) * moonTexture;
	
	// The stars
	vec3 starColor = texture(_StarCubemap, viewDir, -1.0).rgb;

	vec3 col = skyColor + sunColor + moonColor + starColor;
	
	COLOR = col;
}