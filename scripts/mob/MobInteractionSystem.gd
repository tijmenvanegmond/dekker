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

# References
var mob_spawner: MobSpawner
var voxel_world: VoxelWorld
var player_node: Node3D

# Interaction tracking
var active_interactions: Dictionary = {}
var interaction_timer: float = 0.0

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
	
	VoxelLogger.info("MOBS", "MobInteractionSystem initialized")
	add_to_group("mob_interaction_system")

func _process(delta):
	interaction_timer -= delta
	
	# Process interactions periodically to avoid performance issues
	if interaction_timer <= 0.0:
		process_all_interactions(delta)
		interaction_timer = 0.1  # Process every 100ms
	
	# Apply environmental effects
	if wind_enabled:
		apply_wind_effects(delta)

func process_all_interactions(delta):
	if not mob_spawner:
		return
	
	var mobs = mob_spawner.active_mobs
	
	# Process mob-to-mob interactions
	if enable_mob_to_mob_interaction:
		process_mob_interactions(mobs, delta)
	
	# Process terrain interactions
	if enable_terrain_interaction:
		process_terrain_interactions(mobs, delta)
	
	# Process player interactions
	if enable_player_interaction and player_node:
		process_player_interactions(mobs, delta)

func process_mob_interactions(mobs: Array[SphericalMob], _delta: float):
	# Check interactions between all mob pairs
	for i in range(mobs.size()):
		for j in range(i + 1, mobs.size()):
			var mob1 = mobs[i]
			var mob2 = mobs[j]
			
			if not is_instance_valid(mob1) or not is_instance_valid(mob2):
				continue
			
			var distance = mob1.global_position.distance_to(mob2.global_position)
			var interaction_range = mob1.mob_radius + mob2.mob_radius + 2.0
			
			if distance < interaction_range:
				handle_mob_collision(mob1, mob2, distance)

func handle_mob_collision(mob1: SphericalMob, mob2: SphericalMob, distance: float):
	# Calculate collision response
	var collision_direction = (mob2.global_position - mob1.global_position).normalized()
	var overlap = (mob1.mob_radius + mob2.mob_radius) - distance
	
	if overlap > 0:
		# Separate overlapping mobs
		var separation_force = collision_direction * overlap * 50.0 * interaction_force_multiplier
		mob1.apply_external_force(-separation_force)
		mob2.apply_external_force(separation_force)
		
		# Behavior-based interactions
		handle_behavior_interaction(mob1, mob2)
		
		interaction_occurred.emit(mob1, mob2, "collision")

func handle_behavior_interaction(mob1: SphericalMob, mob2: SphericalMob):
	# Interaction based on behavior modes
	match [mob1.behavior_mode, mob2.behavior_mode]:
		[SphericalMob.BehaviorMode.AGGRESSIVE, _]:
			# Aggressive mob pushes others away
			var push_direction = (mob2.global_position - mob1.global_position).normalized()
			mob2.apply_external_force(push_direction * 100.0)
		
		[SphericalMob.BehaviorMode.FLOCK, SphericalMob.BehaviorMode.FLOCK]:
			# Flocking mobs attract slightly
			var attract_direction = (mob2.global_position - mob1.global_position).normalized()
			mob1.apply_external_force(attract_direction * 20.0)
			mob2.apply_external_force(-attract_direction * 20.0)
		
		[SphericalMob.BehaviorMode.FLEE_PLAYER, _]:
			# Fleeing mobs bounce off others
			var bounce_direction = (mob1.global_position - mob2.global_position).normalized()
			mob1.apply_external_force(bounce_direction * 80.0)

func process_terrain_interactions(mobs: Array[SphericalMob], _delta: float):
	if not voxel_world:
		return
	
	for mob in mobs:
		if not is_instance_valid(mob):
			continue
		
		# Check voxel below mob
		var mob_position = mob.global_position
		var voxel_below = voxel_world.get_voxel_at_world_position(mob_position + Vector3.DOWN * mob.mob_radius)
		
		# Apply terrain-specific effects
		apply_terrain_effect(mob, voxel_below)
		
		# Check for voxel destruction (aggressive mobs)
		if mob.behavior_mode == SphericalMob.BehaviorMode.AGGRESSIVE:
			check_voxel_destruction(mob, mob_position)

func apply_terrain_effect(mob: SphericalMob, voxel_type: int):
	match voxel_type:
		1: # Grass - slight speed boost
			if mob.linear_velocity.length() > 0.1:
				var boost_direction = mob.linear_velocity.normalized()
				mob.apply_external_force(boost_direction * 5.0)
				environmental_effect_applied.emit(mob, "grass_boost")
		
		2: # Dirt - normal friction
			pass
		
		3: # Stone - bouncy surface
			if mob.is_on_ground and randf() < 0.1:  # 10% chance per check
				mob.apply_external_force(Vector3.UP * 50.0)
				environmental_effect_applied.emit(mob, "stone_bounce")
		
		4: # Ore - attracts mobs
			var attraction_center = voxel_world.world_to_voxel_pos(mob.global_position)
			var direction_to_ore = (Vector3(attraction_center) - mob.global_position).normalized()
			mob.apply_external_force(direction_to_ore * 15.0)
			environmental_effect_applied.emit(mob, "ore_attraction")

func check_voxel_destruction(mob: SphericalMob, position: Vector3):
	# Aggressive mobs can destroy weak voxels when moving fast
	if mob.linear_velocity.length() > 4.0:
		var impact_position = position + mob.linear_velocity.normalized() * mob.mob_radius
		var voxel_type = voxel_world.get_voxel_at_world_position(impact_position)
		
		# Only destroy dirt and grass (not stone)
		if voxel_type == 1 or voxel_type == 2:
			if randf() < 0.05:  # 5% chance
				voxel_world.set_voxel_at_world_position(impact_position, 0)  # Remove voxel
				VoxelLogger.debug("MOBS", "Aggressive mob destroyed voxel at " + str(impact_position))

func process_player_interactions(mobs: Array[SphericalMob], _delta: float):
	var player_position = player_node.global_position
	
	for mob in mobs:
		if not is_instance_valid(mob):
			continue
		
		var distance_to_player = mob.global_position.distance_to(player_position)
		
		# Different interactions based on behavior and distance
		match mob.behavior_mode:
			SphericalMob.BehaviorMode.SEEK_PLAYER:
				if distance_to_player < 2.0:
					# Player gets slight push when mob gets close
					apply_player_effect("mob_push", (player_position - mob.global_position).normalized() * 10.0)
			
			SphericalMob.BehaviorMode.AGGRESSIVE:
				if distance_to_player < 1.5:
					# Aggressive mob damages/pushes player
					apply_player_effect("mob_attack", (player_position - mob.global_position).normalized() * 50.0)

func apply_player_effect(effect_type: String, force: Vector3):
	# Apply effect to player (if player has appropriate methods)
	if player_node.has_method("apply_external_force"):
		player_node.apply_external_force(force)
	elif player_node.has_method("add_velocity"):
		player_node.add_velocity(force * 0.1)
	
	VoxelLogger.debug("MOBS", "Applied player effect: " + effect_type)

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
	VoxelLogger.debug("MOBS", "MobInteractionSystem tracking new mob")
	
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
	VoxelLogger.info("MOBS", "Wind set to: " + str(direction) + " strength: " + str(strength))

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
	
	VoxelLogger.info("MOBS", "Explosion created at " + str(position) + " affecting nearby mobs")

func toggle_interaction_type(interaction_type: String, enabled: bool):
	match interaction_type:
		"mob_to_mob":
			enable_mob_to_mob_interaction = enabled
		"terrain":
			enable_terrain_interaction = enabled
		"player":
			enable_player_interaction = enabled
	
	VoxelLogger.info("MOBS", "Interaction type '" + interaction_type + "' " + ("enabled" if enabled else "disabled"))

func get_interaction_statistics() -> Dictionary:
	return {
		"mob_to_mob_enabled": enable_mob_to_mob_interaction,
		"terrain_enabled": enable_terrain_interaction,
		"player_enabled": enable_player_interaction,
		"wind_enabled": wind_enabled,
		"active_interactions": active_interactions.size()
	}
