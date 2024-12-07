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

float get_sun_mask(float sun_view_dot, float radius)
{
	float step_radius = 1.0 - radius * radius;
	return step(step_radius, sun_view_dot);
}

// From Inigo Quilez, https://iquilezles.org/articles/intersectors/
float sphere_intersect(vec3 ray_dir, vec3 sphere_pos, float radius)
{
    vec3 oc = -sphere_pos;
    float b = dot(oc, ray_dir);
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
vec3 get_star_uvw(vec3 view_dir, float latitude, float local_sidereal_time)
{
    // tilt = 0 at the north pole, where latitude = 90 degrees
    float tilt = PI * (latitude - 90.0) / 180.0;
    mat3 tilt_rotation = rotation3d(vec3(-1.0,0.0,0.0), tilt);

    // 0.75 is a texture offset for lST = 0 equals noon
    float spin = (0.75-local_sidereal_time) * 2.0 * PI;
    mat3 spin_rotation = rotation3d(vec3(0.0, 1.0, 0.0), spin);
    
    // The order of rotation is important
    return spin_rotation * tilt_rotation * view_dir;
}

void sky() {
	vec3 view_dir = EYEDIR;
	
	// Main angles
	float sun_view_dot = dot(sun_dir, view_dir);
	float sun_zenith_dot = sun_dir.y;
	float view_zenith_dot = view_dir.y;
	float sun_moon_dot = dot(sun_dir, moon_dir);
	
	float sun_view_dot01 = (sun_view_dot + 1.0) * 0.5;
	float sun_zenith_dot01 = (sun_zenith_dot + 1.0) * 0.5;
	
	// Sky colours
	vec3 sun_zenith_color = texture(sun_zenith_gradient, vec2(sun_zenith_dot01, 0.5)).rgb;
	vec3 view_zenith_color = texture(view_zenith_gradient, vec2(sun_zenith_dot01, 0.5)).rgb;
	float vz_mask = pow(clamp(1.0 - view_zenith_dot, 0.0, 1.0), 4);
	vec3 sun_view_color = texture(sun_view_gradient, vec2(sun_zenith_dot01, 0.5)).rgb;
	float sv_mask = pow(clamp(sun_view_dot, 0.0, 1.0), 4);
	
	vec3 sky_output = sun_zenith_color + vz_mask * view_zenith_color + sv_mask * sun_view_color;
	
	// The sun
	float sun_mask = get_sun_mask(sun_view_dot, sun_radius);
	vec3 sun_output = sun_color * sun_mask;
	
	// The moon
	float moon_intersect = sphere_intersect(view_dir, moon_dir, moon_radius);
	float moon_mask = moon_intersect > -1.0 ? 1.0 : 0.0;
	vec3 moon_normal = normalize(view_dir * moon_intersect - moon_dir);
	float moon_ndotl = clamp(dot(moon_normal, sun_dir), 0.0, 1.0);
	vec3 moon_texture = get_moon_texture(moon_normal);
	vec3 moon_output = moon_mask * moon_ndotl * exp2(moon_exposure) * moon_texture;
	
	// The stars
	vec3 star_uvw = get_star_uvw(view_dir, star_latitude, mod(TIME *  star_speed, 1.0));
	vec3 star_output = texture(star_cubemap, star_uvw).rgb;
	star_output = pow(star_output, vec3(star_power));
	float star_strength = (1.0 - sun_view_dot01) * (clamp(-sun_zenith_dot, 0.0, 1.0));
	float star_mask = (1.0 - sun_mask) * (1.0 - moon_mask);
	star_output *= star_mask * exp2(star_exposure) * star_strength;
	
	// The constellations
	vec3 constellation_ouput = texture(star_constellation_cubemap, star_uvw).rgb;
	constellation_ouput *= star_constellation_color * star_mask * star_strength;
	
	// Solar eclipse
	float solar_eclipse01 = smoothstep(1.0 - sun_radius * sun_radius, 1.0, sun_moon_dot);
	sky_output *= mix(1.0, 0.4, solar_eclipse01);
	sun_output *= (1.0 - moon_mask) * mix(1.0, 16.0, solar_eclipse01);
	
	// Lunar eclipse
	float lunar_eclipse_mask = 1.0 - step(1.0 - sun_radius * sun_radius, -sun_view_dot);
	float lunar_eclipse01 = smoothstep(1.0 - sun_radius * sun_radius * 0.05, 1.0, -sun_moon_dot);
	moon_output *= mix(vec3(lunar_eclipse_mask), vec3(0.3,0.05,0), lunar_eclipse01);
	
	vec3 output = sky_output + sun_output + moon_output + star_output + constellation_ouput;
	
	COLOR = output;
}