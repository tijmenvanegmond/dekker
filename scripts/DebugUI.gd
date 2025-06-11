extends Control

# Debug UI for voxel world and mob system
@onready var debug_label: Label
var voxel_world: VoxelWorld
var player: Node3D
var mob_spawner: Node3D
var mob_interaction_system: Node

func _ready():
	# Create debug label
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(debug_label)
	
	# Find system references
	voxel_world = get_tree().get_first_node_in_group("voxel_world")
	if not voxel_world:
		voxel_world = get_node_or_null("/root/Main/VoxelWorld")
	
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("/root/Main/VoxelWorld/Player")
	
	mob_spawner = get_tree().get_first_node_in_group("mob_spawner")
	if not mob_spawner:
		mob_spawner = get_node_or_null("/root/Main/MobSpawner")
	
	mob_interaction_system = get_tree().get_first_node_in_group("mob_interaction_system")
	if not mob_interaction_system:
		mob_interaction_system = get_node_or_null("/root/Main/MobInteractionSystem")

func _process(_delta):
	update_debug_info()
	handle_debug_input()

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
		
		# Threading statistics
		if voxel_world.enable_threading:
			debug_text += "\n=== THREADING ===\n"
			debug_text += "Threading: ENABLED\n"
			
			if voxel_world.terrain_generator and voxel_world.terrain_generator.has_method("get_stats"):
				var terrain_stats = voxel_world.terrain_generator.get_stats()
				if terrain_stats is Dictionary and terrain_stats.has("queue_size"):
					debug_text += "Terrain Queue: " + str(terrain_stats.queue_size) + "\n"
					debug_text += "Terrain Generated: " + str(terrain_stats.get("chunks_generated", 0)) + "\n"
					var chunks_generated = terrain_stats.get("chunks_generated", 0)
					if chunks_generated > 0:
						var avg_time = terrain_stats.get("average_time_per_chunk", 0.0)
						debug_text += "Avg Terrain Time: " + str("%.3f" % avg_time) + "s\n"
				else:
					debug_text += "Terrain Stats: Invalid format\n"
			else:
				debug_text += "Terrain Generator: Not Ready\n"
			
			if voxel_world.mesh_generator and voxel_world.mesh_generator.has_method("get_debug_info"):
				var mesh_stats = voxel_world.mesh_generator.get_debug_info()
				if mesh_stats is Dictionary and mesh_stats.has("queue_size"):
					debug_text += "Mesh Queue: " + str(mesh_stats.queue_size) + "\n"
					debug_text += "Active Mesh Gen: " + str(mesh_stats.get("active_generations", 0)) + "\n"
				else:
					debug_text += "Mesh Stats: Invalid format\n"
			else:
				debug_text += "Mesh Generator: Not Ready\n"
			
			debug_text += "Waiting for Terrain: " + str(voxel_world.chunks_waiting_for_terrain.size()) + "\n"
			debug_text += "Waiting for Mesh: " + str(voxel_world.chunks_waiting_for_mesh.size()) + "\n"
		else:
			debug_text += "\n=== THREADING ===\n"
			debug_text += "Threading: DISABLED\n"
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
	
	# Mob system info
	debug_text += "\n=== MOB SYSTEM ===\n"
	if mob_spawner:
		if mob_spawner.has_method("get_mob_statistics"):
			var mob_stats = mob_spawner.get_mob_statistics()
			debug_text += "Active Mobs: " + str(mob_stats.active_mobs) + "/" + str(mob_stats.max_mobs) + "\n"
			debug_text += "Total Spawned: " + str(mob_stats.total_spawned) + "\n"
			debug_text += "Spawn Rate: " + str("%.1f" % mob_stats.spawn_rate) + "/sec\n"
		else:
			debug_text += "Active Mobs: " + str(mob_spawner.active_mobs.size()) + "/" + str(mob_spawner.max_mobs) + "\n"
		
		# Health statistics for active mobs
		if mob_spawner.active_mobs.size() > 0:
			var health_stats = calculate_mob_health_stats(mob_spawner.active_mobs)
			debug_text += "Avg Health: " + str("%.1f" % health_stats.average) + "/" + str("%.1f" % health_stats.max_possible) + "\n"
			debug_text += "Size Range: " + str("%.2f" % health_stats.min_size) + " - " + str("%.2f" % health_stats.max_size) + "\n"
			debug_text += "Healthiest: " + str("%.1f" % health_stats.highest_health) + "hp\n"
			debug_text += "Weakest: " + str("%.1f" % health_stats.lowest_health) + "hp\n"
	else:
		debug_text += "Mob Spawner: Not Found\n"
	
	if mob_interaction_system:
		if mob_interaction_system.has_method("get_interaction_statistics"):
			var interaction_stats = mob_interaction_system.get_interaction_statistics()
			debug_text += "Mob Interactions: " + ("✓" if interaction_stats.mob_to_mob_enabled else "✗") + "\n"
			debug_text += "Terrain Interactions: " + ("✓" if interaction_stats.terrain_enabled else "✗") + "\n"
			debug_text += "Player Interactions: " + ("✓" if interaction_stats.player_enabled else "✗") + "\n"
			debug_text += "Wind Effects: " + ("✓" if interaction_stats.wind_enabled else "✗") + "\n"
		else:
			debug_text += "Interaction System: Found (no stats method)\n"
	else:
		debug_text += "Interaction System: Not Found\n"

	debug_text += "\n=== DEBUG CONTROLS ===\n"
	debug_text += "Enter: Spawn Aggressive Mob\n"
	debug_text += "Space: Spawn Flock (3 mobs)\n"
	debug_text += "B: Spawn Burst (10 mobs)\n"
	debug_text += "M: Spawn MORE Mobs (20 mobs)\n"
	debug_text += "1-5: Change All Mob Behaviors\n"
	debug_text += "  1=Wander, 2=Seek, 3=Flee, 4=Flock, 5=Aggressive\n"
	debug_text += "Arrow Keys: Set Wind Direction\n"
	debug_text += "End: Create Explosion\n"
	
	debug_label.text = debug_text

func handle_debug_input():
	# Number keys for behavior changes
	if Input.is_action_just_pressed("ui_1") and mob_spawner:
		if mob_spawner.has_method("change_all_behaviors"):
			# Change to WANDER mode
			mob_spawner.change_all_behaviors(SphericalMob.BehaviorMode.WANDER)
	
	if Input.is_action_just_pressed("ui_2") and mob_spawner:
		if mob_spawner.has_method("change_all_behaviors"):
			# Change to SEEK_PLAYER mode
			mob_spawner.change_all_behaviors(SphericalMob.BehaviorMode.SEEK_PLAYER)
	
	if Input.is_action_just_pressed("ui_3") and mob_spawner:
		if mob_spawner.has_method("change_all_behaviors"):
			# Change to FLEE_PLAYER mode
			mob_spawner.change_all_behaviors(SphericalMob.BehaviorMode.FLEE_PLAYER)
	
	if Input.is_action_just_pressed("ui_4") and mob_spawner:
		if mob_spawner.has_method("change_all_behaviors"):
			# Change to FLOCK mode
			mob_spawner.change_all_behaviors(SphericalMob.BehaviorMode.FLOCK)
	
	if Input.is_action_just_pressed("ui_5") and mob_spawner:
		if mob_spawner.has_method("change_all_behaviors"):
			# Change to AGGRESSIVE mode
			mob_spawner.change_all_behaviors(SphericalMob.BehaviorMode.AGGRESSIVE)
	
	# Wind control
	if Input.is_action_just_pressed("ui_up") and mob_interaction_system:
		if mob_interaction_system.has_method("set_wind"):
			mob_interaction_system.set_wind(Vector3(0, 0, -1), 20.0)
			Logger.info("DEBUG", "Wind set to North")
	
	if Input.is_action_just_pressed("ui_down") and mob_interaction_system:
		if mob_interaction_system.has_method("set_wind"):
			mob_interaction_system.set_wind(Vector3(0, 0, 1), 20.0)
			Logger.info("DEBUG", "Wind set to South")
	
	if Input.is_action_just_pressed("ui_left") and mob_interaction_system:
		if mob_interaction_system.has_method("set_wind"):
			mob_interaction_system.set_wind(Vector3(-1, 0, 0), 20.0)
			Logger.info("DEBUG", "Wind set to West")
	
	if Input.is_action_just_pressed("ui_right") and mob_interaction_system:
		if mob_interaction_system.has_method("set_wind"):
			mob_interaction_system.set_wind(Vector3(1, 0, 0), 20.0)
			Logger.info("DEBUG", "Wind set to East")
	
	if Input.is_action_just_pressed("ui_accept") and mob_interaction_system:
		if mob_interaction_system.has_method("set_wind"):
			mob_interaction_system.set_wind(Vector3.ZERO, 0.0)
			Logger.info("DEBUG", "Wind disabled")
	
	# Mob spawning controls
	if Input.is_action_just_pressed("ui_text_backspace") and mob_spawner:  # B key
		if mob_spawner.has_method("spawn_burst"):
			mob_spawner.spawn_burst(10)
			Logger.info("DEBUG", "Spawned burst of 10 mobs")
	
	if Input.is_action_just_pressed("ui_text_newline") and mob_spawner:  # M key 
		if mob_spawner.has_method("spawn_burst"):
			mob_spawner.spawn_burst(20)
			Logger.info("DEBUG", "Spawned MASSIVE burst of 20 mobs")

func calculate_mob_health_stats(mobs: Array) -> Dictionary:
	if mobs.size() == 0:
		return {
			"average": 0.0,
			"max_possible": 0.0,
			"min_size": 0.0,
			"max_size": 0.0,
			"highest_health": 0.0,
			"lowest_health": 0.0
		}
	
	var total_health = 0.0
	var total_max_health = 0.0
	var min_size = 999.0
	var max_size = 0.0
	var highest_health = 0.0
	var lowest_health = 999.0
	
	for mob in mobs:
		if not is_instance_valid(mob) or not mob.is_alive():
			continue
			
		total_health += mob.current_health
		total_max_health += mob.max_health
		
		var mob_size = mob.mob_radius
		min_size = min(min_size, mob_size)
		max_size = max(max_size, mob_size)
		
		highest_health = max(highest_health, mob.current_health)
		lowest_health = min(lowest_health, mob.current_health)
	
	var valid_count = max(1, mobs.size())
	
	return {
		"average": total_health / valid_count,
		"max_possible": total_max_health / valid_count,
		"min_size": min_size,
		"max_size": max_size,
		"highest_health": highest_health,
		"lowest_health": lowest_health
	}
