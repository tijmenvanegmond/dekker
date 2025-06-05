<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Godot 4.4 Voxel Shaders Project

This is a Godot 4.4 project focused on experimenting with voxel shaders and procedural generation.

## Project Context
- Engine: Godot 4.4
- Focus: Voxel rendering and shader development
- Language: GDScript for game logic, GLSL for shaders
- Rendering: Forward Plus renderer for advanced lighting

## Coding Guidelines
- Use GDScript best practices for game scripts
- Follow Godot's naming conventions (snake_case for variables, PascalCase for classes)
- Comment shader code extensively for learning purposes
- Organize shaders in the `shaders/` directory
- Keep voxel-related scripts in `scripts/voxel/`

## Shader Development
- Focus on performance-optimized voxel rendering
- Use compute shaders when appropriate for chunk generation
- Implement proper LOD (Level of Detail) systems
- Consider GPU instancing for voxel rendering
