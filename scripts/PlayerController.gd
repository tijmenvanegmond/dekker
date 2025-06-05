class_name PlayerController
extends CharacterBody3D

# Advanced player controller with world editing capabilities and action system
@export_group("Movement")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var air_control: float = 0.3
@export var friction: float = 10.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var camera_bob_enabled: bool = true
@export var camera_bob_intensity: float = 0.1
@export var camera_bob_speed: float = 12.0

@export_group("World Editing")
@export var edit_mode: bool = false
@export var edit_range: float = 5.0
@export var voxel_placement_type: int = 1

# Internal variables
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_bob_time: float = 0.0
var is_moving: bool = false
var movement_input: Vector3 = Vector3.ZERO  # Used by movement actions

# Action system
var action_system: Dictionary = {}

@onready var camera: Camera3D = $Camera3D
@onready var voxel_world: VoxelWorld = get_parent()

signal voxel_placed(position: Vector3, voxel_type: int)
signal voxel_removed(position: Vector3)
signal edit_mode_changed(enabled: bool)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
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

func handle_movement(delta: float):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Movement input is now handled by action system
	var direction := movement_input.normalized()
	
	# Apply movement
	if direction != Vector3.ZERO:
		is_moving = true
		# Different movement behavior based on ground contact
		if is_on_floor():
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			# Air control
			velocity.x += direction.x * speed * air_control * delta
			velocity.z += direction.z * speed * air_control * delta
			# Clamp air speed
			var horizontal_velocity := Vector2(velocity.x, velocity.z)
			if horizontal_velocity.length() > speed:
				horizontal_velocity = horizontal_velocity.normalized() * speed
				velocity.x = horizontal_velocity.x
				velocity.z = horizontal_velocity.y
	else:
		is_moving = false
		# Apply friction
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, friction * delta)
			velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	move_and_slide()

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
	var info = {
		"position": global_position,
		"velocity": velocity,
		"is_on_floor": is_on_floor(),
		"edit_mode": edit_mode,
		"voxel_type": get_voxel_type_name(voxel_placement_type),
		"mouse_mode": Input.get_mouse_mode(),
		"movement_input": movement_input,
		"action_system": "Inline Action System Active"
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
	
	# Jump action
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Edit mode actions (only process if edit mode is active for some)
	if Input.is_action_just_pressed("toggle_edit_mode"):
		edit_mode = !edit_mode
		edit_mode_changed.emit(edit_mode)
		print("Edit mode: ", "ON" if edit_mode else "OFF")
	
	if edit_mode:
		if Input.is_action_just_pressed("place_voxel"):
			_handle_voxel_placement()
		elif Input.is_action_just_pressed("remove_voxel"):
			_handle_voxel_removal()
		elif Input.is_action_just_pressed("cycle_voxel_type"):
			_cycle_voxel_type()
