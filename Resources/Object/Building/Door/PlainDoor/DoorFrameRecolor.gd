@tool
extends StaticBody3D

@onready var mesh = $DoorFrame
@export var mesh_color : Color = Color(0,0,0,0):
	set(color):
		mesh_color = color
		if Engine.is_editor_hint():
			color_setter()
@export var mesh_material : Material = preload("res://Resources/Material/Tree.tres"):
	set(material):
		mesh_material = material
		if Engine.is_editor_hint():
			material_setter()
@export_enum("none","dark","light") var occlusion : String = "dark":
	set(state):
		occlusion = state
		occlusion_setter()
@onready var occlusion_obj: MeshInstance3D = $Occlusion
@onready var occlusion_light_obj: MeshInstance3D = $Occlusion_light

func _ready():
	if mesh_color != Color(0,0,0,0) :	MaterialUtil.recolor(mesh,mesh_color)
	if mesh_material : MaterialUtil.change_material(mesh,mesh_material)
	occlusion_setter()
	
func color_setter():
	MaterialUtil.recolor(mesh,mesh_color)
func material_setter():
	MaterialUtil.change_material(mesh,mesh_material)
	
func occlusion_setter():
	if is_instance_valid(occlusion_obj) && is_instance_valid(occlusion_light_obj) :
		match occlusion:
			"none" :
				occlusion_obj.visible = false
				occlusion_light_obj.visible = false
			"dark" :
				occlusion_obj.visible = true
				occlusion_light_obj.visible = false
			"light" :
				occlusion_light_obj.visible = true
				occlusion_obj.visible = false
