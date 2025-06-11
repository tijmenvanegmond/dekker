class_name VoxelWorld
extends Node3D

# Main voxel world manager with editing capabilities
@export var render_distance: int = 4
@export var chunk_size: int = 16
@export var enable_threading: bool = true

# Logging
var logger: VoxelLogger

var chunks: Dictionary = {}
var player_position: Vector3
var player: Node3D

# Threaded generation systems (preloaded for proper type recognition)
var terrain_generator: RefCounted  # ThreadedTerrainGenerator
var mesh_generator: RefCounted     # ThreadedMeshGenerator

# Performance tracking
var chunks_waiting_for_terrain: Dictionary = {}
var chunks_waiting_for_mesh: Dictionary = {}

var chunk_check_timer: Timer

func _ready():
	# Initialize logging
	logger = VoxelLogger.get_instance()
	VoxelLogger.set_console_level(VoxelLogger.LogLevel.INFO)  # Only show INFO and above in console
	
	# Initialize threaded generation systems
	if enable_threading:
		terrain_generator = preload("res://scripts/voxel/threaded_terrain_generator.gd").new()
		mesh_generator = preload("res://scripts/voxel/threaded_mesh_generator.gd").new()
		
		# Connect signals
		terrain_generator.terrain_generated.connect(_on_terrain_generated)
		mesh_generator.mesh_generated.connect(_on_mesh_generated)
		
		VoxelLogger.info("WORLD", "Threaded generation enabled")
	else:
		VoxelLogger.info("WORLD", "Using synchronous generation")
	
	# Create timer for periodic chunk checking
	chunk_check_timer = Timer.new()
	chunk_check_timer.wait_time = 1.0  # Check every second
	chunk_check_timer.timeout.connect(_periodic_chunk_check)
	chunk_check_timer.autostart = true
	add_child(chunk_check_timer)
	
	# Find player node (assuming it exists)
	player = get_node_or_null("Player")
	if not player:
		# Create a simple camera for testing
		var camera = Camera3D.new()
		camera.position = Vector3(0, 10, 10)
		camera.look_at(Vector3.ZERO, Vector3.UP)
		add_child(camera)
		VoxelLogger.warning("WORLD", "No PlayerController found, created basic camera")
	else:
		# Connect to player signals for world editing
		if player.has_signal("voxel_placed"):
			player.voxel_placed.connect(_on_voxel_placed)
		if player.has_signal("voxel_removed"):
			player.voxel_removed.connect(_on_voxel_removed)
		if player.has_signal("edit_mode_changed"):
			player.edit_mode_changed.connect(_on_edit_mode_changed)
	
	generate_initial_chunks()

func _process(_delta):
	if player:
		var new_player_pos = player.global_position
		if new_player_pos.distance_to(player_position) > float(chunk_size) / 2.0:
			player_position = new_player_pos
			update_chunks()

func _exit_tree():
	# Cleanup threaded systems
	if terrain_generator:
		terrain_generator.shutdown()
	if mesh_generator:
		mesh_generator.shutdown()
	VoxelLogger.info("WORLD", "Cleanup completed")
	VoxelLogger.close_log()

func generate_initial_chunks():
	player_position = player.global_position if player else Vector3.ZERO
	update_chunks()

func update_chunks():
	var player_chunk = world_to_chunk_pos(player_position)
	
	# Generate new chunks around player
	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.z - render_distance, player_chunk.z + render_distance + 1):
			var chunk_pos = Vector3i(x, 0, z)
			if not chunks.has(chunk_pos):
				create_chunk(chunk_pos)
	
	# Remove distant chunks
	var chunks_to_remove = []
	for chunk_pos in chunks:
		var distance = Vector2(chunk_pos.x - player_chunk.x, chunk_pos.z - player_chunk.z).length()
		if distance > render_distance + 1:
			chunks_to_remove.append(chunk_pos)
	
	for chunk_pos in chunks_to_remove:
		remove_chunk(chunk_pos)

func create_chunk(chunk_pos: Vector3i):
	# Create chunk object but don't generate terrain yet
	var chunk = preload("res://scripts/voxel/voxel_chunk.gd").new()
	chunk.chunk_position = chunk_pos
	chunk.position = Vector3(chunk_pos) * chunk_size
	chunk.name = "Chunk_" + str(chunk_pos.x) + "_" + str(chunk_pos.y) + "_" + str(chunk_pos.z)
	
	# Set timing info for stuck chunk detection
	chunk.set_meta("creation_time", Time.get_ticks_msec())
	
	# Disable auto-generation since we'll handle it with threading
	chunk.auto_generate = false
	
	add_child(chunk)
	chunks[chunk_pos] = chunk
	
	if enable_threading and terrain_generator:
		# Queue terrain generation with priority based on distance to player
		var distance = Vector2(chunk_pos.x - player_position.x / chunk_size, chunk_pos.z - player_position.z / chunk_size).length()
		var priority = max(0, 100 - int(distance * 10))
		
		terrain_generator.queue_terrain_generation(chunk_pos, priority)
		chunks_waiting_for_terrain[chunk_pos] = chunk
		VoxelLogger.debug("WORLD", "Queued terrain generation for chunk: " + str(chunk_pos) + " (priority: " + str(priority) + ")")
	else:
		# Fallback to synchronous generation
		chunk.auto_generate = true
		chunk.generate_chunk()
		# After adding this chunk, try to generate meshes for chunks that might now be ready
		call_deferred("_try_generate_pending_meshes")
		# Also regenerate neighbor meshes to fix seams
		call_deferred("_regenerate_neighbor_meshes", chunk_pos)
	
	VoxelLogger.debug("WORLD", "Created chunk at: " + str(chunk_pos))

func remove_chunk(chunk_pos: Vector3i):
	if chunks.has(chunk_pos):
		var chunk = chunks[chunk_pos]
		chunks.erase(chunk_pos)
		chunk.queue_free()
		VoxelLogger.debug("WORLD", "Removed chunk at: " + str(chunk_pos))

func world_to_chunk_pos(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(world_pos.x / chunk_size)),
		0,
		int(floor(world_pos.z / chunk_size))
	)

func world_to_voxel_pos(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(world_pos.x)),
		int(floor(world_pos.y)),
		int(floor(world_pos.z))
	)

func get_chunk_at_position(world_pos: Vector3) -> VoxelChunk:
	var chunk_pos = world_to_chunk_pos(world_pos)
	return chunks.get(chunk_pos)

func get_voxel_at_world_position(world_pos: Vector3) -> int:
	var chunk = get_chunk_at_position(world_pos)
	if not chunk:
		return 0
	
	var voxel_pos = world_to_voxel_pos(world_pos)
	var chunk_local_pos = voxel_pos - Vector3i(chunk.chunk_position * chunk_size)
	
	return chunk.get_voxel(chunk_local_pos.x, chunk_local_pos.y, chunk_local_pos.z)

func set_voxel_at_world_position(world_pos: Vector3, voxel_type: int) -> bool:
	var chunk = get_chunk_at_position(world_pos)
	if not chunk:
		return false
	
	var voxel_pos = world_to_voxel_pos(world_pos)
	var chunk_local_pos = voxel_pos - Vector3i(chunk.chunk_position * chunk_size)
	
	# Check bounds
	if (chunk_local_pos.x < 0 or chunk_local_pos.x >= chunk_size or
		chunk_local_pos.y < 0 or chunk_local_pos.y >= chunk_size or
		chunk_local_pos.z < 0 or chunk_local_pos.z >= chunk_size):
		return false
	
	chunk.set_voxel(chunk_local_pos.x, chunk_local_pos.y, chunk_local_pos.z, voxel_type)
	chunk.generate_mesh()
	
	# Also update adjacent chunks if voxel is on the edge
	update_adjacent_chunks_if_needed(world_pos, chunk_local_pos)
	
	return true

func update_adjacent_chunks_if_needed(world_pos: Vector3, local_pos: Vector3i):
	# If voxel is on chunk boundary, update adjacent chunks
	var chunk_pos = world_to_chunk_pos(world_pos)
	
	# Check each axis
	if local_pos.x == 0:
		update_chunk_mesh(Vector3i(chunk_pos.x - 1, chunk_pos.y, chunk_pos.z))
	elif local_pos.x == chunk_size - 1:
		update_chunk_mesh(Vector3i(chunk_pos.x + 1, chunk_pos.y, chunk_pos.z))
	
	if local_pos.y == 0:
		update_chunk_mesh(Vector3i(chunk_pos.x, chunk_pos.y - 1, chunk_pos.z))
	elif local_pos.y == chunk_size - 1:
		update_chunk_mesh(Vector3i(chunk_pos.x, chunk_pos.y + 1, chunk_pos.z))
	
	if local_pos.z == 0:
		update_chunk_mesh(Vector3i(chunk_pos.x, chunk_pos.y, chunk_pos.z - 1))
	elif local_pos.z == chunk_size - 1:
		update_chunk_mesh(Vector3i(chunk_pos.x, chunk_pos.y, chunk_pos.z + 1))

func update_chunk_mesh(chunk_pos: Vector3i):
	if chunks.has(chunk_pos):
		var chunk = chunks[chunk_pos] as VoxelChunk
		chunk.generate_mesh()

# Get voxel at world position (for chunk boundary sampling)
func get_voxel_world_pos(world_x: int, world_y: int, world_z: int) -> int:
	var chunk_pos = Vector3i(
		floori(float(world_x) / chunk_size),
		floori(float(world_y) / chunk_size),
		floori(float(world_z) / chunk_size)
	)
	
	if chunks.has(chunk_pos):
		var local_x = world_x - chunk_pos.x * chunk_size
		var local_y = world_y - chunk_pos.y * chunk_size
		var local_z = world_z - chunk_pos.z * chunk_size
		return chunks[chunk_pos].get_voxel(local_x, local_y, local_z)
	
	# If chunk doesn't exist, generate theoretical voxel value
	return _generate_theoretical_voxel(world_x, world_y, world_z)

# Generate theoretical voxel value for unloaded chunks
func _generate_theoretical_voxel(world_x: int, world_y: int, world_z: int) -> int:
	# Use the same height generation logic as VoxelChunk
	var height = _generate_theoretical_height(world_x, world_z)
	
	if world_y < height:
		var depth_from_surface = height - world_y
		if depth_from_surface < 1.0:
			return 1  # Grass
		elif depth_from_surface < 4.0:
			return 2  # Dirt
		else:
			var ore_noise = sin(world_x * 0.3) * cos(world_y * 0.25) * sin(world_z * 0.35)
			if ore_noise > 0.7:
				return 4  # Ore
			return 3  # Stone
	
	return 0  # Air

func _generate_theoretical_height(world_x: int, world_z: int) -> float:
	# Same height generation as VoxelChunk.generate_height()
	var base_height = 8.0 + 4.0 * sin(world_x * 0.1) * cos(world_z * 0.1)
	var noise1 = sin(world_x * 0.05) * cos(world_z * 0.07) * 2.0
	var noise2 = sin(world_x * 0.02 + world_z * 0.03) * 1.5
	var noise3 = sin(world_x * 0.15) * sin(world_z * 0.12) * 0.5
	
	return base_height + noise1 + noise2 + noise3

# Signal handlers for world editing
func _on_voxel_placed(world_pos: Vector3, voxel_type: int):
	var success = set_voxel_at_world_position(world_pos, voxel_type)
	if success:
		VoxelLogger.info("EDIT", "Placed voxel type " + str(voxel_type) + " at " + str(world_pos))
	else:
		VoxelLogger.warning("EDIT", "Failed to place voxel at " + str(world_pos))

func _on_voxel_removed(world_pos: Vector3):
	var success = set_voxel_at_world_position(world_pos, 0)  # 0 = air
	if success:
		VoxelLogger.info("EDIT", "Removed voxel at " + str(world_pos))
	else:
		VoxelLogger.warning("EDIT", "Failed to remove voxel at " + str(world_pos))

func _on_edit_mode_changed(enabled: bool):
	VoxelLogger.info("EDIT", "World editing mode: " + ("ENABLED" if enabled else "DISABLED"))
	if enabled:
		VoxelLogger.info("EDIT", "Controls: Left Click = Place, Right Click = Remove, R = Cycle voxel type, T = Toggle edit mode")

# Get neighbor chunk for boundary checking
func get_neighbor_chunk(chunk_pos: Vector3i) -> VoxelChunk:
	if chunks.has(chunk_pos):
		return chunks[chunk_pos]
	return null

# Try to generate meshes for chunks that might now be ready
func _try_generate_pending_meshes():
	for chunk_pos in chunks:
		var chunk = chunks[chunk_pos]
		if chunk and not chunk.mesh_ready and chunk.voxel_data_ready:
			if enable_threading and mesh_generator:
				# Queue for threaded mesh generation
				_queue_mesh_generation(chunk_pos, chunk)
			else:
				# Fallback to synchronous mesh generation
				chunk.try_generate_mesh()
	
	# Also check for chunks that have been waiting too long and force generation
	_check_for_stuck_chunks()

# Signal handlers for threaded generation
func _on_terrain_generated(chunk_pos: Vector3i, voxel_data: Array[int]):
	if not chunks.has(chunk_pos):
		VoxelLogger.warning("WORLD", "Terrain generated for non-existent chunk: " + str(chunk_pos))
		return
	
	var chunk = chunks[chunk_pos]
	chunk.set_voxel_data(voxel_data)
	chunks_waiting_for_terrain.erase(chunk_pos)
	
	VoxelLogger.debug("WORLD", "Terrain generated for chunk: " + str(chunk_pos))
	
	# Now queue mesh generation
	_queue_mesh_generation(chunk_pos, chunk)
	
	# Regenerate meshes for neighboring chunks to fix seams
	_regenerate_neighbor_meshes(chunk_pos)

func _on_mesh_generated(chunk_pos: Vector3i, mesh_arrays: Array):
	if not chunks.has(chunk_pos):
		VoxelLogger.warning("WORLD", "Mesh generated for non-existent chunk: " + str(chunk_pos))
		return
	
	var chunk = chunks[chunk_pos]
	chunk.set_mesh_arrays(mesh_arrays)
	chunks_waiting_for_mesh.erase(chunk_pos)
	
	VoxelLogger.debug("WORLD", "Mesh generated for chunk: " + str(chunk_pos))

func _queue_mesh_generation(chunk_pos: Vector3i, chunk: VoxelChunk):
	if not chunk.can_generate_mesh():
		# Can't generate mesh yet, neighbors aren't ready
		VoxelLogger.debug("WORLD", "Cannot generate mesh for chunk " + str(chunk_pos) + " - waiting for dependencies")
		return
	
	# Check if already generating or waiting
	if chunks_waiting_for_mesh.has(chunk_pos):
		VoxelLogger.debug("WORLD", "Chunk " + str(chunk_pos) + " already waiting for mesh generation")
		return
	
	var distance = Vector2(chunk_pos.x - player_position.x / chunk_size, chunk_pos.z - player_position.z / chunk_size).length()
	var priority = max(0, 100 - int(distance * 10))
	
	# Set timing info for stuck chunk detection
	chunk.set_meta("mesh_queue_time", Time.get_ticks_msec())
	
	mesh_generator.queue_mesh_generation(chunk_pos, chunk.voxel_data, chunk, priority)
	chunks_waiting_for_mesh[chunk_pos] = chunk
	VoxelLogger.debug("WORLD", "Queued mesh generation for chunk: " + str(chunk_pos) + " (priority: " + str(priority) + ")")

# Method for chunks to request threaded mesh generation
func request_threaded_mesh_generation(chunk_pos: Vector3i):
	if not chunks.has(chunk_pos):
		VoxelLogger.warning("WORLD", "Request for mesh generation of non-existent chunk: " + str(chunk_pos))
		return
	
	var chunk = chunks[chunk_pos]
	if enable_threading and mesh_generator:
		VoxelLogger.debug("WORLD", "Queuing threaded mesh generation for chunk: " + str(chunk_pos))
		_queue_mesh_generation(chunk_pos, chunk)
	else:
		VoxelLogger.warning("WORLD", "Threaded mesh generation not available for chunk: " + str(chunk_pos))

# Check for chunks that have been waiting too long and force generation
func _check_for_stuck_chunks():
	var current_time = Time.get_ticks_msec()
	var stuck_chunks = []
	
	# Check terrain generation timeouts
	for chunk_pos in chunks_waiting_for_terrain:
		var chunk = chunks_waiting_for_terrain[chunk_pos]
		if chunk and not chunk.voxel_data_ready:
			# Force synchronous generation for stuck chunks after 5 seconds
			if current_time - chunk.get("creation_time", 0) > 5000:
				VoxelLogger.warning("WORLD", "Forcing synchronous terrain generation for stuck chunk: " + str(chunk_pos))
				chunk.auto_generate = true
				chunk.generate_chunk()
				stuck_chunks.append(chunk_pos)
	
	# Remove stuck chunks from waiting list
	for chunk_pos in stuck_chunks:
		chunks_waiting_for_terrain.erase(chunk_pos)
	
	stuck_chunks.clear()
	
	# Check mesh generation timeouts
	for chunk_pos in chunks_waiting_for_mesh:
		var chunk = chunks_waiting_for_mesh[chunk_pos]
		if chunk and chunk.voxel_data_ready and not chunk.mesh_ready:
			# Force synchronous generation for stuck chunks after 3 seconds
			if current_time - chunk.get("mesh_queue_time", 0) > 3000:
				VoxelLogger.warning("WORLD", "Forcing synchronous mesh generation for stuck chunk: " + str(chunk_pos))
				chunk.try_generate_mesh()
				stuck_chunks.append(chunk_pos)
	
	# Remove stuck chunks from waiting list
	for chunk_pos in stuck_chunks:
		chunks_waiting_for_mesh.erase(chunk_pos)

# Force generation for chunks that have been waiting too long
func _force_generate_stuck_chunks():
	var current_time = Time.get_ticks_msec()
	var forced_chunks = []
	
	# Check all chunks without voxel data and force generation if needed
	for chunk_pos in chunks:
		var chunk = chunks[chunk_pos]
		if chunk and not chunk.voxel_data_ready:
			# Force generation for chunks that have been waiting more than 2 seconds
			if current_time - chunk.get_meta("creation_time", 0) > 2000:
				VoxelLogger.warning("WORLD", "Force generating terrain for slow chunk: " + str(chunk_pos))
				chunk.auto_generate = true
				chunk.generate_chunk()
				forced_chunks.append(chunk_pos)
	
	# Remove forced chunks from waiting lists
	for chunk_pos in forced_chunks:
		chunks_waiting_for_terrain.erase(chunk_pos)
	
	forced_chunks.clear()
	
	# Check all chunks with data but no mesh and force generation if needed
	for chunk_pos in chunks:
		var chunk = chunks[chunk_pos]
		if chunk and chunk.voxel_data_ready and not chunk.mesh_ready:
			# Force mesh generation for chunks that have been waiting more than 1 second
			var mesh_queue_time = chunk.get_meta("mesh_queue_time", chunk.get_meta("creation_time", 0))
			if current_time - mesh_queue_time > 1000:
				VoxelLogger.warning("WORLD", "Force generating mesh for slow chunk: " + str(chunk_pos))
				chunk.try_generate_mesh()
				forced_chunks.append(chunk_pos)
	
	# Remove forced chunks from waiting lists
	for chunk_pos in forced_chunks:
		chunks_waiting_for_mesh.erase(chunk_pos)

func _periodic_chunk_check():
	# Debugging: Check chunk loading status periodically
	var total_chunks = chunks.size()
	var chunks_with_data = 0
	var chunks_with_mesh = 0
	var chunks_waiting_terrain = chunks_waiting_for_terrain.size()
	var chunks_waiting_mesh = chunks_waiting_for_mesh.size()
	
	for chunk_pos in chunks:
		var chunk = chunks[chunk_pos]
		if chunk:
			if chunk.voxel_data_ready:
				chunks_with_data += 1
			if chunk.mesh_ready:
				chunks_with_mesh += 1
	
	# Log detailed status to file, show summary in console if there are issues
	VoxelLogger.debug("WORLD", "Chunk Status: " + str(total_chunks) + " total, " + str(chunks_with_data) + " with data, " + str(chunks_with_mesh) + " with mesh")
	VoxelLogger.debug("WORLD", "Waiting: " + str(chunks_waiting_terrain) + " for terrain, " + str(chunks_waiting_mesh) + " for mesh")
	
	# Show warning in console if chunks are stuck
	if chunks_waiting_terrain > 0 or chunks_waiting_mesh > 0:
		VoxelLogger.info("WORLD", "Processing chunks: " + str(chunks_waiting_terrain) + " terrain, " + str(chunks_waiting_mesh) + " mesh pending")
	
	# Try to generate meshes for chunks that might be ready
	_try_generate_pending_meshes()
	
	# Force generation for chunks that have been waiting too long
	_force_generate_stuck_chunks()

# Regenerate meshes for neighboring chunks to fix seams
func _regenerate_neighbor_meshes(chunk_pos: Vector3i):
	# List of all 26 neighboring positions (including diagonals)
	# For voxel terrain, we primarily care about the 6 face neighbors
	var neighbor_offsets = [
		Vector3i(-1, 0, 0), Vector3i(1, 0, 0),    # X neighbors
		Vector3i(0, -1, 0), Vector3i(0, 1, 0),    # Y neighbors  
		Vector3i(0, 0, -1), Vector3i(0, 0, 1)     # Z neighbors
	]
	
	for offset in neighbor_offsets:
		var neighbor_pos = chunk_pos + offset
		if chunks.has(neighbor_pos):
			var neighbor_chunk = chunks[neighbor_pos]
			if neighbor_chunk and neighbor_chunk.mesh_ready and neighbor_chunk.voxel_data_ready:
				# Regenerate mesh for this neighbor to account for new boundary conditions
				VoxelLogger.debug("WORLD", "Regenerating mesh for neighbor chunk: " + str(neighbor_pos) + " due to new chunk: " + str(chunk_pos))
				
				if enable_threading and mesh_generator:
					# Use threaded mesh generation
					_queue_mesh_generation(neighbor_pos, neighbor_chunk)
				else:
					# Use synchronous mesh generation
					neighbor_chunk.try_generate_mesh()
