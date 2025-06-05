#[compute]
#version 450

// Compute shader for generating voxel chunks
local_size_x = 8
local_size_y = 8
local_size_z = 8

layout(set = 0, binding = 0, std430) restrict buffer VoxelBuffer {
    uint voxel_data[];
};

layout(set = 0, binding = 1) uniform Params {
    ivec3 chunk_size;
    float noise_scale;
    float height_multiplier;
    float density_threshold;
    vec3 chunk_offset;
};

// Simple 3D noise function
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

float noise3d(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    
    float n = p.x + p.y * 57.0 + 113.0 * p.z;
    return mix(
        mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
            mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
        mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
            mix(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
}

float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise3d(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return value;
}

void main() {
    ivec3 coord = ivec3(gl_GlobalInvocationID.xyz);
    
    if (coord.x >= chunk_size.x || coord.y >= chunk_size.y || coord.z >= chunk_size.z) {
        return;
    }
    
    vec3 world_pos = vec3(coord) + chunk_offset;
    
    // Generate terrain height using noise
    float height = fbm(world_pos.xz * noise_scale) * height_multiplier;
    
    // Determine voxel type based on position and noise
    uint voxel_type = 0; // 0 = air
    
    if (world_pos.y < height) {
        // Add some cave generation
        float cave_noise = fbm(world_pos * 0.1);
        if (cave_noise > density_threshold) {
            if (world_pos.y > height - 2.0) {
                voxel_type = 1; // grass
            } else if (world_pos.y > height - 5.0) {
                voxel_type = 2; // dirt
            } else {
                voxel_type = 3; // stone
            }
        }
    }
    
    int index = coord.x + coord.y * chunk_size.x + coord.z * chunk_size.x * chunk_size.y;
    voxel_data[index] = voxel_type;
}
