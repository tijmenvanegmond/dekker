shader_type spatial;

// 3D Voxel terrain shader with atlas support
uniform float voxel_scale : hint_range(0.1, 10.0) = 1.0;
uniform sampler2D texture_atlas : source_color;
uniform float texture_scale : hint_range(0.1, 10.0) = 1.0;
uniform float atlas_tile_size : hint_range(0.1, 1.0) = 0.25;

// Enhanced material blending
uniform float grass_height : hint_range(0.0, 1.0) = 0.6;
uniform float stone_height : hint_range(0.0, 1.0) = 0.85;
uniform float blend_sharpness : hint_range(0.1, 5.0) = 2.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying flat int material_id;

void vertex() {
	world_pos = VERTEX;
	world_normal = NORMAL;
	
	// Determine material ID based on world position (simplified)
	float height_factor = (world_pos.y + 10.0) * 0.1; // Normalize roughly
	if (height_factor < grass_height) {
		material_id = 0; // Grass
	} else if (height_factor < stone_height) {
		material_id = 1; // Dirt
	} else {
		material_id = 2; // Stone
	}
}

void fragment() {
	vec3 voxel_pos = floor(world_pos * voxel_scale) / voxel_scale;
	vec2 base_uv = voxel_pos.xz * texture_scale;
	
	// Calculate atlas UV based on material ID
	vec2 atlas_uv = base_uv;
	atlas_uv.x = mod(atlas_uv.x, 1.0) * atlas_tile_size + float(material_id) * atlas_tile_size;
	atlas_uv.y = mod(atlas_uv.y, 1.0);
	
	// Sample from atlas
	vec3 albedo_color = texture(texture_atlas, atlas_uv).rgb;
	
	// Add some variation based on position
	float noise_variation = sin(world_pos.x * 0.5) * cos(world_pos.z * 0.7) * 0.1;
	albedo_color *= (1.0 + noise_variation);
	
	ALBEDO = albedo_color;
	ROUGHNESS = 0.8;
	METALLIC = (material_id == 3) ? 0.2 : 0.0; // Ore has some metallic properties
}
