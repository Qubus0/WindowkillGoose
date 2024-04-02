class_name Goose
extends RigidBody2D
#Utils.spawn(preload("res://mods-unpacked/Ste-Goose/goose.tscn"), get_global_mouse_position(), game_area)

var args := {
	index = 0,
}

var targetPlayer:Node2D

var coins := 42.0
@onready var enemy = $Enemy

@onready var collide_shape = $collideShape
@onready var detect_shape = $Area2D/detectShape


var window: Window
@onready var window_camera: Camera2D


var target := Vector2.ZERO
var state_machine: StateMachine
var look_angle := 0

var knockbackVel := Vector2.ZERO

var maxHealth := 100
var flashTimer := 0.0

var frozen := false
var drainSpeed := 1.0
var _drainSpeed := 1.0

#region animation

var step_time := .1
var step_foot_dist := 30
var max_foot_dist := 60
var left_leg_stepper: Tween
var right_leg_stepper: Tween

@onready var foot_left := %Left/Foot
@onready var marker_left := %Left
@onready var foot_right := %Right/Foot
@onready var marker_right := %Right

func move_feet() -> void:
	if foot_left.position.distance_to(marker_left.global_position) >= max_foot_dist:
		step_left(step_time/2)
		return
	elif foot_right.position.distance_to(marker_right.global_position) >= max_foot_dist:
		step_right(step_time/2)
		return

	if not is_stepping(right_leg_stepper):
		if foot_left.position.distance_to(marker_left.global_position) >= step_foot_dist:
			step_left(step_time)

	if not is_stepping(left_leg_stepper):
		if foot_right.position.distance_to(marker_right.global_position) >= step_foot_dist:
			step_right(step_time)

func return_feet() -> void:
	if not is_stepping(right_leg_stepper):
		if foot_left.position.distance_to(marker_left.global_position) >= 0.1:
			step_left(step_time/2)

	if not is_stepping(left_leg_stepper):
		if foot_right.position.distance_to(marker_right.global_position) >= 0.1:
			step_right(step_time/2)

func is_stepping(stepper: Tween) -> bool:
	return is_instance_valid(stepper) and stepper.is_valid() and stepper.is_running()

func step_left(step_time: float) -> void:
	left_leg_stepper = get_tree().create_tween()
	left_leg_stepper.tween_property(foot_left, "position", marker_left.global_position, step_time)

func step_right(step_time: float) -> void:
	right_leg_stepper = get_tree().create_tween()
	right_leg_stepper.tween_property(foot_right, "position", marker_right.global_position, step_time)

var rotation_speed := 6.0
func look_direction(direction: Vector2, delta: float) -> void:
	var body := %Body as Node2D
	var from_angle := body.rotation
	var to_angle := (body).global_transform.looking_at(direction).get_rotation()
	var lerped := lerp_angle(from_angle, to_angle, delta * rotation_speed)
	body.rotation = lerped
	%ClippedBodyPivot.rotation = lerped
	%FeetPivot.rotation = lerped
	%NeckPivot.rotation = lerped
	%Eyes.rotation = lerped
	look_angle = int(body.rotation_degrees) % 360

	%ClippedBody.global_position = %Body.global_position

	var head_rot: int = abs(int(%NeckPivot.rotation_degrees)) % 360
	var rotation_percentage: float = abs((head_rot - 180.0) / 180.0)
	var x_mapped_percentage: float = abs(rotation_percentage - 0.5)
	%Beak.position.x = 10 + (x_mapped_percentage) * 4

	move_feet()

func shift_head(offset: float) -> void:
#	var duration := .3
	#var tw := get_tree().create_tween()
	#tw.set_parallel(true)
	#tw.tween_property(%HeadPivot, "position:x", %HeadPivot.position.x + offset, duration)
	#tw.tween_property(%Eyes/EyeLeft, "position:x", %Eyes/EyeLeft.position.x + offset, duration)
	#tw.tween_property(%Eyes/EyeRight, "position:x", %Eyes/EyeRight.position.x + offset, duration)
	#tw.tween_property(%ClippedBodyPivot/HeadClipMask, "position:x", %ClippedBodyPivot/HeadClipMask.position.x + offset, duration)
	%HeadPivot.position.x += offset
	%Eyes/EyeLeft.position.x += offset
	%Eyes/EyeRight.position.x += offset
	%ClippedBodyPivot/HeadClipMask.position.x += offset

	%ClippedBody.global_position = %Body.global_position

func shift_feet(offset: float) -> void:
#	var duration := .3
#	var tw := get_tree().create_tween()
#	tw.tween_property(%FeetOffset, "position:x", %FeetOffset.position.x + offset *4, duration)
	%FeetOffset.position.x += offset *4

func is_target_reached(target) -> bool:
	return %Beak.global_position.distance_to(target) < 10.0 or global_position.distance_to(target) < 10.0

#endregion

func _ready():
	targetPlayer = Game.randomPlayer()
	enemy.invincible = true

	window = Window.new()
	Game.registerWindow(window, "goose")
	window.size = Vector2(200, 200)
	window.position = position - window.size / 2.0

	window_camera = Camera2D.new()
	window_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	window_camera.position = window.position
	window.unfocusable = true
	window.unresizable = true
	window.always_on_top = Global.options.alwaysOnTop
	window.add_child(window_camera)

	move_feet()
	state_machine = StateMachine.new(self)

	window.close_requested.connect(func():
		if Global.detach >= 4:
			enemy.damage(Global.detach-3)
	)

	collide_shape.disabled = true
	detect_shape.disabled = true

	Utils.processLater(self, 1 + 160 * args.index, func():
		add_child(window)
		collide_shape.disabled = false
		detect_shape.disabled = false
	)


func _process(delta):
	delta *= Global.timescale
	state_machine.update(delta)
	update_windows()


func update_windows():
	if(window.mode & Window.MODE_MINIMIZED > 0):
		window.mode &= ~Window.MODE_MINIMIZED

	Game.setWindowRect(window, Rect2(position - window.size / 2.0, window.size), true, true)
	window_camera.position = window.position


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state_machine.control_puppet()



# all of the following are internal classes to profit from named classes,
# without having to inject classes into the cache at runtime
class StateMachine:
	var puppet: Goose
	var current_state: State
	var states: Array[State] = []
	var state_transitions: Dictionary = {}  # New dictionary for state transitions

	func _init(new_puppet: Goose) -> void:
		puppet = new_puppet
		var idle         = StateIdle.new(puppet)
		var wander       = StateWander.new(puppet)
		var chase_cursor = StateChaseCursor.new(puppet)
		var steal_cursor = StateStealCursor.new(puppet)
		var chase_window = StateChaseWindow.new(puppet)
		var steal_window = StateStealWindow.new(puppet)

		add_state(idle, [
			#wander,
			#chase_cursor,
			chase_window,
		])
		add_state(wander, [idle])
		add_state(chase_cursor, [steal_cursor])
		add_state(steal_cursor, [idle, wander])
		add_state(chase_window, [steal_window])
		add_state(steal_window, [idle, wander])

		change_state(states.front())

	func add_state(state: State, transitions := []) -> void:
		state.state_finished.connect(choose_state)
		state.state_canceled.connect(cancel_state)
		state_transitions[state] = transitions
		states.append(state)

	func choose_state() -> void:
		var new_state: State = state_transitions[current_state].pick_random()
		change_state(new_state)

	func cancel_state() -> void:
		change_state(states.front())

	func change_state(new_state: State) -> void:
		if not current_state == null:
			current_state.exit()

		new_state.setup(current_state)
		current_state = new_state
		current_state.enter()

	func update(delta: float) -> void:
		current_state.process(delta)

	func control_puppet() -> void:
		current_state.control_puppet()


class State:
	signal state_finished
	signal state_canceled

	var name := "Base State"
	var sequential_state: State
	var puppet: Goose
	var shift_head := 0
	var shift_feet := 0

	func _init(puppet: Goose) -> void:
		self.puppet = puppet

	func setup(previous_state: State) -> void:
		pass

	func enter() -> void:
		prints("Entering", name)
		puppet.shift_head(shift_head)
		puppet.shift_feet(shift_feet)

	func exit() -> void:
		prints("Exiting", name)
		puppet.shift_head(-shift_head)
		puppet.shift_feet(-shift_feet)

	func process(delta: float) -> void:
		pass

	func control_puppet() -> void:
		pass

	func update_sequential_state() -> void:
		pass


## stand still.
## ends after a random amount of time.
class StateIdle:
	extends State
	var idle_time := 0.0

	func _init(puppet: Goose) -> void:
		super(puppet)
		name = "Idle"

	func enter() -> void:
		super()
		idle_time = randf_range(1, 3)

	func process(delta: float) -> void:
		idle_time -= delta
		if idle_time <= 0:
			state_finished.emit()
			return

		puppet.return_feet()

	func control_puppet() -> void:
		puppet.linear_velocity = Vector2.ZERO


class TargetedState extends State:
	var target: Vector2
	var speed := 0.0

	func enter() -> void:
		super()
		update_target()

	func update_target() -> void:
		pass

	func control_puppet() -> void:
		if not target or puppet.is_target_reached(target):
			puppet.linear_velocity = Vector2.ZERO
			return

		var direction := target - puppet.global_position
		direction = direction.normalized()
		puppet.linear_velocity = direction * speed


## chase the target.
## ends when the puppet is close to the target.
class StateChase:
	extends TargetedState

	func _init(puppet: Goose) -> void:
		super(puppet)
		name = "Chase"
		shift_head = 6
		shift_feet = 22
		speed = 180

	func process(delta: float) -> void:
		update_target()
		if puppet.is_target_reached(target):
			state_finished.emit()
			return

		puppet.look_direction(target, delta)


## chase the mouse cursor.
class StateChaseCursor:
	extends StateChase

	func update_target():
		target = puppet.get_global_mouse_position()


class StateChaseWindow:
	extends StateChase
	var target_window: Window

	func enter() -> void:
		super()
		var possible_windows: Array[Window] = []
		possible_windows.append_array(Global.main.drainWindows)
		possible_windows.append_array(Global.main.peerWindows)

		if not possible_windows:
			state_canceled.emit()
			return

		target_window = possible_windows.pick_random()

	func update_target():
		if not target_window:
			state_canceled.emit()
			return

		target = Vector2(target_window.position.x + target_window.size.x /2, target_window.position.y -10)


## wander around the by choosing a random direction to move in.
## ends when the puppet is close to the target.
class StateWander:
	extends TargetedState
	var wander_target: Vector2

	func _init(puppet: Goose) -> void:
		super(puppet)
		name = "Wander"
		shift_head = 4
		shift_feet = 12
		speed = 50

	func process(delta: float) -> void:
		if puppet.is_target_reached(target):
			state_finished.emit()
			return

		puppet.look_direction(target, delta)

	func update_target() -> void:
		var area := Game.screenRectDeco.grow(-100)
		target = Utils.randRectPoint(area)


## steals the mouse cursor and moves it around.
## ends when the puppet is close to the target.
class StateStealCursor:
	extends StateWander

	func _init(puppet: Goose) -> void:
		super(puppet)
		name = "Steal"
		shift_head = 6
		shift_feet = 22
		speed = 120

	func process(delta: float) -> void:
		super(delta)

		var beak_position: Vector2 = puppet.get_node("%Beak").global_position - puppet.global_position
		var offset := puppet.window_camera.get_screen_center_position()
		DisplayServer.warp_mouse(offset + beak_position)


class StateStealWindow:
	extends StateWander
	var target_window: Window
	var from_position: Vector2

	func _init(puppet: Goose) -> void:
		super(puppet)
		shift_head = 6
		shift_feet = -22

	func setup(previous_state: State) -> void:
		super(previous_state)
		target_window = previous_state.target_window
		if not target_window:
			state_canceled.emit()

	func enter() -> void:
		super()
		from_position = puppet.global_position

	func process(delta: float) -> void:
		if puppet.is_target_reached(target):
			state_finished.emit()
			return

		puppet.look_direction(from_position, delta)

		var beak_position: Vector2 = puppet.get_node("%Beak").global_position - puppet.global_position
		var offset := puppet.window_camera.get_screen_center_position()
		offset -= Vector2(target_window.size.x /2 , -10)
		target_window.position = Vector2(offset + beak_position)


