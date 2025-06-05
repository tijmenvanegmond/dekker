class_name PlayerController
extends CharacterBody3D

# Advanced player controller with world editing capabilities
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

@onready var camera: Camera3D = $Camera3D
@onready var voxel_world: VoxelWorld = get_parent()

signal voxel_placed(position: Vector3, voxel_type: int)
signal voxel_removed(position: Vector3)
signal edit_mode_changed(enabled: bool)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
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
	
	# Toggle edit mode
	if event.is_action_pressed("toggle_edit_mode"):
		toggle_edit_mode()
	
	# World editing (only when in edit mode)
	if edit_mode and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("place_voxel"):
			try_place_voxel()
		elif event.is_action_pressed("remove_voxel"):
			try_remove_voxel()
		elif event.is_action_pressed("cycle_voxel_type"):
			cycle_voxel_type()

func _physics_process(delta: float):
	handle_movement(delta)
	handle_camera_effects(delta)

func handle_movement(delta: float):
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get input direction using proper movement actions
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1.0
	
	input_dir = input_dir.normalized()
	
	# Convert input to world direction
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
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
	return {
		"position": global_position,
		"velocity": velocity,
		"is_on_floor": is_on_floor(),
		"edit_mode": edit_mode,
		"voxel_type": get_voxel_type_name(voxel_placement_type),
		"mouse_mode": Input.get_mouse_mode()
	}
