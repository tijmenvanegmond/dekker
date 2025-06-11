## Player Action System
## Base class for all player actions
class_name PlayerAction
extends RefCounted

var name: String
var input_action: String
var description: String
var is_enabled: bool = true

func _init(action_name: String, input_name: String = "", desc: String = ""):
	name = action_name
	input_action = input_name if input_name != "" else action_name
	description = desc

## Execute the action - override in subclasses
func execute(player: CharacterBody3D, delta: float) -> void:
	pass

## Check if action should be executed - override for custom conditions
func can_execute(player: CharacterBody3D) -> bool:
	return is_enabled

## Get input strength (for analog inputs like movement)
func get_input_strength() -> float:
	if Input.is_action_pressed(input_action):
		return Input.get_action_strength(input_action)
	return 0.0

## Check if action was just pressed
func is_just_pressed() -> bool:
	return Input.is_action_just_pressed(input_action)

## Check if action is currently pressed
func is_pressed() -> bool:
	return Input.is_action_pressed(input_action)

## Check if action was just released
func is_just_released() -> bool:
	return Input.is_action_just_released(input_action)
