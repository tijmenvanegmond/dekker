extends Control

# Debug UI for voxel world
@onready var debug_label: Label
var voxel_world: VoxelWorld
var player: Node3D

func _ready():
	# Create debug label
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(debug_label)
	
	# Find voxel world and player
	voxel_world = get_tree().get_first_node_in_group("voxel_world")
	if not voxel_world:
		voxel_world = get_node_or_null("/root/Main/VoxelWorld")
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/Main/VoxelWorld/Player")

func _process(_delta):
	update_debug_info()

func update_debug_info():
	var debug_text = "=== VOXEL WORLD DEBUG ===\n"
	
	# Player info
	if player:
		debug_text += "Player Position: " + str(player.global_position.round()) + "\n"
		debug_text += "Velocity: " + str(Vector3(player.velocity.x, player.velocity.y, player.velocity.z).round()) + "\n"
		debug_text += "On Floor: " + str(player.is_on_floor()) + "\n"
		
		# Edit mode info (if player is PlayerController)
		if player.has_method("get_debug_info"):
			var player_debug = player.get_debug_info()
			if player_debug.has("edit_mode"):
				debug_text += "Edit Mode: " + str(player_debug.edit_mode) + "\n"
				if player_debug.edit_mode:
					debug_text += "Voxel Type: " + str(player_debug.voxel_type) + "\n"
			
			# Action system info
			if player_debug.has("movement_input"):
				debug_text += "Movement Input: " + str(player_debug.movement_input.round()) + "\n"
			
			if player_debug.has("action_system"):
				debug_text += "\n=== ACTION SYSTEM ===\n"
				debug_text += player_debug.action_system + "\n"
				debug_text += "WASD Movement: Active\n"
				debug_text += "Jump: " + ("✓" if Input.is_action_pressed("jump") else "○") + "\n"
				debug_text += "Edit Mode: " + ("✓" if player_debug.edit_mode else "○") + "\n"
			elif player_debug.has("actions"):
				debug_text += "\n=== ACTION SYSTEM ===\n"
				var actions = player_debug.actions
				if actions.size() > 0:
					for action_info in actions:
						var status = "✓" if action_info.enabled else "✗"
						debug_text += status + " " + action_info.name + " (" + action_info.input + ")\n"
				else:
					debug_text += "No actions loaded\n"
	else:
		debug_text += "Player: Not Found\n"
	
	# World info
	if voxel_world:
		if voxel_world.has_method("get_world_info"):
			var world_info = voxel_world.get_world_info()
			debug_text += "Chunks Loaded: " + str(world_info.chunk_count) + "\n"
			debug_text += "Player Chunk: " + str(world_info.player_chunk) + "\n"
			debug_text += "Render Distance: " + str(world_info.render_distance) + "\n"
		else:
			debug_text += "Chunks: " + str(voxel_world.chunks.size()) + "\n"
	else:
		debug_text += "World: Not Found\n"
	
	# Controls
	debug_text += "\n=== CONTROLS ===\n"
	debug_text += "WASD: Move\n"
	debug_text += "Space: Jump\n"
	debug_text += "Mouse: Look\n"
	debug_text += "Esc: Release cursor\n"
	debug_text += "T: Toggle edit mode\n"
	debug_text += "R: Cycle voxel type\n"
	debug_text += "Left Click: Place voxel\n"
	debug_text += "Right Click: Remove voxel\n"
	
	# Performance
	debug_text += "\n=== PERFORMANCE ===\n"
	debug_text += "FPS: " + str(Engine.get_frames_per_second()) + "\n"
	
	debug_label.text = debug_text
