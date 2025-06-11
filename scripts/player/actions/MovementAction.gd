## Movement Action System
## Handles player movement actions
class_name MovementAction
extends PlayerAction

var direction: Vector3
var speed_multiplier: float = 1.0

func _init(action_name: String, move_direction: Vector3, input_name: String = "", desc: String = "", speed_mult: float = 1.0):
	super(action_name, input_name, desc)
	direction = move_direction
	speed_multiplier = speed_mult

func execute(player: CharacterBody3D, delta: float) -> void:
	if not can_execute(player):
		return
	
	var strength = get_input_strength()
	if strength > 0:
		var player_controller = player as PlayerController
		if player_controller:
			# Transform direction relative to camera
			var camera_basis = player_controller.camera.global_basis
			var world_direction = camera_basis * direction
			world_direction.y = 0  # Keep movement horizontal
			world_direction = world_direction.normalized()
			
			player_controller.movement_input += world_direction * strength * speed_multiplier
