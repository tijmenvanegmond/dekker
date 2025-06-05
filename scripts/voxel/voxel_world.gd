class_name VoxelWorld
extends Node3D

# Main voxel world manager
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
		player = camera
	
	generate_initial_chunks()

func _process(_delta):
	if player:
		var new_player_pos = player.global_position
		if new_player_pos.distance_to(player_position) > chunk_size / 2:
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

func get_chunk_at_position(world_pos: Vector3) -> VoxelChunk:
	var chunk_pos = world_to_chunk_pos(world_pos)
	return chunks.get(chunk_pos)
