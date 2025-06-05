## Jump Action
## Handles player jumping
class_name JumpAction
extends PlayerAction

var jump_force: float = 15.0

func _init(action_name: String = "jump", input_name: String = "jump", desc: String = "Jump", force: float = 15.0):
	super(action_name, input_name, desc)
	jump_force = force

func execute(player: CharacterBody3D, delta: float) -> void:
	if not can_execute(player):
		return
	
	if is_just_pressed():
		var player_controller = player as PlayerController
		if player_controller and player_controller.is_on_floor():
			player_controller.velocity.y = jump_force
