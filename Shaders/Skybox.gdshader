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
uniform float _StarExposure : hint_range(-16, 16) = 0;
uniform float _StarPower : hint_range(1, 5) = 1;
uniform float _StarLatitude : hint_range(-90, 90) = 0;
uniform float _StarSpeed = 0.001;
uniform samplerCube _StarConstellationCubemap : source_color;
uniform vec3 _StarConstellationColor : source_color = vec3(0.0, 0.3, 0.6);

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

vec3 getMoonTexture(vec3 dir)
{
	dir = _MoonWorldToObject * dir;
	// Rotate 180 degrees by flipping both x and z.
	dir.x = -dir.x;
	dir.z = -dir.z;
	
	return texture(_MoonCubemap, dir).rgb;
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

// Rotate the view direction, tilt with latitude, spin with time
vec3 GetStarUVW(vec3 viewDir, float latitude, float localSiderealTime)
{
    // tilt = 0 at the north pole, where latitude = 90 degrees
    float tilt = PI * (latitude - 90.0) / 180.0;
    mat3 tiltRotation = rotation3d(vec3(-1.0,0.0,0.0), tilt);

    // 0.75 is a texture offset for lST = 0 equals noon
    float spin = (0.75-localSiderealTime) * 2.0 * PI;
    mat3 spinRotation = rotation3d(vec3(0.0, 1.0, 0.0), spin);
    
    // The order of rotation is important
    return spinRotation * tiltRotation * viewDir;
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
	vec3 starUVW = GetStarUVW(viewDir, _StarLatitude, mod(TIME *  _StarSpeed, 1.0));
	vec3 starColor = texture(_StarCubemap, starUVW).rgb;
	starColor = pow(starColor, vec3(_StarPower));
	float starStrength = (1.0 - sunViewDot01) * (clamp(-sunZenithDot, 0.0, 1.0));
	float starMask = (1.0 - sunMask) * (1.0 - moonMask);
	starColor *= starMask * exp2(_StarExposure) * starStrength;
	
	// The constellations
	vec3 constColor = texture(_StarConstellationCubemap, starUVW).rgb;
	constColor *= _StarConstellationColor * starMask * starStrength;
	
	// Solar eclipse
	float solarEclipse01 = smoothstep(1.0 - _SunRadius * _SunRadius, 1.0, sunMoonDot);
	skyColor *= mix(1.0, 0.4, solarEclipse01);
	sunColor *= (1.0 - moonMask) * mix(1.0, 16.0, solarEclipse01);
	
	// Lunar eclipse
	float lunarEclipseMask = 1.0 - step(1.0 - _SunRadius * _SunRadius, -sunViewDot);
	float lunarEclipse01 = smoothstep(1.0 - _SunRadius * _SunRadius * 0.05, 1.0, -sunMoonDot);
	moonColor *= mix(vec3(lunarEclipseMask), vec3(0.3,0.05,0), lunarEclipse01);
	
	vec3 col = skyColor + sunColor + moonColor + starColor + constColor;
	
	COLOR = col;
}