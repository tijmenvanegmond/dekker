class_name PlayerController
extends CharacterBody3D

# Advanced player controller with world editing capabilities and action system
@export_group("Movement")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var air_control: float = 0.3
@export var friction: float = 10.0

@export_group("Slope Climbing")
@export var slope_climbing_enabled: bool = true
@export var max_climbable_angle: float = 60.0  # Maximum slope angle in degrees
@export var slope_climb_boost: float = 1.5     # Speed multiplier when climbing
@export var slope_assist_strength: float = 2.0 # How much upward force to add on slopes

@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var camera_bob_enabled: bool = true
@export var camera_bob_intensity: float = 0.1
@export var camera_bob_speed: float = 12.0

@export_group("World Editing")
@export var edit_mode: bool = false
@export var edit_range: float = 5.0
@export var voxel_placement_type: int = 1
@export var show_edit_indicator: bool = true
@export var edit_sphere_color: Color = Color.CYAN
@export var edit_sphere_opacity: float = 0.7

# Internal variables
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_bob_time: float = 0.0
var is_moving: bool = false
var movement_input: Vector3 = Vector3.ZERO  # Used by movement actions

# Edit indicator
var edit_sphere: MeshInstance3D = null
var edit_sphere_material: StandardMaterial3D = null

# Action system
var action_system: Dictionary = {}

@onready var camera: Camera3D = $Camera3D
@onready var voxel_world: VoxelWorld = get_parent()

signal voxel_placed(position: Vector3, voxel_type: int)
signal voxel_removed(position: Vector3)
signal edit_mode_changed(enabled: bool)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Configure CharacterBody3D for optimal slope climbing
	floor_max_angle = deg_to_rad(max_climbable_angle)
	floor_snap_length = 0.8  # Strong snap to help with slopes
	floor_stop_on_slope = false  # Don't stop on slopes
	floor_block_on_wall = false  # Don't block on walls
	
	# Initialize edit indicator sphere
	_setup_edit_sphere()
	
	# Initialize action system
	_setup_action_system()
	
	# Connect signals if voxel_world exists
	if voxel_world and voxel_world is VoxelWorld:
		voxel_placed.connect(_on_voxel_placed)
		voxel_removed.connect(_on_voxel_removed)

func _input(event: InputEvent):
	# Handle mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float):
	# Reset movement input
	movement_input = Vector3.ZERO
	
	# Execute actions
	_execute_actions(delta)
	
	# Apply movement and physics
	handle_movement(delta)
	handle_camera_effects(delta)
	
	# Update edit indicator
	if edit_mode and show_edit_indicator:
		_update_edit_sphere()

func handle_movement(delta: float):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Get movement input from action system
	var direction := movement_input.normalized()
	
	# Handle movement
	if direction != Vector3.ZERO:
		is_moving = true
		
		if is_on_floor():
			# Ground movement with slope climbing
			if slope_climbing_enabled:
				_handle_slope_movement(direction)
			else:
				# Standard flat movement
				velocity.x = direction.x * speed
				velocity.z = direction.z * speed
		else:
			# Air movement
			_handle_air_movement(direction, delta)
	else:
		is_moving = false
		# Apply friction when not moving
		_apply_ground_friction(delta)
	
	move_and_slide()

func _handle_slope_movement(direction: Vector3):
	var floor_normal = get_floor_normal()
	var slope_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
	
	if slope_angle <= 5.0:
		# Essentially flat ground - use normal movement
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	elif slope_angle <= max_climbable_angle:
		# Climbable slope - use slope climbing mechanics
		
		# Project movement onto the slope plane
		# This is the key: we want to move along the slope surface, not into it
		var slope_direction = direction - direction.dot(floor_normal) * floor_normal
		slope_direction = slope_direction.normalized()
		
		# Calculate movement speed with slope boost
		var movement_speed = speed
		if slope_direction.dot(Vector3.UP) > 0.1:  # Moving upward
			movement_speed *= slope_climb_boost
		
		# Apply horizontal movement
		velocity.x = slope_direction.x * movement_speed
		velocity.z = slope_direction.z * movement_speed
		
		# Add upward assistance for steep slopes
		if slope_angle > 25.0 and slope_direction.dot(Vector3.UP) > 0.0:
			# Add upward velocity to help climb steep slopes
			var assist_strength = slope_assist_strength * (slope_angle / max_climbable_angle)
			velocity.y += assist_strength
	else:
		# Too steep to climb - slide down or move along the base
		var horizontal_dir = Vector3(direction.x, 0, direction.z).normalized()
		velocity.x = horizontal_dir.x * speed * 0.5  # Reduced speed on too-steep slopes
		velocity.z = horizontal_dir.z * speed * 0.5

func _handle_air_movement(direction: Vector3, delta: float):
	# Air control with momentum preservation
	velocity.x += direction.x * speed * air_control * delta
	velocity.z += direction.z * speed * air_control * delta
	
	# Clamp air speed to prevent infinite acceleration
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > speed * 1.2:  # Allow slight overspeed
		horizontal_velocity = horizontal_velocity.normalized() * speed * 1.2
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.y

func _apply_ground_friction(delta: float):
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var slope_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
		
		# Reduce friction on slopes to prevent sliding back
		var friction_multiplier = 1.0
		if slope_angle > 15.0:
			friction_multiplier = 0.2  # Very low friction on slopes
		
		velocity.x = move_toward(velocity.x, 0, friction * friction_multiplier * delta)
		velocity.z = move_toward(velocity.z, 0, friction * friction_multiplier * delta)

func _handle_slope_jump():
	var floor_normal = get_floor_normal()
	var slope_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
	
	if slope_angle <= 5.0:
		# Flat ground - normal jump
		velocity.y = jump_velocity
		
		# Add small forward momentum if moving
		if movement_input != Vector3.ZERO:
			var forward_boost = movement_input.normalized() * 0.5
			velocity.x += forward_boost.x
			velocity.z += forward_boost.z
	else:
		# On a slope - jump perpendicular to slope with forward momentum
		var jump_direction = floor_normal.normalized()
		
		# Mix upward jump with slope normal
		var upward_component = Vector3.UP * 0.7
		var slope_component = jump_direction * 0.3
		var final_jump_direction = (upward_component + slope_component).normalized()
		
		# Apply jump velocity
		velocity.y = jump_velocity * final_jump_direction.y
		
		# Add significant forward momentum when jumping on slopes
		if movement_input != Vector3.ZERO:
			var forward_boost = movement_input.normalized() * 2.5  # Strong forward boost
			velocity.x += forward_boost.x
			velocity.z += forward_boost.z

func handle_camera_effects(delta: float):
	if not camera_bob_enabled:
		return
	
	# Simple camera bobbing when moving
	if is_moving and is_on_floor():
		camera_bob_time += delta * camera_bob_speed
		var bob_offset := sin(camera_bob_time) * camera_bob_intensity
		camera.position.y = 1.8 + bob_offset
	else:
		# Smoothly return to neutral position
		camera_bob_time = 0.0
		camera.position.y = move_toward(camera.position.y, 1.8, delta * 2.0)

func toggle_edit_mode():
	edit_mode = !edit_mode
	edit_mode_changed.emit(edit_mode)
	print("Edit mode: ", "ON" if edit_mode else "OFF")
	
	# Show/hide edit sphere based on edit mode
	if edit_sphere:
		edit_sphere.visible = edit_mode and show_edit_indicator
		print("Edit sphere visibility set to: ", edit_sphere.visible)
	else:
		print("Warning: edit_sphere is null in toggle_edit_mode!")
		if edit_mode:
			print("Attempting to recreate edit sphere...")
			_setup_edit_sphere()
			if edit_sphere:
				edit_sphere.visible = edit_mode and show_edit_indicator

func cycle_voxel_type():
	voxel_placement_type += 1
	if voxel_placement_type > 4:  # Now supporting 4 voxel types
		voxel_placement_type = 1
	print("Voxel type: ", get_voxel_type_name(voxel_placement_type))

func get_voxel_type_name(voxel_type: int) -> String:
	match voxel_type:
		1: return "Grass"
		2: return "Dirt"
		3: return "Stone"
		4: return "Ore"
		_: return "Unknown"

# Action system helper methods
func _handle_voxel_placement():
	try_place_voxel()

func _handle_voxel_removal():
	try_remove_voxel()

func _cycle_voxel_type():
	cycle_voxel_type()

func try_place_voxel():
	var hit_result := cast_ray_to_world()
	if hit_result.has("position"):
		var place_pos: Vector3 = hit_result.position + hit_result.normal * 0.5
		voxel_placed.emit(place_pos, voxel_placement_type)
		print("Placed ", get_voxel_type_name(voxel_placement_type), " at ", place_pos)

func try_remove_voxel():
	var hit_result := cast_ray_to_world()
	if hit_result.has("position"):
		var remove_pos: Vector3 = hit_result.position - hit_result.normal * 0.5
		voxel_removed.emit(remove_pos)
		print("Removed voxel at ", remove_pos)

func cast_ray_to_world() -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * edit_range)
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Assume voxel chunks are on layer 1
	
	var result := space_state.intersect_ray(query)
	return result

func _on_voxel_placed(_pos: Vector3, _voxel_type: int):
	if voxel_world:
		# This would be implemented in VoxelWorld to handle voxel placement
		pass

func _on_voxel_removed(_pos: Vector3):
	if voxel_world:
		# This would be implemented in VoxelWorld to handle voxel removal
		pass

# Debug function to show current state
func get_debug_info() -> Dictionary:
	var floor_normal = get_floor_normal() if is_on_floor() else Vector3.UP
	var slope_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP))) if is_on_floor() else 0.0
	
	var info = {
		"position": global_position,
		"velocity": velocity,
		"speed": Vector2(velocity.x, velocity.z).length(),
		"is_on_floor": is_on_floor(),
		"floor_normal": floor_normal,
		"slope_angle": "%.1f°" % slope_angle,
		"can_climb": slope_angle <= max_climbable_angle and slope_climbing_enabled,
		"is_climbing": slope_angle > 5.0 and slope_angle <= max_climbable_angle and is_moving,
		"edit_mode": edit_mode,
		"voxel_type": get_voxel_type_name(voxel_placement_type),
		"mouse_mode": Input.get_mouse_mode(),
		"movement_input": movement_input
	}
	
	return info

func _setup_action_system():
	# Simple action system without class dependencies
	action_system = {
		"movement_actions": ["move_forward", "move_backward", "move_left", "move_right"],
		"jump_action": "jump",
		"edit_actions": ["toggle_edit_mode", "place_voxel", "remove_voxel", "cycle_voxel_type"]
	}

func _execute_actions(_delta: float):
	# Handle movement actions
	var camera_basis = camera.global_basis
	
	# Forward/backward movement
	if Input.is_action_pressed("move_forward"):
		var forward = camera_basis * Vector3.FORWARD
		forward.y = 0
		movement_input += forward.normalized()
	
	if Input.is_action_pressed("move_backward"):
		var backward = camera_basis * Vector3.BACK
		backward.y = 0
		movement_input += backward.normalized()
	
	# Left/right movement
	if Input.is_action_pressed("move_left"):
		var left = camera_basis * Vector3.LEFT
		left.y = 0
		movement_input += left.normalized()
	
	if Input.is_action_pressed("move_right"):
		var right = camera_basis * Vector3.RIGHT
		right.y = 0
		movement_input += right.normalized()
	
	# Jump action with slope-aware mechanics
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if slope_climbing_enabled:
			_handle_slope_jump()
		else:
			velocity.y = jump_velocity
	
	# Edit mode actions (only process if edit mode is active for some)
	if Input.is_action_just_pressed("toggle_edit_mode"):
		toggle_edit_mode()  # Use the toggle function instead of inline code
	
	if edit_mode:
		if Input.is_action_just_pressed("place_voxel"):
			_handle_voxel_placement()
		elif Input.is_action_just_pressed("remove_voxel"):
			_handle_voxel_removal()
		elif Input.is_action_just_pressed("cycle_voxel_type"):
			_cycle_voxel_type()

# Edit sphere setup and management
func _setup_edit_sphere():
	# Clean up existing sphere if it exists
	if edit_sphere:
		edit_sphere.queue_free()
		edit_sphere = null
	
	# Create sphere mesh - smaller and more subtle
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.4  # Smaller radius
	sphere_mesh.height = 0.8  # Height should be 2x radius
	sphere_mesh.rings = 8
	sphere_mesh.radial_segments = 12
	
	# Create material with good visibility
	edit_sphere_material = StandardMaterial3D.new()
	edit_sphere_material.albedo_color = edit_sphere_color
	edit_sphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edit_sphere_material.flags_transparent = true
	edit_sphere_material.no_depth_test = true  # Always visible through terrain
	edit_sphere_material.flags_unshaded = true  # Bright and visible
	edit_sphere_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	edit_sphere_material.rim_enabled = true  # Add rim lighting for better visibility
	edit_sphere_material.rim_amount = 0.5
	
	# Create mesh instance
	edit_sphere = MeshInstance3D.new()
	edit_sphere.mesh = sphere_mesh
	edit_sphere.material_override = edit_sphere_material
	edit_sphere.visible = false  # Start hidden
	edit_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Add to scene
	add_child(edit_sphere)

func _update_edit_sphere():
	if not edit_sphere:
		_setup_edit_sphere()
		if not edit_sphere:
			return
	
	var hit_result = cast_ray_to_world()
	if hit_result.has("position"):
		# Show different positions for place vs remove
		var place_pos: Vector3 = hit_result.position + hit_result.normal * 0.5
		var remove_pos: Vector3 = hit_result.position - hit_result.normal * 0.5
		
		# Use placement position by default, but could change based on action
		edit_sphere.global_position = place_pos
		edit_sphere.visible = true
		
		# Update material color based on voxel type and action
		_update_sphere_color()
		
		# Add subtle pulsing animation
		var time = Time.get_time_dict_from_system()
		var pulse = 1.0 + sin(time.second * 6.0) * 0.2  # Subtle pulse
		edit_sphere.scale = Vector3.ONE * pulse
	else:
		# No valid edit position - hide sphere
		edit_sphere.visible = false

func _update_sphere_color():
	if not edit_sphere_material:
		return
	
	# Set bright, highly visible colors based on voxel type
	var base_color: Color
	match voxel_placement_type:
		1: base_color = Color.LIME        # Bright green for grass
		2: base_color = Color.ORANGE      # Bright orange for dirt
		3: base_color = Color.CYAN        # Bright cyan for stone
		4: base_color = Color.YELLOW      # Bright yellow for ore
		_: base_color = Color.MAGENTA     # Bright magenta for unknown
	
	# Apply transparency but keep it quite visible
	base_color.a = 0.8  # More opaque than before
	edit_sphere_material.albedo_color = base_color
