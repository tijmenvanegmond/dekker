## Voxel Placement Action
## Handles placing voxels in the world
class_name VoxelPlaceAction
extends PlayerAction

func _init(action_name: String = "place_voxel", input_name: String = "place_voxel", desc: String = "Place voxel"):
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
			player_controller._handle_voxel_placement()
