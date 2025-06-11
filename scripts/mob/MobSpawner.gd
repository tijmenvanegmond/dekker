class_name MobSpawner
extends Node3D

## Spawns and manages spherical mobs in the voxel world
## Handles mob population, respawning, and interactions

@export_group("Spawning")
@export var max_mobs: int = 25  # Increased for more dynamic gameplay
@export var spawn_radius: float = 30.0  # Good radius for exploration
@export var min_spawn_distance: float = 5.0
@export var spawn_interval: float = 2.0  # Faster spawning for quicker population
@export var auto_spawn: bool = true

@export_group("Performance Settings")
@export var update_interval: float = 0.1  # Update every 100ms instead of every frame
@export var max_interactions_per_frame: int = 8  # More interactions for larger groups
@export var distance_cull_threshold: float = 50.0  # Disable mobs beyond this distance

@export_group("Mob Configuration")
@export var mob_scene: PackedScene
@export var default_behavior: int = 0  # 0=WANDER, 1=SEEK_PLAYER, 2=FLEE_PLAYER, 3=FLOCK, 4=AGGRESSIVE
@export var mob_colors: Array[Color] = [
	Color.CYAN,
	Color.MAGENTA, 
	Color.YELLOW,
	Color.GREEN,
	Color.ORANGE
]

# Internal state
var active_mobs: Array[SphericalMob] = []
var spawn_timer: float = 0.0
var voxel_world: VoxelWorld
var player_node: Node3D

# Performance management
var performance_update_timer: float = 0.0
var performance_check_interval: float = 1.0  # Check every second

# Emergency performance settings
var emergency_mode: bool = false
var fps_threshold: float = 30.0  # Trigger emergency mode below this FPS
var fps_samples: Array[float] = []
var max_fps_samples: int = 10

# Mob statistics
var total_spawned: int = 0
var mobs_despawned: int = 0

signal mob_spawned(mob: SphericalMob)
signal mob_despawned(mob: SphericalMob)
signal mob_population_changed(count: int)

func _ready():
	# Find references
	voxel_world = get_tree().get_first_node_in_group("voxel_world")
	player_node = get_tree().get_first_node_in_group("player")
	
	# Create default mob scene if none provided
	if not mob_scene:
		mob_scene = create_default_mob_scene()
	
	# Add to groups for easy finding
	add_to_group("mob_spawner")
	
	Logger.info("MOBS", "MobSpawner initialized - max mobs: " + str(max_mobs))
	
	# Start spawning if auto-spawn is enabled (delay to let terrain generate)
	if auto_spawn:
		# Wait a few seconds for terrain to generate before spawning
		await get_tree().create_timer(3.0).timeout
		spawn_initial_mobs()

func _process(delta):
	if auto_spawn:
		spawn_timer -= delta
		
		if spawn_timer <= 0.0 and active_mobs.size() < max_mobs:
			spawn_random_mob()
			spawn_timer = spawn_interval
	
	# Performance management
	performance_update_timer += delta
	if performance_update_timer >= performance_check_interval:
		manage_mob_performance()
		performance_update_timer = 0.0
	
	# Clean up despawned mobs
	cleanup_despawned_mobs()

func create_default_mob_scene() -> PackedScene:
	# Create a basic mob scene programmatically
	var scene = PackedScene.new()
	var mob = preload("res://scripts/mob/SphericalMob.gd").new()
	
	# Pack the scene
	scene.pack(mob)
	return scene

func spawn_initial_mobs():
	@warning_ignore("integer_division")
	var initial_count = max_mobs / 2
	Logger.info("MOBS", "Spawning " + str(initial_count) + " initial mobs")
	
	for i in range(initial_count):
		spawn_random_mob()
		await get_tree().process_frame  # Spread spawning across frames

func spawn_random_mob() -> SphericalMob:
	var spawn_position = find_valid_spawn_position()
	if spawn_position == Vector3.ZERO:
		Logger.warning("MOBS", "Could not find valid spawn position")
		return null
	
	return spawn_mob_at_position(spawn_position)

func spawn_mob_at_position(spawn_pos: Vector3, behavior: int = default_behavior) -> SphericalMob:
	if active_mobs.size() >= max_mobs:
		Logger.warning("MOBS", "Cannot spawn mob - at maximum capacity")
		return null
	
	# Instantiate mob
	var mob = mob_scene.instantiate() as SphericalMob
	if not mob:
		Logger.error("MOBS", "Failed to instantiate mob from scene")
		return null
	
	# Configure mob
	mob.global_position = spawn_pos
	mob.behavior_mode = behavior
	mob.mob_color = mob_colors[randi() % mob_colors.size()]
	
	# Add health variation - higher health means larger size
	var health_variation = randf_range(50.0, 150.0)
	mob.max_health = health_variation
	mob.current_health = health_variation
	
	# Add some variation to mob properties (now based on health)
	var health_factor = health_variation / 100.0  # Normalize around 100hp as baseline
	mob.base_radius = randf_range(0.2, 0.4)  # Base size variation
	mob.max_radius = mob.base_radius * (1.5 + health_factor * 0.5)  # Scale max size with health
	mob.max_speed = randf_range(3.0, 7.0) * (2.0 - health_factor * 0.3)  # Larger mobs slightly slower
	mob.wander_radius = randf_range(8.0, 15.0)
	mob.mob_mass = health_factor * randf_range(0.8, 1.2)  # Mass scales with health
	
	# Enhanced behavior distribution for more interesting dynamics
	var behavior_chance = randf()
	if health_variation > 120.0:
		# High health mobs - more likely to be aggressive or seek player
		if behavior_chance < 0.4:
			mob.behavior_mode = SphericalMob.BehaviorMode.AGGRESSIVE
		elif behavior_chance < 0.7:
			mob.behavior_mode = SphericalMob.BehaviorMode.SEEK_PLAYER
		else:
			mob.behavior_mode = SphericalMob.BehaviorMode.FLOCK
	elif health_variation < 70.0:
		# Low health mobs - more likely to flee or flock for safety
		if behavior_chance < 0.4:
			mob.behavior_mode = SphericalMob.BehaviorMode.FLEE_PLAYER
		elif behavior_chance < 0.8:
			mob.behavior_mode = SphericalMob.BehaviorMode.FLOCK
		else:
			mob.behavior_mode = SphericalMob.BehaviorMode.WANDER
	else:
		# Medium health mobs - balanced distribution
		if behavior_chance < 0.3:
			mob.behavior_mode = SphericalMob.BehaviorMode.FLOCK
		elif behavior_chance < 0.5:
			mob.behavior_mode = SphericalMob.BehaviorMode.SEEK_PLAYER
		elif behavior_chance < 0.65:
			mob.behavior_mode = SphericalMob.BehaviorMode.FLEE_PLAYER
		elif behavior_chance < 0.8:
			mob.behavior_mode = SphericalMob.BehaviorMode.WANDER
		else:
			mob.behavior_mode = SphericalMob.BehaviorMode.AGGRESSIVE
	
	# Add to scene and tracking
	get_tree().current_scene.add_child(mob)
	active_mobs.append(mob)
	total_spawned += 1
	
	# Connect signals
	mob.tree_exiting.connect(_on_mob_despawned.bind(mob))
	
	Logger.debug("MOBS", "Spawned mob at " + str(spawn_pos) + " (total: " + str(active_mobs.size()) + ")")
	
	# Emit signals
	mob_spawned.emit(mob)
	mob_population_changed.emit(active_mobs.size())
	
	return mob

func find_valid_spawn_position() -> Vector3:
	var attempts = 20
	var player_pos = player_node.global_position if player_node else Vector3.ZERO
	
	for i in range(attempts):
		# Generate random position around player
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)
		var spawn_pos = player_pos + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		# Find ground level using voxel world
		var ground_pos = find_ground_level(spawn_pos)
		if ground_pos != Vector3.ZERO:
			return ground_pos + Vector3.UP * 2.0  # Spawn slightly above ground
	
	Logger.warning("MOBS", "Failed to find valid spawn position after " + str(attempts) + " attempts")
	return Vector3.ZERO

func find_ground_level(world_position: Vector3) -> Vector3:
	if not voxel_world:
		return world_position  # Fallback if no voxel world
	
	# Search for ground level by checking voxels downward
	var search_height = 50
	for y in range(search_height):
		var check_pos = Vector3(world_position.x, world_position.y - y, world_position.z)
		var voxel_type = voxel_world.get_voxel_at_world_position(check_pos)
		
		if voxel_type > 0:  # Found solid voxel
			return Vector3(world_position.x, check_pos.y + 1, world_position.z)
	
	return Vector3.ZERO  # No ground found

func cleanup_despawned_mobs():
	# Remove invalid references
	active_mobs = active_mobs.filter(func(mob): return is_instance_valid(mob))

func manage_mob_performance():
	# Track FPS for emergency performance mode
	var current_fps = Engine.get_frames_per_second()
	fps_samples.append(current_fps)
	if fps_samples.size() > max_fps_samples:
		fps_samples.pop_front()
	
	# Calculate average FPS
	var avg_fps = 0.0
	for fps in fps_samples:
		avg_fps += fps
	avg_fps /= fps_samples.size()
	
	# Check if we need emergency mode
	var should_emergency = avg_fps < fps_threshold
	if should_emergency != emergency_mode:
		emergency_mode = should_emergency
		Logger.info("MOBS", "Emergency performance mode: " + ("ON" if emergency_mode else "OFF") + " (FPS: %.1f)" % avg_fps)
	
	# Automatically adjust mob performance based on distance from player and emergency mode
	if not player_node:
		return
	
	var player_position = player_node.global_position
	var performance_distance = distance_cull_threshold
	
	# In emergency mode, reduce the distance threshold
	if emergency_mode:
		performance_distance *= 0.5
		
		# Also despawn some distant mobs
		if active_mobs.size() > max_mobs / 2:
			despawn_distant_mobs(performance_distance * 2)
	
	for mob in active_mobs:
		if not is_instance_valid(mob):
			continue
		
		var distance_to_player = mob.global_position.distance_to(player_position)
		
		# Set performance mode based on distance and emergency mode
		var should_low_performance = distance_to_player > performance_distance or emergency_mode
		
		if mob.has_method("set_performance_mode"):
			mob.set_performance_mode(should_low_performance)

func _on_mob_despawned(mob: SphericalMob):
	active_mobs.erase(mob)
	mobs_despawned += 1
	
	Logger.debug("MOBS", "Mob despawned (remaining: " + str(active_mobs.size()) + ")")
	
	# Emit signals
	mob_despawned.emit(mob)
	mob_population_changed.emit(active_mobs.size())

# Public interface
func spawn_aggressive_mob_near_player() -> SphericalMob:
	if not player_node:
		return null
	
	var spawn_pos = player_node.global_position + Vector3(randf_range(-5, 5), 5, randf_range(-5, 5))
	return spawn_mob_at_position(spawn_pos, SphericalMob.BehaviorMode.AGGRESSIVE)

func spawn_flock_at_position(spawn_position: Vector3, count: int = 5) -> Array[SphericalMob]:
	var flock: Array[SphericalMob] = []
	
	for i in range(count):
		var offset = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		var mob = spawn_mob_at_position(spawn_position + offset, SphericalMob.BehaviorMode.FLOCK)
		if mob:
			flock.append(mob)
	
	Logger.info("MOBS", "Spawned flock of " + str(flock.size()) + " mobs")
	return flock

func despawn_all_mobs():
	Logger.info("MOBS", "Despawning all " + str(active_mobs.size()) + " mobs")
	
	for mob in active_mobs:
		if is_instance_valid(mob):
			mob.queue_free()
	
	active_mobs.clear()
	mob_population_changed.emit(0)

func despawn_distant_mobs(max_distance: float = 100.0):
	if not player_node:
		return
	
	var player_pos = player_node.global_position
	var despawned_count = 0
	
	for mob in active_mobs.duplicate():
		if mob.global_position.distance_to(player_pos) > max_distance:
			mob.queue_free()
			despawned_count += 1
	
	if despawned_count > 0:
		Logger.debug("MOBS", "Despawned " + str(despawned_count) + " distant mobs")

func change_all_behaviors(new_behavior: SphericalMob.BehaviorMode):
	for mob in active_mobs:
		if is_instance_valid(mob):
			mob.set_behavior_mode(new_behavior)
	
	Logger.info("MOBS", "Changed behavior of all mobs to: " + SphericalMob.BehaviorMode.keys()[new_behavior])

func get_mob_statistics() -> Dictionary:
	return {
		"active_mobs": active_mobs.size(),
		"max_mobs": max_mobs,
		"total_spawned": total_spawned,
		"mobs_despawned": mobs_despawned,
		"spawn_rate": 1.0 / spawn_interval if spawn_interval > 0 else 0.0
	}

func get_mobs_by_behavior(behavior: SphericalMob.BehaviorMode) -> Array[SphericalMob]:
	return active_mobs.filter(func(mob): return mob.behavior_mode == behavior)

func apply_force_to_all_mobs(force: Vector3):
	for mob in active_mobs:
		if is_instance_valid(mob):
			mob.apply_external_force(force)
	
	Logger.debug("MOBS", "Applied force " + str(force) + " to all mobs")

# Public interface for dynamic spawning
func spawn_burst(count: int = 10) -> Array[SphericalMob]:
	"""Spawn a burst of mobs instantly around the player for testing or events"""
	var spawned_mobs: Array[SphericalMob] = []
	
	Logger.info("MOBS", "Spawning burst of " + str(count) + " mobs")
	
	for i in range(count):
		if active_mobs.size() >= max_mobs * 2:  # Allow burst to exceed normal limit temporarily
			break
			
		var mob = spawn_random_mob()
		if mob:
			spawned_mobs.append(mob)
			
		# Small delay to prevent frame drops
		if i % 3 == 0:
			await get_tree().process_frame
	
	Logger.info("MOBS", "Burst spawned " + str(spawned_mobs.size()) + " mobs")
	return spawned_mobs

func spawn_behavior_group(behavior: SphericalMob.BehaviorMode, count: int = 5) -> Array[SphericalMob]:
	"""Spawn a group of mobs with the same behavior"""
	var group: Array[SphericalMob] = []
	
	for i in range(count):
		if active_mobs.size() >= max_mobs * 2:
			break
			
		var spawn_pos = find_valid_spawn_position()
		if spawn_pos != Vector3.ZERO:
			var mob = spawn_mob_at_position(spawn_pos, behavior)
			if mob:
				group.append(mob)
	
	Logger.info("MOBS", "Spawned " + str(group.size()) + " " + SphericalMob.BehaviorMode.keys()[behavior] + " mobs")
	return group

# Debug visualization
func _draw_debug_info():
	if not Engine.is_editor_hint():
		return
	
	# This would be called from a debug overlay
	# Implementation would depend on your debug system
