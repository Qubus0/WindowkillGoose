extends RigidBody2D
#Utils.spawn(preload("res://mods-unpacked/Ste-Goose/goose.tscn"), get_global_mouse_position(), game_area)

var args := {
	index = 0,
}

var targetPlayer:Node2D

var coins := 8.0
@onready var enemy = $Enemy

@onready var collide_shape = $collideShape
@onready var detect_shape = $Area2D/detectShape


var window:Window
var windowCamera:Camera2D

var target := Vector2.ZERO
var angle := Vector2.ZERO

var knockbackVel := Vector2.ZERO

var delta := 0.0

var maxHealth := 100
var flashTimer := 0.0

var frozen := false
var drainSpeed := 1.0
var _drainSpeed := 1.0

#region Footsteps

# todo test utils func mouseScreenPos() -> Vector2:
	#return get_viewport().get_mouse_position()
var speed_normal := 50
var speed_chase := 180
var speed := speed_normal

var neck_normal := 24
var neck_chase := 32
var neck_offset := neck_normal

var feet_normal := 10
var feet_chase := 20
var feet_offset := feet_normal

var step_time := .1
var max_foot_dist := 30
var left_leg_stepper: Tween
var right_leg_stepper: Tween

enum movement {WAIT, WANDER, CHASE}

var move_state := movement.WAIT :
	set(new_state):
		move_state = new_state

		var is_chasing := move_state == movement.CHASE
		speed = speed_normal if not is_chasing else speed_chase
		neck_offset = neck_normal if not is_chasing else neck_chase
		feet_offset = feet_normal if not is_chasing else feet_chase

@onready var foot_left := $FeetPivot/Offset/Left/Foot
@onready var marker_left := $FeetPivot/Offset/Left
@onready var foot_right := $FeetPivot/Offset/Right/Foot
@onready var marker_right := $FeetPivot/Offset/Right

func move_legs() -> void:
	if not is_stepping(right_leg_stepper):
		if foot_left.position.distance_to(marker_left.global_position) >= max_foot_dist:
			left_leg_stepper = get_tree().create_tween()
			left_leg_stepper.tween_property(foot_left, "position", marker_left.global_position, step_time)

	if not is_stepping(left_leg_stepper):
		if foot_right.position.distance_to(marker_right.global_position) >= max_foot_dist:
			right_leg_stepper = get_tree().create_tween()
			right_leg_stepper.tween_property(foot_right, "position", marker_right.global_position, step_time)


func is_stepping(stepper: Tween) -> bool:
	return is_instance_valid(stepper) and stepper.is_valid() and stepper.is_running()


func look_direction(direction: Vector2) -> void:
	$Body.look_at(direction)
	$FeetPivot.look_at(direction)
	$NeckPivot.look_at(direction)

	var head_rot: int = abs(int($NeckPivot.rotation_degrees)) % 360
	# flip the head when looking left
	#var direction := -1 if head_rot > 90 and head_rot < 270 else 1
	var rotation_percentage: float = abs((head_rot - 180.0) / 180.0)
	var mapped_percentage: float = remap(rotation_percentage, 0, 1, -1, 1)

	$NeckPivot/HeadPivot.position.y = mapped_percentage * -10
	$NeckPivot/HeadPivot/Eyes.position.y = mapped_percentage * -4
	$NeckPivot/HeadPivot/Beak.position.y = mapped_percentage * 3

	$NeckPivot/HeadPivot.position.x = neck_offset
	$FeetPivot/Offset.position.x = feet_offset
	#if $NeckPivot.rotation_degrees > 90:

	move_legs()

#endregion


func _ready():
	foot_left.position = global_position
	foot_right.position = global_position
	_wander_target()

	targetPlayer = Game.randomPlayer()

	maxHealth = 120 + lerp(0.0, 32.0, Stats.stats.totalBossesKilled / 6.0)
	#maxHealth = min(maxHealth, 56)

	enemy.health = maxHealth

	window = Window.new()
	Game.registerWindow(window, "goose")
	window.size = Vector2(200, 200)

	window.position = position - window.size / 2.0
	#window.gui_disable_input = true
	#DisplayServer.block_mm(window.get_window_id(), true)

	windowCamera = Camera2D.new()
	windowCamera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	windowCamera.position = window.position
	#window.unfocusable = true
	window.unresizable = true
	window.always_on_top = Global.options.alwaysOnTop
	window.add_child(windowCamera)

	window.close_requested.connect(func():
		if Global.detach >= 4:
			enemy.damage(Global.detach-3)
	)

	collide_shape.disabled = true
	detect_shape.disabled = true

	Utils.processLater(self, 1 + 160 * args.index, func():
		var tween = get_tree().create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		add_child(window)
		collide_shape.disabled = false
		detect_shape.disabled = false
	)


func _process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		move_state = movement.CHASE
		target = get_global_mouse_position()

	delta *= Global.timescale
	updateWindows()

	flashTimer -= 2.0 * delta
	var modulateVal = 1.0 + 20.0 * (TorCurve.run(flashTimer, 2, 1, 1))
	if flashTimer <= 0.0:
		pass

	print(move_state)
	if move_state == movement.WAIT:
		var rota: float = abs($Body.rotation_degrees)
		var direction := -1 if rota > 90 and rota < 270 else 1
		look_direction(global_position + Vector2.RIGHT *800 * direction)
	else:
		look_direction(target)


func _physics_process(delta):
	delta *= Global.timescale
	self.delta = delta
	#updateWindows()


var wander_wait_time = 0.0
var target_threshold := 20

func _integrate_forces(_state):
	angular_velocity = 0
	rotation = 0
	var dist = position.distance_to(target)
	wander_wait_time -= delta

	# if we are out of screen, chase to get back in
	if not Game.screenRectSafe.has_point(position):
		move_state = movement.CHASE
		target = get_global_mouse_position()

	if move_state == movement.CHASE:
		_chase_target()
	elif dist < target_threshold:
		if move_state == movement.WANDER:
			_wait()
		if wander_wait_time < 0:
			_wander_target()

	if dist < target_threshold:
		linear_velocity = Vector2.ZERO
		return

	var lerpStrength = 8.0 * TorCurve.run(dist / 50.0, 1.5, 0.0, 1.0)
	angle = angle.slerp(position.direction_to(target), lerpStrength * delta)

	var vel = angle * speed

	knockbackVel = Utils.lexp(knockbackVel, Vector2.ZERO, 20.0 * delta)

	linear_velocity = vel + knockbackVel
	linear_velocity *= Global.timescale #* parent.drainSpeed

func _wander_target() -> void:
	move_state = movement.WANDER
	target = global_position
	target += Vector2.from_angle(randf_range(0, TAU)) * randi_range(200, 400)
	target = Utils.reflectInside(target, Game.screenRectSafe)
	wander_wait_time = -1
	printt("new wander", target)

func _wait() -> void:
	move_state = movement.WAIT
	wander_wait_time = randi_range(2, 5)
	printt("new wait", target, wander_wait_time)

func _chase_target() -> void:
	move_state = movement.CHASE
	wander_wait_time = -1
	printt("new chase", target)


# TODO
func newTarget():
	targetPlayer = Game.randomPlayer()


func updateWindows():
	if(window.mode & Window.MODE_MINIMIZED > 0):
		window.mode &= ~Window.MODE_MINIMIZED

	window.set_meta("health", (enemy.health + enemy.buff) / (maxHealth + enemy.buff))
	Game.setWindowRect(window, Rect2(position - window.size / 2.0, window.size), true, true)
	windowCamera.position = window.position



func kill(soft := false):
	if not soft:
		Audio.play(preload("res://src/sounds/bossDie.ogg"), 0.8, 1.2)
	for i in 4:
		Utils.spawn(preload("res://src/particle/enemy_pop/enemy_pop.tscn"), position, get_parent(), {color = Color(0.1, 0.769, 1)})

	Audio.playRandom([preload("res://src/sounds/slime1.ogg"), preload("res://src/sounds/slime2.ogg"), preload("res://src/sounds/slime3.ogg")], 0.8, 1.2)

	queue_free()

func knockback(from:Vector2, power := 1.0, reset := false):
	var new = power*600.0 * (position - from).normalized()
	knockbackVel = new if reset else knockbackVel + new
	enemy.flash()
