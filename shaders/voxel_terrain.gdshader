shader_type spatial;

// 3D Voxel terrain shader with multiple materials
uniform float voxel_scale : hint_range(0.1, 10.0) = 1.0;
uniform sampler2D texture_grass : source_color;
uniform sampler2D texture_stone : source_color;
uniform sampler2D texture_dirt : source_color;
uniform float texture_scale : hint_range(0.1, 10.0) = 1.0;

// Voxel material blending
uniform float grass_height : hint_range(0.0, 1.0) = 0.7;
uniform float stone_height : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

vec3 hash3(vec3 p) {
    p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
             dot(p, vec3(269.5, 183.3, 246.1)),
             dot(p, vec3(113.5, 271.9, 124.6)));
    return fract(sin(p) * 43758.5453123);
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    vec3 h000 = hash3(i);
    vec3 h100 = hash3(i + vec3(1.0, 0.0, 0.0));
    vec3 h010 = hash3(i + vec3(0.0, 1.0, 0.0));
    vec3 h110 = hash3(i + vec3(1.0, 1.0, 0.0));
    vec3 h001 = hash3(i + vec3(0.0, 0.0, 1.0));
    vec3 h101 = hash3(i + vec3(1.0, 0.0, 1.0));
    vec3 h011 = hash3(i + vec3(0.0, 1.0, 1.0));
    vec3 h111 = hash3(i + vec3(1.0, 1.0, 1.0));
    
    float n000 = dot(h000, f);
    float n100 = dot(h100, f - vec3(1.0, 0.0, 0.0));
    float n010 = dot(h010, f - vec3(0.0, 1.0, 0.0));
    float n110 = dot(h110, f - vec3(1.0, 1.0, 0.0));
    float n001 = dot(h001, f - vec3(0.0, 0.0, 1.0));
    float n101 = dot(h101, f - vec3(1.0, 0.0, 1.0));
    float n011 = dot(h011, f - vec3(0.0, 1.0, 1.0));
    float n111 = dot(h111, f - vec3(1.0, 1.0, 1.0));
    
    float x00 = mix(n000, n100, f.x);
    float x10 = mix(n010, n110, f.x);
    float x01 = mix(n001, n101, f.x);
    float x11 = mix(n011, n111, f.x);
    
    float y0 = mix(x00, x10, f.y);
    float y1 = mix(x01, x11, f.y);
    
    return mix(y0, y1, f.z);
}

void vertex() {
    world_pos = VERTEX;
    world_normal = NORMAL;
}

void fragment() {
    vec3 voxel_pos = floor(world_pos * voxel_scale) / voxel_scale;
    vec2 uv = voxel_pos.xz * texture_scale;
    
    // Height-based material blending
    float height_factor = (world_pos.y + 1.0) * 0.5; // Normalize to 0-1
    float noise_factor = noise(voxel_pos * 4.0) * 0.1;
    
    vec3 grass_color = texture(texture_grass, uv).rgb;
    vec3 dirt_color = texture(texture_dirt, uv).rgb;
    vec3 stone_color = texture(texture_stone, uv).rgb;
    
    vec3 final_color;
    if (height_factor + noise_factor < grass_height) {
        final_color = mix(dirt_color, grass_color, smoothstep(0.0, grass_height, height_factor + noise_factor));
    } else if (height_factor + noise_factor < stone_height) {
        final_color = mix(grass_color, stone_color, smoothstep(grass_height, stone_height, height_factor + noise_factor));
    } else {
        final_color = stone_color;
    }
    
    ALBEDO = final_color;
    ROUGHNESS = 0.8;
    METALLIC = 0.0;
}
