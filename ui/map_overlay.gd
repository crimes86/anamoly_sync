extends CanvasLayer
## Toggleable galaxy map overlay shown during sector exploration.
## Press M to toggle. State persists across sector transitions via GameState.

@onready var panel: Control = $Panel


func _ready() -> void:
	layer = 10
	# Restore persisted state
	if panel:
		panel.visible = GameState.map_overlay_open
		if panel.visible:
			panel.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		GameState.map_overlay_open = not GameState.map_overlay_open
		if panel:
			panel.visible = GameState.map_overlay_open
			panel.queue_redraw()
		get_viewport().set_input_as_handled()
