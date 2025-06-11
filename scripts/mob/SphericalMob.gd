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

@export_group("AI Behavior")
@export var wander_radius: float = 10.0
@export var detection_radius: float = 8.0
@export var flee_radius: float = 3.0
@export var behavior_mode: BehaviorMode = BehaviorMode.WANDER

@export_group("Visual")
@export var mob_color: Color = Color.CYAN
@export var glow_intensity: float = 0.5

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

func _ready():
	setup_physics()
	setup_visual()
	setup_detection()
	setup_behavior()
	
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
	
	# Connect physics signals
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
	# Create detection area for nearby entities
	detection_area = Area3D.new()
	var detection_collision = CollisionShape3D.new()
	var detection_sphere = SphereShape3D.new()
	detection_sphere.radius = detection_radius
	detection_collision.shape = detection_sphere
	detection_area.add_child(detection_collision)
	add_child(detection_area)
	
	# Connect detection signals
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	detection_area.area_entered.connect(_on_area_entered)
	detection_area.area_exited.connect(_on_area_exited)

func setup_behavior():
	# Initialize behavior timers
	wander_timer = randf() * 2.0
	behavior_timer = randf() * 5.0
	
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	update_behavior(delta)
	update_physics(delta)
	update_visual(delta)
	
	# Store velocity for next frame
	last_velocity = linear_velocity

func update_behavior(delta):
	behavior_timer -= delta
	wander_timer -= delta
	bounce_cooldown -= delta
	
	# Update behavior based on mode
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

func behavior_wander(_delta):
	# Change direction periodically
	if wander_timer <= 0.0:
		var random_direction = Vector3(
			randf_range(-1, 1),
			0,
			randf_range(-1, 1)
		).normalized()
		
		target_position = home_position + random_direction * wander_radius
		wander_timer = randf_range(2.0, 5.0)
	
	# Switch to player interaction if player is nearby
	if player_reference and global_position.distance_to(player_reference.global_position) < detection_radius:
		if randf() < 0.3:  # 30% chance to flee
			behavior_mode = BehaviorMode.FLEE_PLAYER
		else:  # 70% chance to seek
			behavior_mode = BehaviorMode.SEEK_PLAYER
		behavior_timer = randf_range(3.0, 8.0)

func behavior_seek_player(_delta):
	if player_reference:
		target_position = player_reference.global_position
		
		# Return to wandering after some time or if player is far
		if behavior_timer <= 0.0 or global_position.distance_to(player_reference.global_position) > detection_radius * 1.5:
			behavior_mode = BehaviorMode.WANDER
			target_position = home_position

func behavior_flee_player(_delta):
	if player_reference:
		var flee_direction = (global_position - player_reference.global_position).normalized()
		target_position = global_position + flee_direction * flee_radius
		
		# Return to wandering if far enough away
		if behavior_timer <= 0.0 or global_position.distance_to(player_reference.global_position) > detection_radius * 2:
			behavior_mode = BehaviorMode.WANDER
			target_position = home_position

func behavior_flock(_delta):
	if nearby_mobs.size() > 0:
		# Calculate flocking forces
		var separation = calculate_separation()
		var alignment = calculate_alignment()
		var cohesion = calculate_cohesion()
		
		# Combine forces
		var flock_force = separation * 2.0 + alignment * 1.0 + cohesion * 1.0
		target_position = global_position + flock_force.normalized() * 2.0
	else:
		# No nearby mobs, return to wandering
		behavior_mode = BehaviorMode.WANDER

func behavior_aggressive(_delta):
	if player_reference and global_position.distance_to(player_reference.global_position) < detection_radius:
		# Chase player aggressively
		target_position = player_reference.global_position
		
		# If close enough, apply extra force (attack)
		if global_position.distance_to(player_reference.global_position) < mob_radius * 3:
			var attack_direction = (player_reference.global_position - global_position).normalized()
			apply_central_impulse(attack_direction * bounce_force * 0.5)
	else:
		behavior_mode = BehaviorMode.WANDER

func calculate_separation() -> Vector3:
	var separation_force = Vector3.ZERO
	var count = 0
	
	for mob in nearby_mobs:
		var distance = global_position.distance_to(mob.global_position)
		if distance < mob_radius * 4:  # Too close
			var away_direction = (global_position - mob.global_position).normalized()
			separation_force += away_direction / distance  # Stronger when closer
			count += 1
	
	return separation_force / max(count, 1)

func calculate_alignment() -> Vector3:
	var average_velocity = Vector3.ZERO
	
	for mob in nearby_mobs:
		average_velocity += mob.linear_velocity
	
	return average_velocity / max(nearby_mobs.size(), 1)

func calculate_cohesion() -> Vector3:
	var mob_center_of_mass = Vector3.ZERO
	
	for mob in nearby_mobs:
		mob_center_of_mass += mob.global_position
	
	mob_center_of_mass /= max(nearby_mobs.size(), 1)
	return (mob_center_of_mass - global_position).normalized()

func apply_movement_force(delta):
	var direction_to_target = (target_position - global_position)
	direction_to_target.y = 0  # Keep movement horizontal
	
	if direction_to_target.length() > 0.5:  # Only move if target is far enough
		direction_to_target = direction_to_target.normalized()
		
		# Apply force based on current speed
		var current_speed = Vector2(linear_velocity.x, linear_velocity.z).length()
		var force_multiplier = max(0.1, 1.0 - (current_speed / max_speed))
		
		var movement_force = direction_to_target * attraction_force * force_multiplier
		apply_central_force(movement_force)

func update_physics(delta):
	# Check if on ground (simplified)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * (mob_radius + 0.1)
	)
	var result = space_state.intersect_ray(query)
	is_on_ground = result.has("position")
	
	# Limit maximum speed
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

func update_visual(delta):
	# Pulse glow based on behavior
	var pulse_intensity = glow_intensity
	
	match behavior_mode:
		BehaviorMode.AGGRESSIVE:
			pulse_intensity += sin(Time.get_ticks_msec() * 0.01) * 0.3
			material.emission = Color.RED * pulse_intensity
		BehaviorMode.FLEE_PLAYER:
			pulse_intensity += sin(Time.get_ticks_msec() * 0.02) * 0.2
			material.emission = Color.YELLOW * pulse_intensity
		_:
			material.emission = mob_color * pulse_intensity

func interact_with_voxel_terrain():
	# Check for voxel terrain interaction
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

func _on_body_entered(body):
	if body is SphericalMob:
		nearby_mobs.append(body)
		
		# Collision interaction - bounce off each other
		var collision_direction = (global_position - body.global_position).normalized()
		apply_central_impulse(collision_direction * bounce_force * 0.5)

func _on_body_exited(body):
	if body is SphericalMob:
		nearby_mobs.erase(body)

func _on_detection_entered(body):
	# Detect player or other important entities
	if body.is_in_group("player"):
		# React to player presence based on current behavior
		pass

func _on_detection_exited(body):
	pass

func _on_area_entered(area):
	# Interact with other areas (power-ups, hazards, etc.)
	pass

func _on_area_exited(area):
	pass

# Public methods for external control
func set_behavior_mode(new_mode: BehaviorMode):
	behavior_mode = new_mode
	behavior_timer = randf_range(3.0, 8.0)

func apply_external_force(force: Vector3):
	apply_central_impulse(force)

func get_behavior_info() -> Dictionary:
	return {
		"mode": BehaviorMode.keys()[behavior_mode],
		"target_position": target_position,
		"velocity": linear_velocity,
		"is_on_ground": is_on_ground,
		"nearby_mobs": nearby_mobs.size()
	}
