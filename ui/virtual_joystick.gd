extends Control
## Virtual joystick for mobile touch input.
## Emits a normalized direction vector for ship movement.

signal joystick_input(direction: Vector2)
signal fire_pressed()
signal fire_released()

@export var joystick_radius: float = 64.0
@export var dead_zone: float = 0.15

var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var current_direction: Vector2 = Vector2.ZERO
var touch_index: int = -1

@onready var base_circle: Control = $Base
@onready var thumb: Control = $Base/Thumb
@onready var fire_button: Button = $FireButton


func _ready() -> void:
	# Only show on touch devices
	if not _is_touch_device():
		visible = false
		return

	if fire_button:
		fire_button.button_down.connect(func(): fire_pressed.emit())
		fire_button.button_up.connect(func(): fire_released.emit())


func _is_touch_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web")


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed and _is_in_joystick_area(event.position):
			is_dragging = true
			touch_index = event.index
			drag_start = event.position
			if thumb:
				thumb.position = Vector2.ZERO
		elif not event.pressed and event.index == touch_index:
			_reset_joystick()

	elif event is InputEventScreenDrag and event.index == touch_index and is_dragging:
		var offset: Vector2 = event.position - drag_start
		if offset.length() > joystick_radius:
			offset = offset.normalized() * joystick_radius

		if thumb:
			thumb.position = offset

		current_direction = offset / joystick_radius
		if current_direction.length() < dead_zone:
			current_direction = Vector2.ZERO

		joystick_input.emit(current_direction)


func _is_in_joystick_area(pos: Vector2) -> bool:
	if base_circle == null:
		return false
	var center: Vector2 = base_circle.global_position + base_circle.size * 0.5
	return pos.distance_to(center) <= joystick_radius * 2.0


func _reset_joystick() -> void:
	is_dragging = false
	touch_index = -1
	current_direction = Vector2.ZERO
	if thumb:
		thumb.position = Vector2.ZERO
	joystick_input.emit(Vector2.ZERO)
