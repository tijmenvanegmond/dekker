shader_type canvas_item;

// Basic voxel-style shader with pixelated effect
uniform float voxel_size : hint_range(1.0, 32.0) = 8.0;
uniform vec3 light_direction : hint_range(-1.0, 1.0) = vec3(0.5, -0.5, 0.5);
uniform float light_intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec3 base_color : source_color = vec3(0.8, 0.8, 0.8);

varying vec3 world_position;

vec3 voxelize_position(vec3 pos) {
    return floor(pos * voxel_size) / voxel_size;
}

void vertex() {
    world_position = VERTEX;
}

void fragment() {
    vec3 voxel_pos = voxelize_position(world_position);
    
    // Simple lighting calculation
    vec3 normal = normalize(cross(dFdx(voxel_pos), dFdy(voxel_pos)));
    float light = max(0.0, dot(normal, normalize(-light_direction)));
    
    vec3 final_color = base_color * (0.3 + 0.7 * light * light_intensity);
    
    COLOR = vec4(final_color, 1.0);
}
