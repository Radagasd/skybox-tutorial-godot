shader_type sky;

group_uniforms directions;
uniform vec3 sun_dir;
uniform vec3 moon_dir;

group_uniforms sky_gradients;
/** The gradient texture that is sampled using the Sun-Zenith angle */
uniform sampler2D sun_zenith_gradient : source_color, repeat_disable;
/** The gradient texture that is sampled using the View-Zenith angle */
uniform sampler2D view_zenith_gradient : source_color, repeat_disable;
/** The gradient texture that is sampled using the Sun-View angle */
uniform sampler2D sun_view_gradient : source_color, repeat_disable;

group_uniforms sun;
uniform float sun_radius : hint_range(0, 1) = 0.05;
uniform vec3 sun_color : source_color = vec3(1.0, 1.0, 1.0);

group_uniforms moon;
uniform float moon_radius : hint_range(0, 1) = 0.05;
uniform float moon_exposure : hint_range(-16, 16) = 0;
uniform samplerCube moon_cubemap : source_color;
uniform mat3 moon_world_to_object;

group_uniforms stars;
uniform samplerCube star_cubemap : source_color;
uniform float star_exposure : hint_range(-16, 16) = 0;
uniform float star_power : hint_range(1, 5) = 1;
uniform float star_latitude : hint_range(-90, 90) = 0;
uniform float star_speed = 0.001;
uniform samplerCube star_constellation_cubemap : source_color;
uniform vec3 star_constellation_color : source_color = vec3(0.0, 0.3, 0.6);

float get_sun_mask(float sunViewDot, float sunRadius)
{
	float stepRadius = 1.0 - sunRadius * sunRadius;
	return step(stepRadius, sunViewDot);
}

// From Inigo Quilez, https://iquilezles.org/articles/intersectors/
float sphere_intersect(vec3 rayDir, vec3 spherePos, float radius)
{
    vec3 oc = -spherePos;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - radius * radius;
    float h = b * b - c;
    if(h < 0.0) return -1.0;
    h = sqrt(h);
    return -b - h;
}

vec3 get_moon_texture(vec3 dir)
{
	dir = moon_world_to_object * dir;
	// Rotate 180 degrees by flipping both x and z.
	dir.x = -dir.x;
	dir.z = -dir.z;
	
	return texture(moon_cubemap, dir).rgb;
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
vec3 get_star_uvw(vec3 viewDir, float latitude, float localSiderealTime)
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
	float sunViewDot = dot(sun_dir, viewDir);
	float sunZenithDot = sun_dir.y;
	float viewZenithDot = viewDir.y;
	float sunMoonDot = dot(sun_dir, moon_dir);
	
	float sunViewDot01 = (sunViewDot + 1.0) * 0.5;
	float sunZenithDot01 = (sunZenithDot + 1.0) * 0.5;
	
	// Sky colours
	vec3 sunZenithColor = texture(sun_zenith_gradient, vec2(sunZenithDot01, 0.5)).rgb;
	vec3 viewZenithColor = texture(view_zenith_gradient, vec2(sunZenithDot01, 0.5)).rgb;
	float vzMask = pow(clamp(1.0 - viewZenithDot, 0.0, 1.0), 4);
	vec3 sunViewColor = texture(sun_view_gradient, vec2(sunZenithDot01, 0.5)).rgb;
	float svMask = pow(clamp(sunViewDot, 0.0, 1.0), 4);
	
	vec3 skyColor = sunZenithColor + vzMask * viewZenithColor + svMask * sunViewColor;
	
	// The sun
	float sunMask = get_sun_mask(sunViewDot, sun_radius);
	vec3 sunColor = sun_color * sunMask;
	
	// The moon
	float moonIntersect = sphere_intersect(viewDir, moon_dir, moon_radius);
	float moonMask = moonIntersect > -1.0 ? 1.0 : 0.0;
	vec3 moonNormal = normalize(viewDir * moonIntersect - moon_dir);
	float moonNdotL = clamp(dot(moonNormal, sun_dir), 0.0, 1.0);
	vec3 moonTexture = get_moon_texture(moonNormal);
	vec3 moonColor = moonMask * moonNdotL * exp2(moon_exposure) * moonTexture;
	
	// The stars
	vec3 starUVW = get_star_uvw(viewDir, star_latitude, mod(TIME *  star_speed, 1.0));
	vec3 starColor = texture(star_cubemap, starUVW).rgb;
	starColor = pow(starColor, vec3(star_power));
	float starStrength = (1.0 - sunViewDot01) * (clamp(-sunZenithDot, 0.0, 1.0));
	float starMask = (1.0 - sunMask) * (1.0 - moonMask);
	starColor *= starMask * exp2(star_exposure) * starStrength;
	
	// The constellations
	vec3 constColor = texture(star_constellation_cubemap, starUVW).rgb;
	constColor *= star_constellation_color * starMask * starStrength;
	
	// Solar eclipse
	float solarEclipse01 = smoothstep(1.0 - sun_radius * sun_radius, 1.0, sunMoonDot);
	skyColor *= mix(1.0, 0.4, solarEclipse01);
	sunColor *= (1.0 - moonMask) * mix(1.0, 16.0, solarEclipse01);
	
	// Lunar eclipse
	float lunarEclipseMask = 1.0 - step(1.0 - sun_radius * sun_radius, -sunViewDot);
	float lunarEclipse01 = smoothstep(1.0 - sun_radius * sun_radius * 0.05, 1.0, -sunMoonDot);
	moonColor *= mix(vec3(lunarEclipseMask), vec3(0.3,0.05,0), lunarEclipse01);
	
	vec3 col = skyColor + sunColor + moonColor + starColor + constColor;
	
	COLOR = col;
}