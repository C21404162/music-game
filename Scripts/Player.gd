extends CharacterBody3D

#movement
const WALK_SPEED = 3.5
const SPRINT_SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSITIVITY = 0.005
const MAX_JUMP_CHARGE_TIME = 1.0 
const MIN_CHARGE_FOR_BOOST = 0.3
const MAX_JUMP_BOOST = 1.5 

#collision layers
const LAYER_WORLD = 1
const LAYER_HANDS = 2
const LAYER_PLAYER = 4

#physics stuff
@export var hand_smoothing = 35.0
@export var reach_distance = 0.7
@export var reach_speed = 12.5
@export var climb_force = 7.0
@export var hang_offset = Vector3(0, -1.8, 0)

#nodes
@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var left_hand = $lefthand
@onready var right_hand = $righthand
@onready var grab_sound = $"../grabsound"
@onready var hand_fx = $"../Map/GPUParticles3D"


#climb variables
var left_hand_initial_offset: Vector3
var right_hand_initial_offset: Vector3
var left_hand_reaching = false
var right_hand_reaching = false
var left_hand_grabbing = false
var right_hand_grabbing = false
var grab_point_left: Vector3
var grab_point_right: Vector3
var is_charging_jump = false
var jump_charge_time = 0.0
var noclip_enabled = false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	
	#cam setup
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	setup_hands()
	left_hand_initial_offset = left_hand.global_position - camera.global_position
	right_hand_initial_offset = right_hand.global_position - camera.global_position

func setup_hands():
	left_hand.gravity_scale = 0
	right_hand.gravity_scale = 0
	left_hand.collision_layer = LAYER_HANDS
	left_hand.collision_mask = LAYER_WORLD
	right_hand.collision_layer = LAYER_HANDS
	right_hand.collision_mask = LAYER_WORLD
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD
	
	left_hand.contact_monitor = true
	right_hand.contact_monitor = true
	left_hand.max_contacts_reported = 1
	right_hand.max_contacts_reported = 1

func _unhandled_input(event):
	
	if event is InputEventMouseMotion:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				left_hand_reaching = event.pressed
				if !event.pressed: left_hand_grabbing = false
			MOUSE_BUTTON_RIGHT:
				right_hand_reaching = event.pressed
				if !event.pressed: right_hand_grabbing = false
	
	#noclip toggle
	if event.is_action_pressed("noclip"):
		noclip_enabled = !noclip_enabled
		if noclip_enabled:
			collision_mask = 0 
		else:
			collision_mask = LAYER_WORLD

func _physics_process(delta):
	check_grab()
	
	if noclip_enabled:
		handle_noclip(delta)
	elif left_hand_grabbing or right_hand_grabbing:
		handle_climbing(delta)
	else:
		handle_movement(delta)
	
	update_hands(delta)
	move_and_slide()

func handle_noclip(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var noclip_speed = SPRINT_SPEED * 2
	var vertical_input = Input.get_action_strength("jump") - Input.get_action_strength("crouch")
	velocity = direction * noclip_speed
	velocity.y = vertical_input * noclip_speed

func handle_movement(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
		var input_dir = Input.get_vector("left", "right", "up", "down")
		var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		
		if direction:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 2.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 2.0)
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	
	var speed = SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	#crouch
	if Input.is_action_pressed("crouch"):
		speed*= 0.6
	
	#lerp
	if direction:
		if is_on_floor():
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 12.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 12.0)
	else:
		velocity.x = lerp(velocity.x, 0.0, delta * 10.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 10.0)

func handle_climbing(delta):
	# Reset horizontal velocity when grabbing
	velocity.x = 0
	velocity.z = 0
	velocity.y = 0
	
	var forward_dir = camera.global_transform.basis.z
	
	#jump charge
	if Input.is_action_pressed("jump"):
		is_charging_jump = true
		jump_charge_time += delta
		jump_charge_time = min(jump_charge_time, MAX_JUMP_CHARGE_TIME)
	if Input.is_action_just_released("jump"):
		if is_charging_jump:
			var charge_ratio = jump_charge_time / MAX_JUMP_CHARGE_TIME
			var jump_boost = 1.0 + (charge_ratio * (MAX_JUMP_BOOST - 1.0))
			if jump_charge_time >= MIN_CHARGE_FOR_BOOST:
				left_hand_grabbing = false
				right_hand_grabbing = false
				velocity = -forward_dir * (SPRINT_SPEED * jump_boost)
				velocity.y = JUMP_VELOCITY * jump_boost
			
			is_charging_jump = false
			jump_charge_time = 0.0
			
func check_grab():
	#if hand reaching+made contact+not grabbing anything else
	if left_hand_reaching and left_hand.get_contact_count() > 0 and !left_hand_grabbing:
		grab_point_left = left_hand.global_position
		left_hand_grabbing = true
		
		grab_sound.play()
		
	#if hand reaching+made contact+not grabbing anything else
	if right_hand_reaching and right_hand.get_contact_count() > 0 and !right_hand_grabbing:
		grab_point_right = right_hand.global_position
		right_hand_grabbing = true

		grab_sound.play()
	
func update_hands(delta):
	var cam_basis = camera.global_transform.basis
	
	#if grab move to grab point
	#if reaching extend from camera
	#if not grab return to default
	var left_target = grab_point_left if left_hand_grabbing else \
		camera.global_position + cam_basis * left_hand_initial_offset + \
		(-cam_basis.z * reach_distance if left_hand_reaching else Vector3.ZERO)
	
	#if grab move to grab point
	#if reaching extend from camera
	#if not grab return to default
	var right_target = grab_point_right if right_hand_grabbing else \
		camera.global_position + cam_basis * right_hand_initial_offset + \
		(-cam_basis.z * reach_distance if right_hand_reaching else Vector3.ZERO)
	
	#hand movement left
	left_hand.global_position = left_hand.global_position.lerp(
		left_target,
		delta * (reach_speed if left_hand_reaching else hand_smoothing)
	)
	#hand movement right
	right_hand.global_position = right_hand.global_position.lerp(
		right_target,
		delta * (reach_speed if right_hand_reaching else hand_smoothing)
	)
	
	var left_adjustment = Basis().rotated(Vector3.FORWARD, deg_to_rad(180))
	var right_adjustment = Basis().rotated(Vector3.FORWARD, deg_to_rad(180))
	
	#hand rotation
	if left_hand_grabbing:
		var grab_dir = (grab_point_left - camera.global_position).normalized()
		var target_basis = Basis.looking_at(grab_dir, Vector3.UP)
		left_hand.global_transform.basis = left_hand.global_transform.basis.slerp(
			target_basis, 
			delta * hand_smoothing
		)
	else:
		left_hand.global_transform.basis = left_hand.global_transform.basis.slerp(
			cam_basis * left_adjustment,
			delta * hand_smoothing
		)
	
	if right_hand_grabbing:
		var grab_dir = (grab_point_right - camera.global_position).normalized()
		var target_basis = Basis.looking_at(grab_dir, Vector3.UP)
		right_hand.global_transform.basis = right_hand.global_transform.basis.slerp(
			target_basis, 
			delta * hand_smoothing
		)
	else:
		right_hand.global_transform.basis = right_hand.global_transform.basis.slerp(
			cam_basis * right_adjustment,
			delta * hand_smoothing
		)

func handle_landing():
	#put sounds, fx
	velocity.y = 0
