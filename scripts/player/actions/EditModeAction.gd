## Edit Mode Action
## Handles toggling edit mode and voxel editing
class_name EditModeAction
extends PlayerAction

func _init(action_name: String = "toggle_edit_mode", input_name: String = "toggle_edit_mode", desc: String = "Toggle edit mode"):
	super(action_name, input_name, desc)

func execute(player: CharacterBody3D, delta: float) -> void:
	if not can_execute(player):
		return
	
	if is_just_pressed():
		var player_controller = player as PlayerController
		if player_controller:
			player_controller.edit_mode = !player_controller.edit_mode
			print("Edit mode: ", "ON" if player_controller.edit_mode else "OFF")
