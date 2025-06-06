shader_type spatial;

// Tri-planar voxel terrain shader for marching cubes geometry
uniform float texture_scale : hint_range(0.1, 10.0) = 2.0;
uniform float blend_sharpness : hint_range(1.0, 32.0) = 8.0;

// Material textures
uniform sampler2D grass_texture : source_color, hint_default_white;
uniform sampler2D dirt_texture : source_color, hint_default_white;
uniform sampler2D stone_texture : source_color, hint_default_white;

// Material blending heights
uniform float grass_height : hint_range(0.0, 20.0) = 8.0;
uniform float stone_height : hint_range(0.0, 20.0) = 15.0;
uniform float transition_width : hint_range(0.1, 5.0) = 2.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = VERTEX;
	world_normal = NORMAL;
}

// Tri-planar texture sampling
vec3 triplanar_sample(sampler2D tex, vec3 pos, vec3 normal) {
	vec3 blend_weights = abs(normal);
	blend_weights = pow(blend_weights, vec3(blend_sharpness));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);
	
	vec3 x_sample = texture(tex, pos.yz * texture_scale).rgb;
	vec3 y_sample = texture(tex, pos.xz * texture_scale).rgb;
	vec3 z_sample = texture(tex, pos.xy * texture_scale).rgb;
	
	return x_sample * blend_weights.x + y_sample * blend_weights.y + z_sample * blend_weights.z;
}

void fragment() {
	vec3 scaled_pos = world_pos * 0.1; // Scale down for texture tiling
	
	// Sample all three material textures using tri-planar mapping
	vec3 grass_color = triplanar_sample(grass_texture, scaled_pos, world_normal);
	vec3 dirt_color = triplanar_sample(dirt_texture, scaled_pos, world_normal);
	vec3 stone_color = triplanar_sample(stone_texture, scaled_pos, world_normal);
	
	// Height-based material blending
	float height = world_pos.y;
	
	// Calculate blend factors
	float grass_factor = smoothstep(grass_height - transition_width, grass_height, height);
	float stone_factor = smoothstep(stone_height - transition_width, stone_height, height);
	
	// Blend materials based on height
	vec3 final_color = grass_color;
	final_color = mix(final_color, dirt_color, grass_factor);
	final_color = mix(final_color, stone_color, stone_factor);
	
	// Add some subtle variation based on world position
	float variation = sin(world_pos.x * 0.1) * cos(world_pos.z * 0.15) * 0.05;
	final_color *= (1.0 + variation);
	
	ALBEDO = final_color;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}
