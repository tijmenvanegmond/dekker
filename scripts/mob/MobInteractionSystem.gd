class_name MobInteractionSystem
extends Node

## Handles interactions between mobs, terrain, and player
## Manages mob behaviors and environmental effects

@export_group("Interaction Settings")
@export var enable_mob_to_mob_interaction: bool = true
@export var enable_terrain_interaction: bool = true
@export var enable_player_interaction: bool = true
@export var interaction_force_multiplier: float = 1.0

@export_group("Environmental Effects")
@export var wind_enabled: bool = false
@export var wind_direction: Vector3 = Vector3(1, 0, 0)
@export var wind_strength: float = 10.0
@export var gravity_modifier: float = 1.0

@export_group("Performance Settings")
@export var interaction_update_interval: float = 0.15  # Update every 150ms
@export var max_mob_interactions_per_frame: int = 3  # Limit interactions per frame
@export var interaction_distance_threshold: float = 15.0  # Only check nearby mobs
@export var enable_distance_culling: bool = true  # Skip distant mobs

# References
var mob_spawner: MobSpawner
var voxel_world: VoxelWorld
var player_node: Node3D

# Interaction tracking
var active_interactions: Dictionary = {}
var interaction_timer: float = 0.0

# Performance optimization variables
var interaction_update_timer: float = 0.0
var interaction_frame_counter: int = 0
var last_player_position: Vector3

signal interaction_occurred(mob1: SphericalMob, mob2: SphericalMob, interaction_type: String)
signal environmental_effect_applied(mob: SphericalMob, effect_type: String)

func _ready():
	# Find system references
	mob_spawner = get_tree().get_first_node_in_group("mob_spawner")
	voxel_world = get_tree().get_first_node_in_group("voxel_world")
	player_node = get_tree().get_first_node_in_group("player")
	
	# Connect to mob spawner if available
	if mob_spawner:
		mob_spawner.mob_spawned.connect(_on_mob_spawned)
		mob_spawner.mob_despawned.connect(_on_mob_despawned)
	
	Logger.info("MOBS", "MobInteractionSystem initialized")
	add_to_group("mob_interaction_system")

func _process(delta):
	# Performance optimization: update less frequently
	interaction_update_timer += delta
	interaction_frame_counter += 1
	
	# Process interactions with reduced frequency
	if interaction_update_timer >= interaction_update_interval:
		process_all_interactions_optimized(delta)
		interaction_update_timer = 0.0
	
	# Apply environmental effects less frequently
	if wind_enabled and interaction_frame_counter % 10 == 0:
		apply_wind_effects_optimized(delta)

func process_all_interactions_optimized(delta):
	if not mob_spawner:
		return
	
	var mobs = mob_spawner.active_mobs
	
	# Filter out distant mobs for performance
	var nearby_mobs: Array[SphericalMob] = []
	if enable_distance_culling and player_node:
		last_player_position = player_node.global_position
		for mob in mobs:
			if is_instance_valid(mob) and mob.global_position.distance_to(last_player_position) < interaction_distance_threshold:
				nearby_mobs.append(mob)
	else:
		nearby_mobs = mobs
	
	# Process mob-to-mob interactions with limits
	if enable_mob_to_mob_interaction:
		process_mob_interactions_optimized(nearby_mobs, delta)
	
	# Process terrain interactions (less frequently)
	if enable_terrain_interaction and interaction_frame_counter % 3 == 0:
		process_terrain_interactions_optimized(nearby_mobs, delta)
	
	# Process player interactions
	if enable_player_interaction and player_node:
		process_player_interactions_optimized(nearby_mobs, delta)

func process_mob_interactions_optimized(mobs: Array[SphericalMob], _delta: float):
	# Limit the number of interaction checks per frame
	var interactions_processed = 0
	
	# Check interactions between mob pairs (limited)
	for i in range(min(mobs.size(), 5)):  # Only check first 5 mobs
		if interactions_processed >= max_mob_interactions_per_frame:
			break
			
		for j in range(i + 1, min(mobs.size(), i + 4)):  # Limit secondary checks
			var mob1 = mobs[i]
			var mob2 = mobs[j]
			
			if not is_instance_valid(mob1) or not is_instance_valid(mob2):
				continue
			
			var distance = mob1.global_position.distance_to(mob2.global_position)
			var interaction_range = mob1.mob_radius + mob2.mob_radius + 1.5  # Smaller range
			
			if distance < interaction_range:
				handle_mob_collision_optimized(mob1, mob2, distance)
				interactions_processed += 1
				
				if interactions_processed >= max_mob_interactions_per_frame:
					break

func handle_mob_collision_optimized(mob1: SphericalMob, mob2: SphericalMob, distance: float):
	# Simplified collision response
	var collision_direction = (mob2.global_position - mob1.global_position).normalized()
	var overlap = (mob1.mob_radius + mob2.mob_radius) - distance
	
	if overlap > 0:
		# Simpler separation
		var separation_force = collision_direction * overlap * 30.0  # Reduced force
		mob1.apply_external_force(-separation_force)
		mob2.apply_external_force(separation_force)
		
		# Simplified behavior interaction
		handle_behavior_interaction_optimized(mob1, mob2)

func handle_behavior_interaction_optimized(mob1: SphericalMob, mob2: SphericalMob):
	# Simplified health-based interactions
	var mob1_strength = mob1.get_health_percentage()
	var mob2_strength = mob2.get_health_percentage()
	
	# Only handle aggressive interactions for performance
	if mob1.behavior_mode == SphericalMob.BehaviorMode.AGGRESSIVE:
		if mob1_strength > mob2_strength and mob1.mob_radius > mob2.mob_radius * 1.3:
			mob2.take_damage(10.0, mob1)  # Fixed damage for simplicity
		
		var push_direction = (mob2.global_position - mob1.global_position).normalized()
		mob2.apply_external_force(push_direction * 50.0)  # Reduced force
	
	elif mob2.behavior_mode == SphericalMob.BehaviorMode.AGGRESSIVE:
		if mob2_strength > mob1_strength and mob2.mob_radius > mob1.mob_radius * 1.3:
			mob1.take_damage(10.0, mob2)
		
		var push_direction = (mob1.global_position - mob2.global_position).normalized()
		mob1.apply_external_force(push_direction * 50.0)

func process_terrain_interactions_optimized(mobs: Array[SphericalMob], _delta: float):
	if not voxel_world:
		return
	
	# Only check a few mobs per frame
	var checks_per_frame = min(3, mobs.size())
	for i in range(checks_per_frame):
		var mob = mobs[i]
		if not is_instance_valid(mob):
			continue
		
		# Simplified terrain check
		var mob_position = mob.global_position
		if mob_position.y > 0.5:  # Simple height check instead of voxel lookup
			var voxel_below = voxel_world.get_voxel_at_world_position(mob_position + Vector3.DOWN * mob.mob_radius)
			apply_terrain_effect_optimized(mob, voxel_below)

func apply_terrain_effect_optimized(mob: SphericalMob, voxel_type: int):
	# Simplified terrain effects
	match voxel_type:
		1: # Grass - small speed boost
			if mob.linear_velocity.length() > 0.5:
				var boost_direction = mob.linear_velocity.normalized()
				mob.apply_external_force(boost_direction * 3.0)  # Reduced force
		3: # Stone - bounce
			if mob.is_on_ground and randf() < 0.05:  # Reduced chance
				mob.apply_external_force(Vector3.UP * 25.0)  # Reduced force

func process_player_interactions_optimized(mobs: Array[SphericalMob], _delta: float):
	if not player_node:
		return
		
	var player_position = last_player_position
	
	# Only check close mobs to player
	var close_mobs = []
	for mob in mobs:
		if is_instance_valid(mob) and mob.is_alive():
			var distance = mob.global_position.distance_to(player_position)
			if distance < 8.0:  # Smaller interaction range
				close_mobs.append({"mob": mob, "distance": distance})
	
	# Sort by distance and only process closest 3
	close_mobs.sort_custom(func(a, b): return a.distance < b.distance)
	
	for i in range(min(3, close_mobs.size())):
		var mob_data = close_mobs[i]
		var mob = mob_data.mob
		var distance = mob_data.distance
		
		# Simplified player interactions
		match mob.behavior_mode:
			SphericalMob.BehaviorMode.AGGRESSIVE:
				if distance < mob.mob_radius + 1.5:
					var attack_force = 30.0 * mob.get_health_percentage()  # Reduced force
					apply_player_effect("mob_attack", (player_position - mob.global_position).normalized() * attack_force)

func apply_wind_effects_optimized(_delta: float):
	if not mob_spawner:
		return
	
	# Apply wind to only nearby mobs
	var wind_force = wind_direction * wind_strength * 0.5  # Reduced wind force
	var mobs_affected = 0
	
	for mob in mob_spawner.active_mobs:
		if not is_instance_valid(mob) or mobs_affected >= 5:  # Limit wind effects
			break
			
		if enable_distance_culling and player_node:
			if mob.global_position.distance_to(last_player_position) > interaction_distance_threshold:
				continue
		
		mob.apply_external_force(wind_force)
		mobs_affected += 1

func process_player_interactions(mobs: Array[SphericalMob], _delta: float):
	var player_position = player_node.global_position
	
	for mob in mobs:
		if not is_instance_valid(mob) or not mob.is_alive():
			continue
		
		var distance_to_player = mob.global_position.distance_to(player_position)
		var mob_strength = mob.get_health_percentage()
		var mob_size_factor = mob.mob_radius / 0.5  # Normalize to base size
		
		# Different interactions based on behavior, distance, and mob health/size
		match mob.behavior_mode:
			SphericalMob.BehaviorMode.SEEK_PLAYER:
				if distance_to_player < 2.0:
					# Larger/healthier mobs push harder
					var push_force = 10.0 * mob_size_factor
					apply_player_effect("mob_push", (player_position - mob.global_position).normalized() * push_force)
			
			SphericalMob.BehaviorMode.AGGRESSIVE:
				if distance_to_player < mob.mob_radius + 1.0:
					# Aggressive mob damage scales with size and health
					var attack_force = 50.0 * mob_strength * mob_size_factor
					apply_player_effect("mob_attack", (player_position - mob.global_position).normalized() * attack_force)
					
					# Large aggressive mobs can damage terrain around player
					if mob_size_factor > 1.5 and voxel_world:
						damage_terrain_around_player(player_position, mob_size_factor)
			
			SphericalMob.BehaviorMode.FLOCK:
				if distance_to_player < 1.5:
					# Friendly flocking mobs might heal player slightly
					if randf() < 0.01 * mob_strength:  # Small chance based on mob health
						apply_player_effect("mob_heal", Vector3.ZERO)

func damage_terrain_around_player(player_pos: Vector3, damage_factor: float):
	# Large aggressive mobs can destroy terrain near the player
	if randf() < 0.1 * damage_factor:  # Chance scales with mob size
		var damage_positions = [
			player_pos + Vector3.UP,
			player_pos + Vector3.DOWN,
			player_pos + Vector3.LEFT,
			player_pos + Vector3.RIGHT,
			player_pos + Vector3.FORWARD,
			player_pos + Vector3.BACK
		]
		
		for pos in damage_positions:
			var voxel_type = voxel_world.get_voxel_at_world_position(pos)
			# Only destroy softer materials (grass, dirt)
			if voxel_type == 1 or voxel_type == 2:
				if randf() < 0.3:
					voxel_world.set_voxel_at_world_position(pos, 0)

func apply_player_effect(effect_type: String, force: Vector3):
	# Apply effect to player (if player has appropriate methods)
	match effect_type:
		"mob_push", "mob_attack":
			if player_node.has_method("apply_external_force"):
				player_node.apply_external_force(force)
			elif player_node.has_method("add_velocity"):
				player_node.add_velocity(force * 0.1)
		"mob_heal":
			# Could add player healing here if player has health system
			Logger.debug("MOBS", "Friendly mob near player")
	
	Logger.debug("MOBS", "Applied player effect: " + effect_type)

func apply_wind_effects(delta: float):
	if not mob_spawner:
		return
	
	for mob in mob_spawner.active_mobs:
		if not is_instance_valid(mob):
			continue
		
		# Apply wind force (stronger effect when airborne)
		var wind_force = wind_direction.normalized() * wind_strength
		if not mob.is_on_ground:
			wind_force *= 2.0  # Stronger effect when airborne
		
		mob.apply_external_force(wind_force * delta)

func _on_mob_spawned(mob: SphericalMob):
	Logger.debug("MOBS", "MobInteractionSystem tracking new mob")
	
	# Apply initial environmental effects
	if gravity_modifier != 1.0:
		mob.gravity_scale = gravity_modifier

func _on_mob_despawned(mob: SphericalMob):
	# Clean up any tracking data for this mob
	active_interactions.erase(mob)

# Public interface for external control
func set_wind(direction: Vector3, strength: float):
	wind_direction = direction.normalized()
	wind_strength = strength
	wind_enabled = strength > 0.0
	Logger.info("MOBS", "Wind set to: " + str(direction) + " strength: " + str(strength))

func create_explosion_at(position: Vector3, radius: float = 10.0, force: float = 500.0):
	if not mob_spawner:
		return
	
	for mob in mob_spawner.active_mobs:
		if not is_instance_valid(mob):
			continue
		
		var distance = mob.global_position.distance_to(position)
		if distance < radius:
			var explosion_force = (mob.global_position - position).normalized()
			var force_magnitude = force * (1.0 - distance / radius)  # Closer = stronger
			mob.apply_external_force(explosion_force * force_magnitude)
	
	Logger.info("MOBS", "Explosion created at " + str(position) + " affecting nearby mobs")

func toggle_interaction_type(interaction_type: String, enabled: bool):
	match interaction_type:
		"mob_to_mob":
			enable_mob_to_mob_interaction = enabled
		"terrain":
			enable_terrain_interaction = enabled
		"player":
			enable_player_interaction = enabled
	
	Logger.info("MOBS", "Interaction type '" + interaction_type + "' " + ("enabled" if enabled else "disabled"))

func get_interaction_statistics() -> Dictionary:
	return {
		"mob_to_mob_enabled": enable_mob_to_mob_interaction,
		"terrain_enabled": enable_terrain_interaction,
		"player_enabled": enable_player_interaction,
		"wind_enabled": wind_enabled,
		"active_interactions": active_interactions.size()
	}
