extends KinematicBody2D

#### SIGNALS ####
signal exit
signal die
signal controls_changed

#### VARIABLES ####

## Export

# traces the fsm changes
export (bool) var debug = true

# default moves available
export(String, "move_up", "move_down", "move_left", "move_right", "run", "jump") var control_1 = "move_right"
export(String, "move_up", "move_down", "move_left", "move_right", "run", "jump") var control_2 = "move_left"

# controls are pressed
var control_1_pressed = false
var control_2_pressed = false

## FSM

const IDLE = 0
const WALKING = 1
const RUNNING = 2
const JUMPING = 3
const FALLING = 4
const CLIMBING = 5
# current state
var fsm = IDLE

## PHYSICS

const GRAVITY = 500
const WALK_SPEED = 125
const RUN_SPEED = 350
const JUMP_SPEED = 50

var velocity = Vector2()

const MAX_JUMP_TIME = 0.1
var jumping_time = 0

#### ONREADY ####

onready var interaction_area = get_node("interaction_area")
onready var climb_area = preload("res://sources/scripts/levels/climb_area.gd")

func _ready():
	set_fixed_process(true)
	set_process_input(true)

#### METHODS ####
	
func _fixed_process(delta):
	decide_fsm(delta)
	update_physics(delta)
	
func _input(event):
	update_controls(event)
	
# PHYSICS

func update_physics(delta):
	# first update the velocity with gravity
	update_gravity(delta)
	
	# next update the velocity according to the fsm state
	if fsm == IDLE:
		update_idle(delta)
	elif fsm == WALKING:
		update_walking(delta)
	elif fsm == RUNNING:
		update_running(delta)
	elif fsm == JUMPING:
		update_jumping(delta)
	elif fsm == FALLING:
		update_falling(delta)
	elif fsm == CLIMBING:
		update_climbing(delta)
	
	# finally integrate the velocity into actual motion
	integrate_motion(delta)
	
	
func update_idle(delta):
	velocity.y = 0
	velocity.x = lerp(velocity.x, 0, 0.1)
	
func update_walking(delta):
	if is_on_ground() :
		velocity.y = 0
		if available_action_pressed("move_left") && available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, 0, 0.2)
		elif available_action_pressed("move_left"):
			velocity.x = lerp(velocity.x, -WALK_SPEED, 0.2)
		elif available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, WALK_SPEED, 0.2)

func update_running(delta):
	if is_on_ground() :
		velocity.y = 0
		if available_action_pressed("move_left") && available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, 0, 0.2)
		elif available_action_pressed("move_left"):
			velocity.x = lerp(velocity.x, -RUN_SPEED, 0.2)
		elif available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, RUN_SPEED, 0.2)
	
func update_jumping(delta):
	jumping_time += delta
	if abs(velocity.x) < RUN_SPEED && available_action_pressed("run"):
		if available_action_pressed("move_left"):
			velocity.x = lerp(velocity.x, -RUN_SPEED, 0.3)
		elif available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, RUN_SPEED, 0.3)
	elif abs(velocity.x) < WALK_SPEED && !available_action_pressed("run"):
		if available_action_pressed("move_left"):
			velocity.x = lerp(velocity.x, -WALK_SPEED, 0.3)
		elif available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, WALK_SPEED, 0.3)
		
	velocity.y -= JUMP_SPEED
	
func update_falling(delta):
	if abs(velocity.x) < RUN_SPEED && available_action_pressed("run") && (available_action_pressed("move_left") || available_action_pressed("move_right")):
		if available_action_pressed("move_left"):
			velocity.x = lerp(velocity.x, -RUN_SPEED, 0.1)
		elif available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, RUN_SPEED, 0.1)
	elif abs(velocity.x) < WALK_SPEED && !available_action_pressed("run") && (available_action_pressed("move_left") || available_action_pressed("move_right")):
		if available_action_pressed("move_left"):
			velocity.x = lerp(velocity.x, -WALK_SPEED, 0.2)
		elif available_action_pressed("move_right"):
			velocity.x = lerp(velocity.x, WALK_SPEED, 0.2)
	else:
		velocity.x = lerp(velocity.x, 0, 0.02)
	
func update_climbing(delta):
	if available_action_pressed("move_up"):
		move(Vector2(0, -5))
	elif available_action_pressed("move_down"):
		move(Vector2(0, 5))
	velocity.y = 0
	velocity.x = 0

func update_gravity(delta):
	#velocity.y += delta * GRAVITY
	velocity.y = lerp(velocity.y, GRAVITY, 0.015)
	
func integrate_motion(delta):
	var motion = velocity * delta
	move(motion)
	
	if is_colliding():
		var n = get_collision_normal()
		motion = n.slide(motion)
		velocity = n.slide(velocity)
		move(motion)
	
func is_on_ground():
	 return test_move(Vector2(0, 1))
	
func reset_jump():
	jumping_time = 0
	if control_1 == "jump" && control_1_pressed:
		control_1_pressed = false
	if control_2 == "jump" && control_2_pressed:
		control_2_pressed = false
# FSM

func decide_fsm(delta):
	if fsm == IDLE:
		decide_fsm_idle(delta)
	elif fsm == WALKING:
		decide_fsm_walking(delta)
	elif fsm == RUNNING:
		decide_fsm_running(delta)
	elif fsm == JUMPING:
		decide_fsm_jumping(delta)
	elif fsm == FALLING:
		decide_fsm_falling(delta)
	elif fsm == CLIMBING:
		decide_fsm_climbing(delta)

func decide_fsm_idle(delta):
	if !is_on_ground():
		change_state(FALLING)
	elif available_action_pressed("jump"):
		change_state(JUMPING)
	elif can_climb() && (available_action_pressed("move_up") || available_action_pressed("move_down")):
		change_state(CLIMBING)
	elif available_action_pressed("move_left") || available_action_pressed("move_right") :
		if available_action_pressed("run"):
			change_state(RUNNING)
		else:
			change_state(WALKING)
	
func decide_fsm_walking(delta):
	if !is_on_ground():
		change_state(FALLING)
	elif available_action_pressed("jump"):
		change_state(JUMPING)
	elif can_climb() && (available_action_pressed("move_up") || available_action_pressed("move_down")):
		change_state(CLIMBING)
	elif available_action_pressed("run"):
		change_state(RUNNING)
	elif !available_action_pressed("move_left") && !available_action_pressed("move_right") :
		change_state(IDLE)

func decide_fsm_running(delta):
	if !is_on_ground():
		change_state(FALLING)
	elif available_action_pressed("jump"):
		change_state(JUMPING)
	elif can_climb() && (available_action_pressed("move_up") || available_action_pressed("move_down")):
		change_state(CLIMBING)
	elif !available_action_pressed("move_left") && !available_action_pressed("move_right") :
		change_state(IDLE)
	elif !available_action_pressed("run"):
		change_state(WALKING)

func decide_fsm_jumping(delta):
	if jumping_time > MAX_JUMP_TIME || !available_action_pressed("jump"):
		change_state(FALLING)
		reset_jump()
		
func decide_fsm_falling(delta):
	if is_on_ground():
		if available_action_pressed("move_left") || available_action_pressed("move_right"):
			change_state(WALKING)
		else :
			change_state(IDLE)
	elif can_climb() && (available_action_pressed("move_up") || available_action_pressed("move_down")):
		change_state(CLIMBING)
		
func decide_fsm_climbing(delta):
	if available_action_pressed("jump"):
		change_state(FALLING)
	elif !can_climb():
		change_state(FALLING)
	elif is_on_ground() && available_action_pressed("move_down"):
		change_state(IDLE)

func change_state(id):
	if debug:
		print(get_fsm_name(fsm), " -> ", get_fsm_name(id))
	fsm = id

func can_climb():
	for area in interaction_area.get_overlapping_areas():
		if area extends climb_area:
			return true
	return false

func get_fsm_name(id = -1):
	if id == -1:
		id = fsm
	if id == IDLE:
		return "idle"
	elif id == WALKING:
		return "walking"
	elif id == RUNNING:
		return "running"
	elif id == JUMPING:
		return "jumping"
	elif id == FALLING:
		return "falling"
	elif id == CLIMBING:
		return "climbing"
	
# Interactions

func update_controls(event):
	# update control_x_pressed state
	if event.type == InputEvent.KEY && !event.is_echo():
		if event.is_action(control_1):
			control_1_pressed = event.pressed
		if event.is_action(control_2):
			control_2_pressed = event.pressed
	
func available_action_pressed(action):
	if debug:
		return Input.is_action_pressed(action)
	else:
		return (control_1_pressed && control_1 == action) || (control_2_pressed && control_2 == action)

func change_controls(control_1, control_2):
	if self.control_1 != control_1:
		self.control_1 = control_1
		control_1_pressed = false
	if self.control_2 != control_2:
		self.control_2 = control_2
		control_2_pressed = false
	emit_signal("controls_changed", self)

func die():
	emit_signal("die")
	#get_tree().get_root().get_node("root").restart()
	
func exit():
	emit_signal("exit")
	#get_tree().get_root().get_node("root").show_menu()
