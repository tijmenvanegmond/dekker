class_name VoxelMeshGenerator
extends RefCounted

# Mesh generation for voxel chunks using marching cubes algorithm
@export var angular_mode: bool = true

var marching_cubes: MarchingCubesAlgorithm

func _init():
	marching_cubes = MarchingCubesAlgorithm.new()
	marching_cubes.angular_mode = angular_mode

func generate_chunk_mesh(chunk: VoxelChunk) -> Array:
	return _generate_marching_cubes_mesh(chunk)

func _generate_marching_cubes_mesh(chunk: VoxelChunk) -> Array:
	var mesh = marching_cubes.generate_chunk_mesh(chunk)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	if mesh.get_surface_count() > 0:
		arrays = mesh.surface_get_arrays(0)
	
	return arrays
