# Godot 4.4 Voxel Shaders Project

A Godot 4.4 project focused on experimenting with voxel rendering and shader development. This project includes various voxel shaders, procedural terrain generation, multithreaded marching cubes, and a complete voxel world system.

## Project Structure

```
├── scenes/
│   ├── Main.tscn                           # Main scene with voxel world and player
│   └── ThreadedMarchingCubesTest.tscn     # Performance test scene
├── scripts/
│   └── voxel/
│       ├── voxel_chunk.gd                 # Individual voxel chunk management
│       ├── voxel_mesh_generator.gd        # Mesh generation for voxel chunks
│       ├── voxel_world.gd                 # World manager and chunk loading
│       ├── marching_cubes_generator.gd    # CPU marching cubes implementation
│       ├── threaded_marching_cubes_manager.gd # Multithreaded marching cubes
│       ├── threaded_voxel_world.gd        # High-performance voxel world
│       ├── gpu_marching_cubes_manager.gd  # GPU compute shader integration
│       └── threaded_marching_cubes_demo.gd # Performance comparison demo
├── shaders/
│   ├── basic_voxel.gdshader              # Basic 2D voxel-style shader
│   ├── voxel_terrain.gdshader            # 3D terrain shader with material blending
│   ├── voxel_generation.glsl             # Compute shader for chunk generation
│   └── marching_cubes_terrain.compute    # GPU marching cubes implementation
├── materials/
│   └── voxel_terrain_material.tres       # Material using voxel terrain shader
└── textures/                             # Placeholder for texture assets
```

## Features

### Multithreaded Marching Cubes System ⚡
- **WorkerThreadPool Integration**: Uses Godot 4.4's modern threading system
- **Parallel Chunk Generation**: Generate multiple chunks simultaneously
- **Dynamic Thread Scaling**: Automatically adapts to CPU core count
- **Priority System**: High-priority chunks (near player) process first
- **Performance Monitoring**: Real-time stats and performance comparison tools

### GPU Compute Pipeline 🔥
- **GPU Marching Cubes**: GLSL compute shaders for maximum performance
- **CPU Fallback**: Graceful degradation when GPU compute unavailable
- **Buffer Management**: Efficient GPU memory handling
- **Hybrid Architecture**: Combines CPU coordination with GPU acceleration

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

4. **Marching Cubes Compute Shader** (`marching_cubes_terrain.compute`)
   - GPU-accelerated marching cubes algorithm
   - Complete 256-case triangle table
   - Optimized for parallel execution

### Scripts Included
- **VoxelChunk**: Manages individual 32x32x32 voxel chunks
- **MarchingCubesMeshGenerator**: CPU marching cubes with surface optimization
- **ThreadedMarchingCubesManager**: Multithreaded chunk generation coordinator
- **ThreadedVoxelWorld**: High-performance infinite world with dynamic loading
- **GPUMarchingCubesManager**: GPU compute shader integration
- **VoxelWorld**: Basic voxel world implementation

## Performance Comparison

| Method | Chunks/sec | Avg Time/Chunk | Scalability |
|--------|------------|----------------|-------------|
| Single-threaded CPU | ~1-2 | 500-1000ms | Poor |
| Multi-threaded CPU | ~4-8 | 125-250ms | Good |
| GPU Compute Shader | ~10-20+ | 50-100ms | Excellent |

*Results vary based on hardware and chunk complexity*

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
- **Escape**: Release/capture mouse cursor
- **T**: Toggle world edit mode
- **R**: Cycle through voxel types (Grass, Dirt, Stone, Ore)
- **Left Click**: Place voxel (in edit mode)
- **Right Click**: Remove voxel (in edit mode)

## New Features Added

### Advanced Player Controller
- Proper WASD movement controls (fixed from arrow keys)
- Air control and improved physics
- Camera bobbing effect
- Mouse sensitivity controls
- World editing mode with visual feedback

### World Editing System
- Toggle edit mode with T key
- Place voxels with left click
- Remove voxels with right click  
- Cycle through 4 voxel types with R key
- Real-time mesh updates
- Smart chunk boundary handling

### Debug UI
- Real-time performance metrics
- Player position and state
- Chunk loading information
- Control reference
- Edit mode status

### Enhanced Terrain Generation
- Multi-octave noise for varied terrain
- Improved height-based material assignment
- Ore vein generation in deep stone layers
- Better surface detail

## Marching Cubes Terrain Generation

This project now includes a fully threaded marching cubes terrain generation system that creates smooth, organic terrain with caves and overhangs.

### Key Features

#### Threaded Generation
- **ThreadedChunkManager**: Manages a pool of worker threads for terrain generation
- **Non-blocking**: Terrain generation happens in background threads
- **Queue Management**: Intelligent queuing system prevents overloading
- **Performance Monitoring**: Built-in statistics and debugging

#### Marching Cubes Implementation
- **MarchingCubesGenerator**: Complete marching cubes algorithm implementation
- **Smooth Terrain**: Creates organic, cave-capable terrain from density fields
- **Multiple Noise Layers**: Uses FastNoiseLite for complex terrain features
- **Configurable**: Easy to adjust terrain characteristics

#### Enhanced Chunk System
- **Larger Chunks**: 32x32x32 voxel chunks for better performance
- **Density-Based**: Uses floating-point density values instead of discrete voxel types
- **Efficient Collision**: Automatic mesh-based collision generation
- **Seamless Integration**: Works with existing voxel editing system

### Architecture

```
VoxelWorld
├── ThreadedChunkManager (manages worker threads)
│   ├── Thread Pool (4 worker threads by default)
│   ├── Generation Queue (up to 16 pending chunks)
│   └── MarchingCubesGenerator (algorithm implementation)
├── VoxelChunk (enhanced for density data)
└── Player System (unchanged - still works with voxel editing)
```

### Usage

#### Basic Setup
1. Use the `MarchingCubesTest.tscn` scene as a starting point
2. The VoxelWorld will automatically initialize the threaded system
3. Chunks generate automatically as the player moves

#### Customization
- Adjust `render_distance` in VoxelWorld for view distance
- Modify noise settings in ThreadedChunkManager for different terrain
- Change `MAX_THREADS` in ThreadedChunkManager for performance tuning

### Performance Considerations

- **Thread Count**: Default 4 threads, adjust based on CPU cores
- **Chunk Size**: 32x32x32 provides good balance of detail and performance
- **Queue Size**: Limited to 16 pending generations to prevent memory issues
- **LOD**: Future enhancement - Level of Detail for distant chunks

### Debug Information

The enhanced DebugUI shows:
- Loaded chunk count
- Generating chunk count  
- Generation statistics
- Player position and chunk
- Thread pool status

### Testing

Run the project using:
```bash
godot --path .
```

Or use the VS Code task: "Run Godot Project"

The test scene includes:
- First-person player controller
- Voxel editing capabilities (still functional)
- Real-time debug information
- Smooth marching cubes terrain

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
