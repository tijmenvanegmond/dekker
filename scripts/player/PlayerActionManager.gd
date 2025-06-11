## Player Action Manager
## Manages and executes all player actions
class_name PlayerActionManager
extends RefCounted

var actions: Array[PlayerAction] = []
var action_map: Dictionary = {}

func _init():
	_setup_default_actions()

## Setup default actions for the player
func _setup_default_actions():
	# Movement actions
	add_action(MovementAction.new("move_forward", Vector3.FORWARD, "move_forward", "Move forward"))
	add_action(MovementAction.new("move_backward", Vector3.BACK, "move_backward", "Move backward"))
	add_action(MovementAction.new("move_left", Vector3.LEFT, "move_left", "Move left"))
	add_action(MovementAction.new("move_right", Vector3.RIGHT, "move_right", "Move right"))
	
	# Jump action
	add_action(JumpAction.new())
	
	# Edit mode actions
	add_action(EditModeAction.new())
	add_action(VoxelPlaceAction.new())
	add_action(VoxelRemoveAction.new())
	add_action(VoxelTypeCycleAction.new())

## Add a new action to the manager
func add_action(action: PlayerAction) -> void:
	actions.append(action)
	action_map[action.name] = action

## Remove an action by name
func remove_action(action_name: String) -> bool:
	if action_name in action_map:
		var action = action_map[action_name]
		actions.erase(action)
		action_map.erase(action_name)
		return true
	return false

## Get an action by name
func get_action(action_name: String) -> PlayerAction:
	return action_map.get(action_name, null)

## Enable/disable an action
func set_action_enabled(action_name: String, enabled: bool) -> bool:
	var action = get_action(action_name)
	if action:
		action.is_enabled = enabled
		return true
	return false

## Execute all applicable actions for the current frame
func execute_actions(player: CharacterBody3D, delta: float) -> void:
	for action in actions:
		if action.can_execute(player):
			action.execute(player, delta)

## Get list of all action names and descriptions for debug display
func get_action_info() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for action in actions:
		info.append({
			"name": action.name,
			"description": action.description,
			"enabled": action.is_enabled,
			"input": action.input_action
		})
	return info
