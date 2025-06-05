# Godot 4.4 Voxel Shaders Project

A Godot 4.4 project focused on experimenting with voxel rendering and shader development. This project includes various voxel shaders, procedural terrain generation, and a basic voxel world system.

## Project Structure

```
├── scenes/
│   └── Main.tscn              # Main scene with voxel world and player
├── scripts/
│   └── voxel/
│       ├── voxel_chunk.gd     # Individual voxel chunk management
│       ├── voxel_mesh_generator.gd # Mesh generation for voxel chunks
│       └── voxel_world.gd     # World manager and chunk loading
├── shaders/
│   ├── basic_voxel.gdshader   # Basic 2D voxel-style shader
│   ├── voxel_terrain.gdshader # 3D terrain shader with material blending
│   └── voxel_generation.glsl  # Compute shader for chunk generation
├── materials/
│   └── voxel_terrain_material.tres # Material using voxel terrain shader
└── textures/                  # Placeholder for texture assets
```

## Features

### Shaders Included
1. **Basic Voxel Shader** (`basic_voxel.gdshader`)
   - Canvas item shader for 2D voxel effects
   - Adjustable voxel size and lighting

2. **Voxel Terrain Shader** (`voxel_terrain.gdshader`)
   - 3D spatial shader for terrain rendering
   - Height-based material blending (grass, dirt, stone)
   - Procedural noise for variation

3. **Voxel Generation Compute Shader** (`voxel_generation.glsl`)
   - GPU-based chunk generation
   - Fractal noise terrain generation
   - Cave generation support

### Scripts Included
- **VoxelChunk**: Manages individual 16x16x16 voxel chunks
- **VoxelMeshGenerator**: Generates meshes from voxel data using marching cubes approach
- **VoxelWorld**: Handles infinite world generation and chunk loading/unloading

## Getting Started

### Prerequisites
- Godot 4.4 or newer
- Basic understanding of GDScript and GLSL shaders

### Running the Project
1. Open the project in Godot 4.4
2. Run the Main scene (`scenes/Main.tscn`)
3. Use WASD to move, mouse to look around, Space to jump
4. Press Escape to release mouse cursor

### Controls
- **WASD**: Move around
- **Mouse**: Look around
- **Space**: Jump
- **Escape**: Release mouse cursor

## Customization

### Modifying Terrain Generation
Edit the `generate_chunk()` function in `voxel_chunk.gd` to change terrain generation:
```gdscript
# Simple height generation
var height = int(8 + 4 * sin(world_x * 0.1) * cos(world_z * 0.1))
```

### Shader Parameters
The voxel terrain shader includes several adjustable parameters:
- `voxel_scale`: Controls the size of individual voxels
- `texture_scale`: UV scaling for textures
- `grass_height`: Height threshold for grass vs dirt
- `stone_height`: Height threshold for stone vs other materials

### Adding New Voxel Types
1. Extend the `get_voxel_type()` function in `voxel_chunk.gd`
2. Update the mesh generator to handle new materials
3. Modify the terrain shader for new material blending

## Advanced Features

### Compute Shader Integration
The project includes a compute shader template for GPU-based chunk generation. To use:
1. Create an RenderingDevice instance
2. Load and compile the compute shader
3. Set up buffer data and dispatch compute calls

### LOD (Level of Detail) System
Consider implementing:
- Distance-based mesh simplification
- Multiple chunk sizes for different distances
- Texture atlas optimization

### Performance Optimization
- Implement frustum culling for chunks
- Use object pooling for chunk instances
- Consider using Godot's MultiMesh for instanced rendering

## Learning Resources

### Voxel Rendering
- Marching Cubes algorithm
- Dual Contouring for smoother surfaces
- Greedy meshing for reduced vertex count

### Shader Development
- GLSL reference documentation
- Godot shader documentation
- Real-time rendering techniques

## Troubleshooting

### Common Issues
1. **Chunks not generating**: Check console for errors in voxel_chunk.gd
2. **Performance issues**: Reduce render distance or chunk size
3. **Shader compilation errors**: Verify Godot 4.4 compatibility

### Performance Tips
- Keep chunk size reasonable (16x16x16 is a good starting point)
- Implement chunk pooling to reduce garbage collection
- Use LOD for distant chunks

## Contributing

Feel free to extend this project with:
- New shader effects
- Improved terrain generation algorithms
- Performance optimizations
- Visual enhancements

## Next Steps

1. Add texture atlases for materials
2. Implement water and transparent blocks
3. Add lighting system integration
4. Create biome-based generation
5. Implement block placement/removal system

Happy voxel shader development! 🎮✨
