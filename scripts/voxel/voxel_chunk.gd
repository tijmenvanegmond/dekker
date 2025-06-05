class_name VoxelChunk
extends MeshInstance3D

# Voxel chunk management class
const CHUNK_SIZE = 16
const VOXEL_SIZE = 1.0

@export var chunk_position: Vector3i
@export var auto_generate: bool = true

var voxel_data: Array[int] = []
var mesh_generator: VoxelMeshGenerator

func _ready():
	mesh_generator = VoxelMeshGenerator.new()
	if auto_generate:
		generate_chunk()

func generate_chunk():
	# Initialize voxel data array
	voxel_data.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	voxel_data.fill(0)
	
	# Generate terrain using simple noise
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var world_x = chunk_position.x * CHUNK_SIZE + x
			var world_z = chunk_position.z * CHUNK_SIZE + z
			
			# Simple height generation
			var height = int(8 + 4 * sin(world_x * 0.1) * cos(world_z * 0.1))
			height = clamp(height, 0, CHUNK_SIZE - 1)
			
			for y in range(height):
				var world_y = chunk_position.y * CHUNK_SIZE + y
				set_voxel(x, y, z, get_voxel_type(world_x, world_y, world_z))
	
	# Generate mesh
	generate_mesh()

func get_voxel_type(x: int, y: int, z: int) -> int:
	# Simple material assignment based on height
	if y < 2:
		return 3  # Stone
	elif y < 5:
		return 2  # Dirt
	else:
		return 1  # Grass

func set_voxel(x: int, y: int, z: int, voxel_type: int):
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return
	
	var index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
	voxel_data[index] = voxel_type

func get_voxel(x: int, y: int, z: int) -> int:
	if x < 0 or x >= CHUNK_SIZE or y < 0 or y >= CHUNK_SIZE or z < 0 or z >= CHUNK_SIZE:
		return 0
	
	var index = x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE
	return voxel_data[index]

func generate_mesh():
	var arrays = mesh_generator.generate_chunk_mesh(self)
	
	if arrays.size() > 0:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh = array_mesh
		
		# Create collision shape
		create_trimesh_collision()

func is_voxel_solid(x: int, y: int, z: int) -> bool:
	return get_voxel(x, y, z) > 0
