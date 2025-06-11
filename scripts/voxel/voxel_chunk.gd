class_name VoxelChunk
extends MeshInstance3D

# Voxel chunk management class
const CHUNK_SIZE = 16
const VOXEL_SIZE = 1.0

@export var chunk_position: Vector3i
@export var auto_generate: bool = true

var voxel_data: Array[int] = []
var mesh_generator: VoxelMeshGenerator

# Track when chunk was last generated to prevent excessive regeneration
var last_mesh_generation_time: float = 0.0
var is_generating_mesh: bool = false  # Prevent recursion
var voxel_data_ready: bool = false  # Track if voxel data is generated
var mesh_ready: bool = false  # Track if mesh is generated

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
	
	# Mark voxel data as ready
	voxel_data_ready = true
	
	# Try to generate mesh (will only succeed if neighbors are ready)
	try_generate_mesh()

func generate_height(world_x: int, world_z: int) -> float:
	# Base height using sine waves
	var base_height = 8.0 + 4.0 * sin(world_x * 0.1) * cos(world_z * 0.1)
	
	# Add some noise for variation
	var noise1 = sin(world_x * 0.05) * cos(world_z * 0.07) * 2.0
	var noise2 = sin(world_x * 0.02 + world_z * 0.03) * 1.5
	var noise3 = sin(world_x * 0.15) * sin(world_z * 0.12) * 0.5
	
	return base_height + noise1 + noise2 + noise3

func get_voxel_type(world_x: int, world_y: int, world_z: int, surface_height: float) -> int:
	# More sophisticated material assignment
	var depth_from_surface = surface_height - world_y
	
	if depth_from_surface < 1.0:
		return 1  # Grass (top layer)
	elif depth_from_surface < 4.0:
		return 2  # Dirt (sub-surface)
	else:
		# Add some ore veins in deep stone - use world coordinates for consistency
		var ore_noise = sin(world_x * 0.3) * cos(world_y * 0.25) * sin(world_z * 0.35)
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
	if index < 0 or index >= voxel_data.size():
		return 0
	
	return voxel_data[index]

func get_voxel_safe(x: int, y: int, z: int) -> int:
	# Safe voxel access with bounds checking and neighbor chunk sampling
	if x >= 0 and x < CHUNK_SIZE and y >= 0 and y < CHUNK_SIZE and z >= 0 and z < CHUNK_SIZE:
		return get_voxel(x, y, z)
	
	# For out-of-bounds access, try to get from neighboring chunk
	if get_parent() and get_parent().has_method("get_voxel_world_pos"):
		var world_x = chunk_position.x * CHUNK_SIZE + x
		var world_y = chunk_position.y * CHUNK_SIZE + y
		var world_z = chunk_position.z * CHUNK_SIZE + z
		return get_parent().get_voxel_world_pos(world_x, world_y, world_z)
	
	return 0  # Return air/empty if no neighbor available

func generate_mesh():
	# Prevent infinite recursion
	if is_generating_mesh:
		return
	
	# Prevent excessive mesh regeneration
	var current_time = Time.get_ticks_msec() / 1000.0  # Use more reliable timing
	if current_time - last_mesh_generation_time < 0.1:  # Minimum 100ms between regenerations
		return
	
	is_generating_mesh = true
	last_mesh_generation_time = current_time
	
	# Use threaded mesh generation if available
	var world = get_parent()
	if world and world.has_method("request_threaded_mesh_generation") and world.enable_threading:
		Logger.debug("CHUNK", "Chunk " + str(chunk_position) + " requesting threaded mesh generation")
		world.request_threaded_mesh_generation(chunk_position)
		is_generating_mesh = false
		return
	
	# Fallback to synchronous generation
	Logger.debug("CHUNK", "Chunk " + str(chunk_position) + " using synchronous mesh generation")
	var arrays = mesh_generator.generate_chunk_mesh(self)
	
	if arrays.size() > 0 and arrays[Mesh.ARRAY_VERTEX] != null and arrays[Mesh.ARRAY_VERTEX].size() > 0:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh = array_mesh
		
		# Apply voxel terrain material
		var material = preload("res://materials/voxel_terrain_material.tres")
		set_surface_override_material(0, material)
		
		# Create efficient collision shape
		create_collision_shape()
		
		# Mark mesh as ready
		mesh_ready = true
		Logger.debug("CHUNK", "Chunk " + str(chunk_position) + " mesh generated successfully with " + str(arrays[Mesh.ARRAY_VERTEX].size()) + " vertices")
	else:
		Logger.debug("CHUNK", "Chunk " + str(chunk_position) + " generated empty mesh arrays - no visible terrain")
	
	is_generating_mesh = false

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

# Try to generate mesh as soon as our voxel data is ready
func try_generate_mesh():
	if mesh_ready:
		return  # Already have mesh
		
	if not voxel_data_ready:
		return  # Our own voxel data not ready yet
	
	Logger.debug("CHUNK", "Chunk " + str(chunk_position) + " generating mesh - voxel data ready")
	# Generate mesh immediately when voxel data is ready
	generate_mesh()

# Methods for threaded generation support
func set_voxel_data(new_voxel_data: Array[int]):
	"""Set voxel data from threaded terrain generation"""
	voxel_data = new_voxel_data.duplicate()
	voxel_data_ready = true
	Logger.debug("CHUNK", "Chunk " + str(chunk_position) + " received voxel data from threaded generation, voxel_data_ready=" + str(voxel_data_ready))
	# Try to generate mesh now that we have voxel data
	try_generate_mesh()

func set_mesh_arrays(mesh_arrays: Array):
	"""Set mesh from threaded mesh generation"""
	if mesh_arrays.size() > 0:
		var array_mesh = ArrayMesh.new()
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
		mesh = array_mesh
		
		# Apply voxel terrain material
		var material = preload("res://materials/voxel_terrain_material.tres")
		set_surface_override_material(0, material)
		
		# Create efficient collision shape
		create_collision_shape()
		
		# Mark mesh as ready
		mesh_ready = true
		Logger.debug("CHUNK", "Chunk " + str(chunk_position) + " received mesh from threaded generation")
	else:
		Logger.warning("CHUNK", "Chunk " + str(chunk_position) + " received empty mesh arrays")

func can_generate_mesh() -> bool:
	"""Check if this chunk can generate a mesh (has data and neighbors are ready)"""
	# Only require own voxel data to be ready - neighbors can use fallback values
	return voxel_data_ready

func get_voxel_data_copy() -> Array[int]:
	"""Get a copy of voxel data for threaded mesh generation"""
	return voxel_data.duplicate()
