## Voxel Type Cycle Action
## Handles cycling through voxel types for placement
class_name VoxelTypeCycleAction
extends PlayerAction

func _init(action_name: String = "cycle_voxel_type", input_name: String = "cycle_voxel_type", desc: String = "Cycle voxel type"):
	super(action_name, input_name, desc)

func can_execute(player: CharacterBody3D) -> bool:
	var player_controller = player as PlayerController
	return super.can_execute(player) and player_controller and player_controller.edit_mode

func execute(player: CharacterBody3D, delta: float) -> void:
	if not can_execute(player):
		return
	
	if is_just_pressed():
		var player_controller = player as PlayerController
		if player_controller:
			player_controller._cycle_voxel_type()
