class_name SphericalMob
extends RigidBody3D

## Spherical mob that interacts with voxel terrain and other mobs
## Features: Rolling physics, terrain interaction, mob-to-mob interaction, AI behavior

@export_group("Mob Properties")
@export var mob_radius: float = 0.5
@export var mob_mass: float = 1.0
@export var max_speed: float = 5.0
@export var bounce_force: float = 300.0
@export var attraction_force: float = 50.0

@export_group("Health System")
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var base_radius: float = 0.3  # Minimum size when health is low
@export var max_radius: float = 1.2   # Maximum size when health is full
@export var health_regen_rate: float = 5.0  # Health per second regeneration
@export var size_update_smoothing: float = 2.0  # How fast size changes

@export_group("AI Behavior")
@export var wander_radius: float = 10.0
@export var detection_radius: float = 8.0
@export var flee_radius: float = 3.0
@export var behavior_mode: BehaviorMode = BehaviorMode.WANDER

@export_group("Visual")
@export var mob_color: Color = Color.CYAN
@export var glow_intensity: float = 0.5

@export_group("Performance Settings")
@export var ai_update_interval: float = 0.2  # Update AI every 200ms
@export var visual_update_interval: float = 0.1  # Update visuals every 100ms
@export var health_update_interval: float = 0.5  # Update health every 500ms
@export var physics_optimization: bool = true  # Enable physics optimizations

enum BehaviorMode {
	WANDER,      # Random wandering
	SEEK_PLAYER, # Move towards player
	FLEE_PLAYER, # Move away from player
	FLOCK,       # Group behavior with other mobs
	AGGRESSIVE   # Chase and attack
}

# Components
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var detection_area: Area3D
var material: StandardMaterial3D

# AI state
var target_position: Vector3
var home_position: Vector3
var wander_timer: float = 0.0
var behavior_timer: float = 0.0
var nearby_mobs: Array[SphericalMob] = []
var player_reference: Node3D

# Physics state
var last_velocity: Vector3
var is_on_ground: bool = false
var bounce_cooldown: float = 0.0

# Health state
var target_radius: float  # The radius we're scaling towards
var current_scale: float = 1.0  # Current scaling factor
var damage_flash_tween: Tween  # Reuse tween to prevent creating multiple
var heal_flash_tween: Tween   # Reuse tween to prevent creating multiple

# Performance timers
var optimization_frame_counter: int = 0
var last_player_distance: float = 999.0  # Cache player distance

# Signals for health events
signal health_changed(old_health: float, new_health: float)
signal mob_died(mob: SphericalMob)

func _ready():
	setup_physics()
	setup_visual()
	setup_detection()
	setup_behavior()
	setup_health_system()
	
	# Store initial position as home
	home_position = global_position
	target_position = global_position

func setup_physics():
	# Configure RigidBody3D
	mass = mob_mass
	gravity_scale = 1.0
	lock_rotation = false  # Allow rolling
	continuous_cd = true   # Better collision detection
	
	# Create sphere collision shape
	collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = mob_radius
	collision_shape.shape = sphere_shape
	add_child(collision_shape)
	
	# Connect physics signals for mob-to-mob interactions (needed for flocking)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup_visual():
	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = mob_radius
	sphere_mesh.height = mob_radius * 2
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	mesh_instance.mesh = sphere_mesh
	
	# Create glowing material
	material = StandardMaterial3D.new()
	material.albedo_color = mob_color
	material.emission_enabled = true
	material.emission = mob_color * glow_intensity
	material.roughness = 0.3
	material.metallic = 0.1
	mesh_instance.material_override = material
	
	add_child(mesh_instance)

func setup_detection():
	# Simplified detection - remove expensive collision detection
	# Just store detection radius for simple distance checks
	pass

func setup_behavior():
	# Initialize behavior timers
	wander_timer = randf() * 2.0
	behavior_timer = randf() * 5.0
	
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")

func setup_health_system():
	# Initialize health system
	current_health = max_health
	target_radius = calculate_radius_from_health()
	current_scale = target_radius / base_radius
	
	# Update initial size
	update_mob_scale()

func _physics_process(delta):
	# CRITICAL: Only do the absolute minimum every frame
	
	# Always limit velocity to prevent physics issues (essential for physics)
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	
	# Much less frequent updates - only every 60 frames (1 second at 60fps)
	optimization_frame_counter += 1
	var mob_id = get_instance_id() % 60  # Spread across 60 frames instead of 30
	var should_update = optimization_frame_counter % 60 == mob_id
	
	# Only do expensive updates very occasionally
	if should_update:
		update_minimal_systems(delta * 60.0)  # Compensate for less frequent updates

# Single optimized update function that caches expensive calculations
func update_minimal_systems(delta):
	# Cache player distance ONCE per update cycle
	if player_reference:
		last_player_distance = global_position.distance_to(player_reference.global_position)
	
	# Skip ALL updates if too far from player
	if last_player_distance > 50.0:
		return
	
	# Update timers
	behavior_timer -= delta
	wander_timer -= delta
	bounce_cooldown -= delta
	
	# Simple behavior update
	update_behavior_simple(delta)
	
	# Simple visual update (no expensive material changes)
	update_visual_simple(delta)
	
	# Health regeneration
	if current_health < max_health:
		var old_health = current_health
		current_health = min(max_health, current_health + health_regen_rate * delta)
		if abs(current_health - old_health) > 5.0:  # Only emit signal for significant changes
			health_changed.emit(old_health, current_health)

func update_behavior_simple(delta):
	# Complex behavior system - optimized but full-featured
	match behavior_mode:
		BehaviorMode.WANDER:
			behavior_wander(delta)
		BehaviorMode.SEEK_PLAYER:
			behavior_seek_player(delta)
		BehaviorMode.FLEE_PLAYER:
			behavior_flee_player(delta)
		BehaviorMode.FLOCK:
			behavior_flock(delta)
		BehaviorMode.AGGRESSIVE:
			behavior_aggressive(delta)
	
	# Apply movement force towards target
	apply_movement_force(delta)

func update_visual_simple(_delta):
	# Skip visual updates if too far
	if last_player_distance > 30.0:
		return
	
	# Only update scale if health changed significantly
	var new_target_radius = calculate_radius_from_health()
	if abs(new_target_radius - target_radius) > 0.1:  # Much larger threshold
		target_radius = new_target_radius
		update_mob_scale_simple()
	
	# Enhanced visual feedback based on behavior
	if material:
		var health_percent = current_health / max_health
		
		# Dynamic color changes based on behavior and health
		match behavior_mode:
			BehaviorMode.AGGRESSIVE:
				material.emission = Color.RED * (glow_intensity * (1.0 + health_percent))
				material.albedo_color = mob_color.lerp(Color.RED, 0.4)
			BehaviorMode.FLEE_PLAYER:
				material.emission = Color.YELLOW * (glow_intensity * health_percent)
				material.albedo_color = mob_color.lerp(Color.YELLOW, 0.3)
			BehaviorMode.SEEK_PLAYER:
				material.emission = Color.GREEN * (glow_intensity * health_percent)
				material.albedo_color = mob_color.lerp(Color.GREEN, 0.2)
			BehaviorMode.FLOCK:
				material.emission = Color.CYAN * (glow_intensity * health_percent)
				material.albedo_color = mob_color
			_: # WANDER
				material.emission = mob_color * (glow_intensity * health_percent)
				material.albedo_color = mob_color
		
		# Health-based color modifications
		if health_percent < 0.3:
			material.albedo_color = material.albedo_color.lerp(Color.DARK_RED, 0.5)
		elif health_percent > 0.9:
			material.albedo_color = material.albedo_color.lerp(Color.WHITE, 0.2)

func update_mob_scale_simple():
	# Direct scale update without smooth interpolation
	var target_scale = target_radius / base_radius
	current_scale = target_scale
	
	# Update mesh scale only
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * current_scale
	
	# Update collision much less frequently - only for significant changes
	if abs(current_scale - (mob_radius / base_radius)) > 0.2:
		if collision_shape and collision_shape.shape is SphereShape3D:
			var sphere = collision_shape.shape as SphereShape3D
			sphere.radius = base_radius * current_scale
		mob_radius = base_radius * current_scale

# Complex behavior functions
func behavior_wander(_delta):
	# Advanced wandering with environmental awareness
	if wander_timer <= 0.0:
		var random_direction = Vector3(
			randf_range(-1, 1),
			0,
			randf_range(-1, 1)
		).normalized()
		
		# Add some noise for more organic movement
		var noise_offset = Vector3(
			sin(Time.get_ticks_msec() * 0.001) * 0.3,
			0,
			cos(Time.get_ticks_msec() * 0.001) * 0.3
		)
		
		target_position = home_position + random_direction * wander_radius + noise_offset
		wander_timer = randf_range(3.0, 6.0)
	
	# Dynamic player detection with behavior switching
	if player_reference and last_player_distance < detection_radius:
		if randf() < 0.3:  # 30% chance to notice player
			# Choose behavior based on mob's health/size
			var health_factor = get_health_percentage()
			if health_factor > 0.8:
				behavior_mode = BehaviorMode.SEEK_PLAYER
			elif health_factor < 0.4:
				behavior_mode = BehaviorMode.FLEE_PLAYER
			else:
				behavior_mode = BehaviorMode.FLOCK
			behavior_timer = randf_range(5.0, 10.0)

func behavior_seek_player(_delta):
	if player_reference:
		# Advanced pathfinding towards player
		var player_pos = player_reference.global_position
		var direction_to_player = (player_pos - global_position).normalized()
		
		# Add prediction based on player movement
		if player_reference.has_method("get_velocity"):
			var player_velocity = player_reference.get_velocity() if player_reference.has_method("get_velocity") else Vector3.ZERO
			var predicted_pos = player_pos + player_velocity * 0.5
			direction_to_player = (predicted_pos - global_position).normalized()
		
		target_position = global_position + direction_to_player * detection_radius * 0.8
		
		# Switch behavior based on distance and health
		if behavior_timer <= 0.0:
			var health_factor = get_health_percentage()
			if last_player_distance > detection_radius * 2:
				behavior_mode = BehaviorMode.WANDER
			elif health_factor > 0.9 and last_player_distance < 3.0:
				behavior_mode = BehaviorMode.AGGRESSIVE
				behavior_timer = randf_range(3.0, 8.0)

func behavior_flee_player(_delta):
	if player_reference:
		# Intelligent fleeing with obstacle avoidance
		var flee_direction = (global_position - player_reference.global_position).normalized()
		
		# Add some randomness to avoid predictable patterns
		var random_offset = Vector3(
			randf_range(-0.5, 0.5),
			0,
			randf_range(-0.5, 0.5)
		)
		flee_direction = (flee_direction + random_offset).normalized()
		
		target_position = global_position + flee_direction * flee_radius
		
		# Stop fleeing when far enough or timer expires
		if behavior_timer <= 0.0 or last_player_distance > detection_radius * 3:
			behavior_mode = BehaviorMode.WANDER
			behavior_timer = randf_range(2.0, 5.0)

func behavior_flock(_delta):
	# Advanced flocking behavior with separation, alignment, and cohesion
	var separation_force = Vector3.ZERO
	var alignment_force = Vector3.ZERO
	var cohesion_force = Vector3.ZERO
	var close_mobs = []
	
	# Find nearby mobs efficiently
	for mob in nearby_mobs:
		if is_instance_valid(mob) and mob != self:
			var distance_sq = global_position.distance_squared_to(mob.global_position)
			if distance_sq < 25.0:  # 5.0 units squared
				close_mobs.append(mob)
	
	if close_mobs.size() > 0:
		# Separation: avoid crowding neighbors
		for mob in close_mobs:
			var diff = global_position - mob.global_position
			var distance = diff.length()
			if distance > 0 and distance < 3.0:
				separation_force += diff.normalized() / distance
		
		# Alignment: steer towards average heading of neighbors
		var avg_velocity = Vector3.ZERO
		for mob in close_mobs:
			avg_velocity += mob.linear_velocity
		if close_mobs.size() > 0:
			avg_velocity /= close_mobs.size()
			alignment_force = avg_velocity.normalized()
		
		# Cohesion: steer towards average position of neighbors
		var center = Vector3.ZERO
		for mob in close_mobs:
			center += mob.global_position
		center /= close_mobs.size()
		cohesion_force = (center - global_position).normalized()
		
		# Combine forces with weights
		var combined_force = (separation_force * 2.0 + alignment_force * 1.0 + cohesion_force * 1.5).normalized()
		target_position = global_position + combined_force * 5.0
	else:
		# No nearby mobs, switch to wandering
		if behavior_timer <= 0.0:
			behavior_mode = BehaviorMode.WANDER
			behavior_timer = randf_range(3.0, 7.0)

func behavior_aggressive(_delta):
	if player_reference and last_player_distance < detection_radius:
		# Advanced combat behavior
		var player_pos = player_reference.global_position
		
		# Circle around player before attacking
		var circle_angle = Time.get_ticks_msec() * 0.002
		var circle_radius = 4.0
		var circle_pos = player_pos + Vector3(
			cos(circle_angle) * circle_radius,
			0,
			sin(circle_angle) * circle_radius
		)
		
		# Choose between circling and direct attack
		if last_player_distance > 2.5:
			target_position = circle_pos
		else:
			target_position = player_pos
			
			# Attack with charging behavior
			if randf() < 0.1:  # 10% chance per update to charge
				var charge_direction = (player_pos - global_position).normalized()
				apply_central_impulse(charge_direction * bounce_force * 0.8)
				
				# Damage terrain around attack point occasionally
				if randf() < 0.05:
					damage_terrain_around_position(player_pos)
		
		# Switch behavior based on health
		var health_factor = get_health_percentage()
		if behavior_timer <= 0.0 or health_factor < 0.3:
			if health_factor < 0.3:
				behavior_mode = BehaviorMode.FLEE_PLAYER
			else:
				behavior_mode = BehaviorMode.WANDER
			behavior_timer = randf_range(5.0, 12.0)
	else:
		# Player too far, return to wandering
		behavior_mode = BehaviorMode.WANDER
		behavior_timer = randf_range(3.0, 8.0)

func apply_movement_force(_delta):
	var direction_to_target = (target_position - global_position)
	direction_to_target.y = 0  # Keep movement horizontal
	
	if direction_to_target.length() > 1.0:
		direction_to_target = direction_to_target.normalized()
		
		# Dynamic force based on behavior and health
		var force_multiplier = 1.0
		match behavior_mode:
			BehaviorMode.AGGRESSIVE:
				force_multiplier = 1.5
			BehaviorMode.FLEE_PLAYER:
				force_multiplier = 1.8
			BehaviorMode.SEEK_PLAYER:
				force_multiplier = 1.2
			BehaviorMode.FLOCK:
				force_multiplier = 0.8
			_:
				force_multiplier = 1.0
		
		# Scale force by health - healthier mobs move faster
		var health_factor = get_health_percentage()
		force_multiplier *= (0.5 + health_factor * 0.5)
		
		var movement_force = direction_to_target * attraction_force * force_multiplier
		apply_central_force(movement_force)

func damage_terrain_around_position(world_position: Vector3):
	# Advanced terrain interaction for aggressive mobs
	var voxel_world = get_tree().get_first_node_in_group("voxel_world")
	if not voxel_world or not voxel_world.has_method("get_voxel_at_world_position"):
		return
	
	# Only large, healthy mobs can damage terrain
	var health_factor = get_health_percentage()
	var size_factor = mob_radius / base_radius
	
	if health_factor > 0.7 and size_factor > 1.3:
		# Damage voxels in a small radius
		var damage_positions = [
			world_position + Vector3.UP,
			world_position + Vector3.DOWN,
			world_position + Vector3.LEFT * 0.5,
			world_position + Vector3.RIGHT * 0.5,
			world_position + Vector3.FORWARD * 0.5,
			world_position + Vector3.BACK * 0.5
		]
		
		for pos in damage_positions:
			if randf() < 0.3:  # 30% chance per voxel
				var voxel_type = voxel_world.get_voxel_at_world_position(pos)
				# Only destroy softer materials
				if voxel_type == 1 or voxel_type == 2:  # Grass or dirt
					if voxel_world.has_method("set_voxel_at_world_position"):
						voxel_world.set_voxel_at_world_position(pos, 0)

func calculate_radius_from_health() -> float:
	# Scale radius based on health percentage
	var health_percent = current_health / max_health
	return lerp(base_radius, max_radius, health_percent)

func update_mob_scale():
	# Update mesh scale only - skip expensive collision updates
	if mesh_instance:
		mesh_instance.scale = Vector3.ONE * current_scale
	
	# Update mob_radius property to match current size
	mob_radius = base_radius * current_scale

# Health management methods
func take_damage(damage: float, source: Node3D = null):
	var old_health = current_health
	current_health = max(0.0, current_health - damage)
	
	health_changed.emit(old_health, current_health)
	
	# Visual feedback for damage
	if mesh_instance:
		# Kill previous tween to prevent overlapping
		if damage_flash_tween:
			damage_flash_tween.kill()
		damage_flash_tween = create_tween()
		damage_flash_tween.tween_method(_flash_damage_color, 0.0, 1.0, 0.2)
	
	# Check for death
	if current_health <= 0.0:
		die()
	
	# Knockback effect based on damage
	if source and damage > 10.0:
		var knockback_direction = (global_position - source.global_position).normalized()
		var knockback_force = damage * 10.0
		apply_central_impulse(knockback_direction * knockback_force)

func heal(amount: float):
	var old_health = current_health
	current_health = min(max_health, current_health + amount)
	
	if current_health != old_health:
		health_changed.emit(old_health, current_health)
		
		# Visual feedback for healing
		if mesh_instance:
			# Kill previous tween to prevent overlapping
			if heal_flash_tween:
				heal_flash_tween.kill()
			heal_flash_tween = create_tween()
			heal_flash_tween.tween_method(_flash_heal_color, 0.0, 1.0, 0.3)

func die():
	mob_died.emit(self)
	
	# Death effects
	if mesh_instance:
		var tween = create_tween()
		tween.parallel().tween_property(mesh_instance, "scale", Vector3.ZERO, 0.5)
		tween.parallel().tween_property(material, "transparency", 1.0, 0.5)
		tween.tween_callback(queue_free)

func _flash_damage_color(progress: float):
	if material:
		var flash_color = Color.RED.lerp(material.albedo_color, progress)
		material.emission = flash_color * glow_intensity * 2.0

func _flash_heal_color(progress: float):
	if material:
		var flash_color = Color.GREEN.lerp(material.albedo_color, progress)
		material.emission = flash_color * glow_intensity * 1.5

# Public health interface
func get_health_percentage() -> float:
	return current_health / max_health

func is_alive() -> bool:
	return current_health > 0.0

func set_max_health(new_max_health: float):
	var health_ratio = current_health / max_health if max_health > 0 else 1.0
	max_health = new_max_health
	current_health = max_health * health_ratio
	health_changed.emit(current_health, current_health)

# Terrain interaction
func interact_with_voxel_terrain():
	var voxel_world = get_tree().get_first_node_in_group("voxel_world")
	if voxel_world and voxel_world.has_method("get_voxel_at_world_position"):
		var voxel_below = voxel_world.get_voxel_at_world_position(global_position + Vector3.DOWN * mob_radius)
		
		# React to different voxel types
		match voxel_below:
			1: # Grass - normal behavior
				pass
			2: # Dirt - slight slowdown
				linear_velocity *= 0.95
			3: # Stone - bouncy
				if is_on_ground and bounce_cooldown <= 0:
					apply_central_impulse(Vector3.UP * bounce_force * 0.3)
					bounce_cooldown = 1.0

# Combat system
func calculate_collision_damage(other_mob: SphericalMob):
	"""Calculate and apply damage based on collision speed and size"""
	if not is_instance_valid(other_mob) or not other_mob.is_alive() or not is_alive():
		return
	
	# Get collision velocities
	var my_speed = linear_velocity.length()
	var other_speed = other_mob.linear_velocity.length()
	var _relative_speed = abs(my_speed - other_speed)  # For future use
	
	# Size factors (larger mobs do more damage)
	var my_size_factor = mob_radius / base_radius
	var other_size_factor = other_mob.mob_radius / other_mob.base_radius
	
	# Damage calculation: speed × size = damage
	var my_damage = my_speed * my_size_factor
	var other_damage = other_speed * other_size_factor
	
	# Minimum speed threshold to cause damage (prevent tiny bumps from dealing damage)
	var damage_threshold = 2.0
	
	# Apply damage to other mob if I'm moving fast enough
	if my_speed > damage_threshold and my_damage > 5.0:
		var damage_to_deal = my_damage * 0.5  # Scale damage for balance
		other_mob.take_damage(damage_to_deal, self)
		
		# Visual feedback for successful hit
		if other_mob.mesh_instance:
			create_damage_effect(other_mob.global_position)
		
		Logger.debug("MOBS", "Mob collision: %.1f damage dealt (speed: %.1f, size: %.1f)" % [damage_to_deal, my_speed, my_size_factor])
	
	# Apply damage to me if other mob is moving fast enough
	if other_speed > damage_threshold and other_damage > 5.0:
		var damage_to_take = other_damage * 0.5  # Scale damage for balance
		take_damage(damage_to_take, other_mob)
		
		# Visual feedback for taking hit
		if mesh_instance:
			create_damage_effect(global_position)
		
		Logger.debug("MOBS", "Mob collision: %.1f damage taken (other speed: %.1f, size: %.1f)" % [damage_to_take, other_speed, other_size_factor])
	
	# Knockback based on damage dealt
	var collision_direction = (global_position - other_mob.global_position).normalized()
	var knockback_force = (my_damage + other_damage) * 10.0  # Damage = knockback
	
	# Apply knockback to both mobs
	apply_central_impulse(collision_direction * knockback_force)
	other_mob.apply_central_impulse(-collision_direction * knockback_force)

func create_damage_effect(effect_position: Vector3):
	"""Create a visual effect at the damage location"""
	# Simple particle-like effect using temporary mesh
	var effect_sphere = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	effect_sphere.mesh = sphere_mesh
	
	# Red damage effect material
	var effect_material = StandardMaterial3D.new()
	effect_material.albedo_color = Color.RED
	effect_material.emission_enabled = true
	effect_material.emission = Color.RED * 2.0
	effect_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	effect_sphere.material_override = effect_material
	
	# Add to scene at damage position
	get_tree().current_scene.add_child(effect_sphere)
	effect_sphere.global_position = effect_position
	
	# Animate and remove effect
	var tween = create_tween()
	tween.parallel().tween_property(effect_sphere, "scale", Vector3.ZERO, 0.5)
	tween.parallel().tween_property(effect_material, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(effect_sphere.queue_free)

# Signal handlers
func _on_body_entered(body):
	if body is SphericalMob:
		nearby_mobs.append(body)
		
		# Calculate collision damage based on speed and size
		calculate_collision_damage(body)

func _on_body_exited(body):
	if body is SphericalMob:
		nearby_mobs.erase(body)

func _on_detection_entered(_body):
	pass

func _on_detection_exited(_body):
	pass

func _on_area_entered(_area):
	pass

func _on_area_exited(_area):
	pass

# Public methods for external control
func set_behavior_mode(new_mode: BehaviorMode):
	behavior_mode = new_mode
	behavior_timer = randf_range(3.0, 8.0)

func apply_external_force(force: Vector3):
	apply_central_impulse(force)

# Performance optimization: disable expensive features when far from player
func set_performance_mode(low_performance: bool):
	if low_performance:
		# Disable expensive visual effects
		if material:
			material.emission_enabled = false
		
		# Reduce physics quality
		physics_optimization = true
		continuous_cd = false
		
		# Longer update intervals
		ai_update_interval = 0.5
		visual_update_interval = 0.3
		health_update_interval = 1.0
	else:
		# Re-enable full quality
		if material:
			material.emission_enabled = true
		
		physics_optimization = false
		continuous_cd = true
		
		# Normal update intervals
		ai_update_interval = 0.2
		visual_update_interval = 0.1
		health_update_interval = 0.5

func get_behavior_info() -> Dictionary:
	return {
		"mode": BehaviorMode.keys()[behavior_mode],
		"target_position": target_position,
		"velocity": linear_velocity,
		"is_on_ground": is_on_ground,
		"nearby_mobs": nearby_mobs.size(),
		"health": current_health,
		"max_health": max_health,
		"health_percentage": get_health_percentage(),
		"size": mob_radius
	}
