extends StaticBody3D

@onready var _button = $Button

func _ready():
	_state_change()

func _on_switch_scene_interact_signal() -> void:
	_state_change()
		
func _state_change():
	if get_parent().state :	_button.rotation.x = deg_to_rad(10)
	else :		_button.rotation.x = deg_to_rad(-10)
