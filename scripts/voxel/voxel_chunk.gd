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
	
	# Generate terrain using improved noise
	for x in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			var world_x = chunk_position.x * CHUNK_SIZE + x
			var world_z = chunk_position.z * CHUNK_SIZE + z
			
			# Multi-octave noise for more interesting terrain
			var height = generate_height(world_x, world_z)
			height = clamp(height, 0, CHUNK_SIZE - 1)
			
			for y in range(int(height)):
				var world_y = chunk_position.y * CHUNK_SIZE + y
				set_voxel(x, y, z, get_voxel_type(world_x, world_y, world_z, height))
	
	# Generate mesh
	generate_mesh()

func generate_height(world_x: int, world_z: int) -> float:
	# Base height using sine waves
	var base_height = 8.0 + 4.0 * sin(world_x * 0.1) * cos(world_z * 0.1)
	
	# Add some noise for variation
	var noise1 = sin(world_x * 0.05) * cos(world_z * 0.07) * 2.0
	var noise2 = sin(world_x * 0.02 + world_z * 0.03) * 1.5
	var noise3 = sin(world_x * 0.15) * sin(world_z * 0.12) * 0.5
	
	return base_height + noise1 + noise2 + noise3

func get_voxel_type(x: int, y: int, z: int, surface_height: float) -> int:
	# More sophisticated material assignment
	var depth_from_surface = surface_height - y
	
	if depth_from_surface < 1.0:
		return 1  # Grass (top layer)
	elif depth_from_surface < 4.0:
		return 2  # Dirt (sub-surface)
	else:
		# Add some ore veins in deep stone
		var ore_noise = sin(x * 0.3) * cos(y * 0.25) * sin(z * 0.35)
		if ore_noise > 0.7:
			return 4  # Could be ore or special stone
		return 3  # Regular stone

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
		
		# Apply voxel terrain material
		var material = preload("res://materials/voxel_terrain_material.tres")
		set_surface_override_material(0, material)
		
		# Create efficient collision shape
		create_collision_shape()

func create_collision_shape():
	# Remove existing collision shape if any
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()
	
	# Create a StaticBody3D for collision
	var static_body = StaticBody3D.new()
	add_child(static_body)
	
	# Create collision shapes for solid voxel regions
	# This is more efficient than trimesh collision
	create_box_collision_shapes(static_body)

func create_box_collision_shapes(static_body: StaticBody3D):
	# Group adjacent solid voxels into larger collision boxes for better performance
	var processed = []
	processed.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	processed.fill(false)
	
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				if is_voxel_solid(x, y, z) and not processed[get_voxel_index(x, y, z)]:
					# Create a collision box for this voxel
					var collision_shape = CollisionShape3D.new()
					var box_shape = BoxShape3D.new()
					box_shape.size = Vector3(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE)
					collision_shape.shape = box_shape
					collision_shape.position = Vector3(x + 0.5, y + 0.5, z + 0.5) * VOXEL_SIZE
					static_body.add_child(collision_shape)
					
					processed[get_voxel_index(x, y, z)] = true

func get_voxel_index(x: int, y: int, z: int) -> int:
	return x + y * CHUNK_SIZE + z * CHUNK_SIZE * CHUNK_SIZE

func is_voxel_solid(x: int, y: int, z: int) -> bool:
	return get_voxel(x, y, z) > 0
