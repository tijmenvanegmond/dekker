## Simple Action System
## Single-file action system for better compatibility
class_name SimpleActionSystem
extends RefCounted

# Action types
enum ActionType {
	MOVEMENT,
	JUMP,
	EDIT_MODE_TOGGLE,
	VOXEL_PLACE,
	VOXEL_REMOVE,
	VOXEL_TYPE_CYCLE
}

# Action definition structure
class ActionDefinition:
	var name: String
	var type: ActionType
	var input_action: String
	var direction: Vector3 = Vector3.ZERO
	var enabled: bool = true
	
	func _init(action_name: String, action_type: ActionType, input_name: String, move_dir: Vector3 = Vector3.ZERO):
		name = action_name
		type = action_type
		input_action = input_name
		direction = move_dir

# Internal variables
var actions: Array[ActionDefinition] = []
var action_map: Dictionary = {}

func _init():
	_setup_default_actions()

func _setup_default_actions():
	# Movement actions
	add_action("move_forward", ActionType.MOVEMENT, "move_forward", Vector3.FORWARD)
	add_action("move_backward", ActionType.MOVEMENT, "move_backward", Vector3.BACK)
	add_action("move_left", ActionType.MOVEMENT, "move_left", Vector3.LEFT)
	add_action("move_right", ActionType.MOVEMENT, "move_right", Vector3.RIGHT)
	
	# Other actions
	add_action("jump", ActionType.JUMP, "jump")
	add_action("toggle_edit_mode", ActionType.EDIT_MODE_TOGGLE, "toggle_edit_mode")
	add_action("place_voxel", ActionType.VOXEL_PLACE, "place_voxel")
	add_action("remove_voxel", ActionType.VOXEL_REMOVE, "remove_voxel")
	add_action("cycle_voxel_type", ActionType.VOXEL_TYPE_CYCLE, "cycle_voxel_type")

func add_action(name: String, type: ActionType, input: String, direction: Vector3 = Vector3.ZERO):
	var action = ActionDefinition.new(name, type, input, direction)
	actions.append(action)
	action_map[name] = action

func execute_actions(player: CharacterBody3D, delta: float):
	var player_controller = player as PlayerController
	if not player_controller:
		return
	
	# Process all actions
	for action in actions:
		if not action.enabled:
			continue
		
		match action.type:
			ActionType.MOVEMENT:
				_handle_movement_action(action, player_controller, delta)
			ActionType.JUMP:
				_handle_jump_action(action, player_controller)
			ActionType.EDIT_MODE_TOGGLE:
				_handle_edit_mode_action(action, player_controller)
			ActionType.VOXEL_PLACE:
				_handle_voxel_place_action(action, player_controller)
			ActionType.VOXEL_REMOVE:
				_handle_voxel_remove_action(action, player_controller)
			ActionType.VOXEL_TYPE_CYCLE:
				_handle_voxel_type_cycle_action(action, player_controller)

func _handle_movement_action(action: ActionDefinition, player: PlayerController, _delta: float):
	if Input.is_action_pressed(action.input_action):
		var strength = Input.get_action_strength(action.input_action)
		var camera_basis = player.camera.global_basis
		var world_direction = camera_basis * action.direction
		world_direction.y = 0  # Keep movement horizontal
		world_direction = world_direction.normalized()
		player.movement_input += world_direction * strength

func _handle_jump_action(action: ActionDefinition, player: PlayerController):
	if Input.is_action_just_pressed(action.input_action) and player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _handle_edit_mode_action(action: ActionDefinition, player: PlayerController):
	if Input.is_action_just_pressed(action.input_action):
		player.edit_mode = !player.edit_mode
		print("Edit mode: ", "ON" if player.edit_mode else "OFF")

func _handle_voxel_place_action(action: ActionDefinition, player: PlayerController):
	if player.edit_mode and Input.is_action_just_pressed(action.input_action):
		player._handle_voxel_placement()

func _handle_voxel_remove_action(action: ActionDefinition, player: PlayerController):
	if player.edit_mode and Input.is_action_just_pressed(action.input_action):
		player._handle_voxel_removal()

func _handle_voxel_type_cycle_action(action: ActionDefinition, player: PlayerController):
	if player.edit_mode and Input.is_action_just_pressed(action.input_action):
		player._cycle_voxel_type()

func get_action_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for action in actions:
		info.append({
			"name": action.name,
			"type": ActionType.keys()[action.type],
			"enabled": action.enabled,
			"input": action.input_action
		})
	return info

func set_action_enabled(action_name: String, enabled: bool) -> bool:
	if action_name in action_map:
		action_map[action_name].enabled = enabled
		return true
	return false
