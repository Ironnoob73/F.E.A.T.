extends CharacterBody3D

const SPEED = 5
const DASH = 8
const CROUCH = 3
const CROUCH_depth = 0.5
const JUMP_VELOCITY = 8

const ACCELERATION = 0.1
const FRICTION = 0.3

@onready var player_collision = $PlayerColl
@onready var player_camera = $PlayerCam
@onready var standing_detected= $StandingDetected
@onready var pause_menu = $Pause_menu
@onready var inventory_menu = $Inventory

@onready var first_person_cam = $PlayerCam/FirstPersonHandled/SubViewport/FirstPersonCam
@onready var hand_held = $PlayerCam/FirstPersonHandled/SubViewport/FirstPersonCam/HandHeld

@onready var interact_ray = $PlayerCam/InteractRay

var INERTIA:Vector2 = Vector2.ZERO

var current_menu = "HUD"

@export var Inventory : InventoryClass
var current_hotbar : int = 0
var handheld_tool : EqMetaClass
@onready var HUD_hotbar = $HudHotbar

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# Lock Mouse.
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	pause_menu.hide()
	inventory_menu.hide()
	refresh_handheld(current_hotbar)
	
func _input(event):
	# Player camera.
	if event is InputEventMouseMotion and current_menu == "HUD":
		rotate_y(-deg_to_rad(event.relative.x * Global.mouse_sens))
		player_camera.rotate_x(-deg_to_rad(event.relative.y * Global.mouse_sens))
		player_camera.rotation.x = clamp(player_camera.rotation.x,deg_to_rad(-90),deg_to_rad(90))
		
func _unhandled_input(_event):
	# Pause.
	if Input.is_action_just_pressed("pause"):
		match current_menu :
			"HUD":
				current_menu = "Pause"
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				pause_menu.show()
			"Inventory":
				inventory_menu.close_inventory()
			"ToolSetting":
				current_menu = "HUD"
				hand_held.get_child(0).setting_off()
		print(current_menu)
	# Inventory
	if Input.is_action_just_pressed("inventory"):
		match current_menu :
			"HUD":
				current_menu = "Inventory"
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				inventory_menu.open_inventory()
			"Inventory":
				inventory_menu.close_inventory()
			"ToolSetting":
				hand_held.get_child(0).setting_off()
				current_menu = "Inventory"
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				inventory_menu.open_inventory()
	#Hotbar
	if !Input.is_action_pressed("tool_function_switch") and current_menu == "HUD":
		if Input.is_action_just_pressed("hotbar_tool_0") :
			current_hotbar = 0
			refresh_handheld(current_hotbar)
		if Input.is_action_just_pressed("hotbar_tool_1") :
			current_hotbar = 1
			refresh_handheld(current_hotbar)
		if Input.is_action_just_pressed("hotbar_tool_2") :
			current_hotbar = 2
			refresh_handheld(current_hotbar)
		if Input.is_action_just_pressed("hotbar_tool_3") :
			current_hotbar = 3
			refresh_handheld(current_hotbar)
		if Input.is_action_just_pressed("hotbar_tool_4") :
			current_hotbar = 4
			refresh_handheld(current_hotbar)
			

#from : https://github.com/majikayogames/godot-character-controller-stairs/blob/main/entities/Player/Player.gd
var _was_on_floor_last_frame = false
var _snapped_to_stairs_last_frame = false
func _snap_down_to_stairs_check():
	var did_snap = false
	if not is_on_floor() and velocity.y <= 0 and (_was_on_floor_last_frame or _snapped_to_stairs_last_frame) and $StairsBelowRayCast3D.is_colliding():
		var body_test_result = PhysicsTestMotionResult3D.new()
		var params = PhysicsTestMotionParameters3D.new()
		var max_step_down = -0.5
		params.from = self.global_transform
		params.motion = Vector3(0,max_step_down,0)
		if PhysicsServer3D.body_test_motion(self.get_rid(), params, body_test_result):
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true

	_was_on_floor_last_frame = is_on_floor()
	_snapped_to_stairs_last_frame = did_snap
	
@onready var _initial_separation_ray_dist = abs($StepUpSeparationRay_F.position.z)
var _last_xz_vel : Vector3 = Vector3(0,0,0)
func _rotate_step_up_separation_ray():
	var xz_vel = velocity * Vector3(1,0,1)
	
	if xz_vel.length() < 0.1:
		xz_vel = _last_xz_vel
	else:
		_last_xz_vel = xz_vel
		
	var xz_f_ray_pos = xz_vel.normalized() * _initial_separation_ray_dist
	$StepUpSeparationRay_F.global_position.x = self.global_position.x + xz_f_ray_pos.x
	$StepUpSeparationRay_F.global_position.z = self.global_position.z + xz_f_ray_pos.z

	var xz_l_ray_pos = xz_f_ray_pos.rotated(Vector3(0,1.0,0), deg_to_rad(-50))
	$StepUpSeparationRay_L.global_position.x = self.global_position.x + xz_l_ray_pos.x
	$StepUpSeparationRay_L.global_position.z = self.global_position.z + xz_l_ray_pos.z
	
	var xz_r_ray_pos = xz_f_ray_pos.rotated(Vector3(0,1.0,0), deg_to_rad(50))
	$StepUpSeparationRay_R.global_position.x = self.global_position.x + xz_r_ray_pos.x
	$StepUpSeparationRay_R.global_position.z = self.global_position.z + xz_r_ray_pos.z
	
	# To prevent character from running up walls, we do a check for how steep
	# the slope in contact with our separation rays is
	$StepUpSeparationRay_F/RayCast3D.force_raycast_update()
	$StepUpSeparationRay_L/RayCast3D.force_raycast_update()
	$StepUpSeparationRay_R/RayCast3D.force_raycast_update()
	var max_slope_ang_dot = Vector3(0,1,0).rotated(Vector3(1.0,0,0), self.floor_max_angle).dot(Vector3(0,1,0))
	var any_too_steep = false
	if $StepUpSeparationRay_F/RayCast3D.is_colliding() and $StepUpSeparationRay_F/RayCast3D.get_collision_normal().dot(Vector3(0,1,0)) < max_slope_ang_dot:
		any_too_steep = true
	if $StepUpSeparationRay_L/RayCast3D.is_colliding() and $StepUpSeparationRay_L/RayCast3D.get_collision_normal().dot(Vector3(0,1,0)) < max_slope_ang_dot:
		any_too_steep = true
	if $StepUpSeparationRay_R/RayCast3D.is_colliding() and $StepUpSeparationRay_R/RayCast3D.get_collision_normal().dot(Vector3(0,1,0)) < max_slope_ang_dot:
		any_too_steep = true
	
	$StepUpSeparationRay_F.disabled = any_too_steep
	$StepUpSeparationRay_L.disabled = any_too_steep
	$StepUpSeparationRay_R.disabled = any_too_steep
	
var _cur_frame = 0
@export var _jump_frame_grace = 5
var _last_frame_was_on_floor = -_jump_frame_grace - 1
			
func _physics_process(_delta):
	# Record Inerita & Add the gravity.
	if is_on_floor():
		INERTIA.x = velocity.x
		INERTIA.y = velocity.z
	else:
		velocity.y -= gravity * 0.05

	# Handle Jump.
	_cur_frame += 1
	if is_on_floor():
		_last_frame_was_on_floor = _cur_frame
	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or _cur_frame - _last_frame_was_on_floor <= _jump_frame_grace):
		velocity.y = JUMP_VELOCITY
	
	# Move Input.
	var input_vec = Vector3.ZERO
	input_vec.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vec.z = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vec = (transform.basis * Vector3(input_vec.x,0,input_vec.z)).normalized()
	
	var isDash = 0
	isDash = Input.get_action_strength("shift")
	var isCrouch = 0
	isCrouch = Input.get_action_strength("crouch")
	
	# Move.
	velocity.x = lerp(velocity.x,input_vec.x * (SPEED + isDash * DASH * (1 - isCrouch) - isCrouch * CROUCH ) , ACCELERATION)
	velocity.z = lerp(velocity.z,input_vec.z * (SPEED + isDash * DASH * (1 - isCrouch) - isCrouch * CROUCH ) , ACCELERATION)
	# Stop.
	if velocity.x * input_vec.x <= 0 and velocity.x!=0:
		if is_on_floor():	velocity.x = lerp(velocity.x,0.0,FRICTION)
		else:				velocity.x = lerp(INERTIA.x,0.0,FRICTION)
	if velocity.z * input_vec.z <= 0 and velocity.z!=0:
		if is_on_floor():	velocity.z = lerp(velocity.z,0.0,FRICTION)
		else:				velocity.z = lerp(INERTIA.y,0.0,FRICTION)
	
	# Crouch.
	if Input.is_action_pressed("crouch"):
		player_collision.shape.height = lerp(player_collision.shape.height,1.8 * CROUCH_depth,0.5)
		player_camera.position.y = lerp(player_camera.position.y,0.5 * CROUCH_depth,0.5)
		$StepUpSeparationRay_F.shape.length = lerp($StepUpSeparationRay_F.shape.length,0.0,0.5)
		$StepUpSeparationRay_L.shape.length = lerp($StepUpSeparationRay_L.shape.length,0.0,0.5)
		$StepUpSeparationRay_R.shape.length = lerp($StepUpSeparationRay_R.shape.length,0.0,0.5)
	elif !standing_detected.is_colliding():
		player_collision.shape.height = lerp(player_collision.shape.height,1.8,0.5)
		player_camera.position.y = lerp(player_camera.position.y,0.5,0.5)
		$StepUpSeparationRay_F.shape.length = lerp($StepUpSeparationRay_F.shape.length,0.9,0.1)
		$StepUpSeparationRay_L.shape.length = lerp($StepUpSeparationRay_L.shape.length,0.9,0.1)
		$StepUpSeparationRay_R.shape.length = lerp($StepUpSeparationRay_R.shape.length,0.9,0.1)
	
	_rotate_step_up_separation_ray()
	move_and_slide()
	_snap_down_to_stairs_check()

	#Scroll hotbar
	if current_menu == "HUD" and !Input.is_action_pressed("tool_function_switch"):
		if Input.is_action_just_pressed("roll_down"):
			if current_hotbar < 4 :	current_hotbar += 1
			else :	current_hotbar = 0
			refresh_handheld(current_hotbar)
		elif Input.is_action_just_pressed("roll_up"):
			if current_hotbar > 0 :	current_hotbar -= 1
			else :	current_hotbar = 4
			refresh_handheld(current_hotbar)
		
func _process(_delta):
	first_person_cam.global_transform = player_camera.global_transform
	
func refresh_handheld(index:int):
	handheld_tool = Inventory.ToolHotbar[current_hotbar]
	if index == current_hotbar:
		if hand_held.get_children():
			hand_held.get_child(0).queue_free()
			hand_held.get_child(0).free()
			interact_ray.affect_terrain = "none"
		if handheld_tool:
			if handheld_tool.equipment.scene:
				hand_held.add_child(handheld_tool.equipment.scene.instantiate())
				interact_ray.affect_terrain = handheld_tool.equipment.affect_terrain
				hand_held.get_child(0)._tool_init()
			else :
				var handheld_model = MeshInstance3D.new()
				handheld_model.mesh = handheld_tool.equipment.model
				hand_held.add_child(handheld_model)
			refresh_handheld_info()
		else :
			HUD_hotbar.set_info(current_hotbar)
func refresh_handheld_info():
	HUD_hotbar.set_info(current_hotbar,\
		handheld_tool.equipment.name0,\
		handheld_tool.equipment.icon,\
		((handheld_tool.equipment.durability - handheld_tool.damage)/handheld_tool.equipment.durability)*100)
