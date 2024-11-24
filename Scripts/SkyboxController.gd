@tool # Make it run in editor (might need to close and reopen scene to work)
extends WorldEnvironment # We're modifying the sky material that is on a WorldEnvironment, so extend from there.

func _process(delta: float) -> void:
	var sun_dir = $"../Sun".get_global_transform().basis.z; # This is our forward direction pointing towards the sun
	var moonBasis = $"../Moon".get_global_transform().basis;
	var moon_dir = moonBasis.z; # This is our forward direction pointing towards the moon
	environment.sky.sky_material.set_shader_parameter('_SunDir', sun_dir); # Update sky material with sun direction
	environment.sky.sky_material.set_shader_parameter('_MoonDir', moon_dir); # Update sky material with moon direction
	environment.sky.sky_material.set_shader_parameter('_MoonSpaceMatrix', moonBasis);
	pass
