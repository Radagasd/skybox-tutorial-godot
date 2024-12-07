@tool # Make it run in editor (might need to close and reopen scene to work)
extends WorldEnvironment # We're modifying the sky material that is on a WorldEnvironment, so extend from there.

func _process(delta: float) -> void:
	var sun_dir = $"../Sun".get_global_transform().basis.z; # This is our forward direction pointing towards the sun
	var moon_basis = $"../Moon".get_global_transform().basis;
	var moon_dir = moon_basis.z; # This is our forward direction pointing towards the moon
	environment.sky.sky_material.set_shader_parameter('sun_dir', sun_dir); # Update sky material with sun direction
	environment.sky.sky_material.set_shader_parameter('moon_dir', moon_dir); # Update sky material with moon direction
	environment.sky.sky_material.set_shader_parameter('moon_world_to_object', moon_basis.inverse()); # The world to object matrix is the inverse of the basis (which is object to world)
	pass
