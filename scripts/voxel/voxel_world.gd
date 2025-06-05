class_name VoxelWorld
extends Node3D

# Main voxel world manager with editing capabilities
@export var render_distance: int = 4
@export var chunk_size: int = 16

var chunks: Dictionary = {}
var player_position: Vector3
var player: Node3D

func _ready():
	# Find player node (assuming it exists)
	player = get_node_or_null("Player")
	if not player:
		# Create a simple camera for testing
		var camera = Camera3D.new()
		camera.position = Vector3(0, 10, 10)
		camera.look_at(Vector3.ZERO, Vector3.UP)
		add_child(camera)
		print("Warning: No PlayerController found, created basic camera")
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
	var chunk = preload("res://scripts/voxel/voxel_chunk.gd").new()
	chunk.chunk_position = chunk_pos
	chunk.position = Vector3(chunk_pos) * chunk_size
	chunk.name = "Chunk_" + str(chunk_pos.x) + "_" + str(chunk_pos.y) + "_" + str(chunk_pos.z)
	
	add_child(chunk)
	chunks[chunk_pos] = chunk
	
	print("Created chunk at: ", chunk_pos)

func remove_chunk(chunk_pos: Vector3i):
	if chunks.has(chunk_pos):
		var chunk = chunks[chunk_pos]
		chunks.erase(chunk_pos)
		chunk.queue_free()
		print("Removed chunk at: ", chunk_pos)

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

# Signal handlers for world editing
func _on_voxel_placed(world_pos: Vector3, voxel_type: int):
	var success = set_voxel_at_world_position(world_pos, voxel_type)
	if success:
		print("Placed voxel type ", voxel_type, " at ", world_pos)
	else:
		print("Failed to place voxel at ", world_pos)

func _on_voxel_removed(world_pos: Vector3):
	var success = set_voxel_at_world_position(world_pos, 0)  # 0 = air
	if success:
		print("Removed voxel at ", world_pos)
	else:
		print("Failed to remove voxel at ", world_pos)

func _on_edit_mode_changed(enabled: bool):
	print("World editing mode: ", "ENABLED" if enabled else "DISABLED")
	if enabled:
		print("Controls: Left Click = Place, Right Click = Remove, R = Cycle voxel type, T = Toggle edit mode")

# Debug function
func get_world_info() -> Dictionary:
	return {
		"chunk_count": chunks.size(),
		"player_position": player_position,
		"player_chunk": world_to_chunk_pos(player_position),
		"render_distance": render_distance
	}
