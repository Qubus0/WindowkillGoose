#extends Node2D
extends RigidBody2D
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

var is_chasing := false :
	set(chasing):
		is_chasing = chasing
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


func animation_process() -> void:
	$Icon.look_at(get_global_mouse_position())
	$FeetPivot.look_at(get_global_mouse_position())
	$NeckPivot.look_at(get_global_mouse_position())

	var head_rot: int = abs(int($NeckPivot.rotation_degrees)) % 360
	# flip the head when looking left
	var direction := -1 if head_rot > 90 and head_rot < 270 else 1

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
	is_chasing = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	delta *= Global.timescale
	updateWindows()

	flashTimer -= 2.0 * delta
	var modulateVal = 1.0 + 20.0 * (TorCurve.run(flashTimer, 2, 1, 1))
	if flashTimer <= 0.0:
		pass

	animation_process()



func _physics_process(delta):
	delta *= Global.timescale
	self.delta = delta

	#updateWindows()

func _integrate_forces(_state):
	target = get_global_mouse_position()
#
	var dist = position.distance_to(target)
	var lerpStrength = 8.0 * TorCurve.run(dist / 50.0, 1.5, 0.0, 1.0)
	#var lerpStrength = 8.0 * min(1.0, dist / 50.0)
	angle = angle.slerp(position.direction_to(target), lerpStrength * delta)

	var vel = angle * speed

	knockbackVel = Utils.lexp(knockbackVel, Vector2.ZERO, 20.0 * delta)

	linear_velocity = vel + knockbackVel
	#linear_velocity = springVel

	linear_velocity *= Global.timescale #* parent.drainSpeed
	angular_velocity *= Global.timescale


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
