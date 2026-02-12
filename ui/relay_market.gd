extends CanvasLayer
## NPC Relay Market overlay. Only accessible when docked at home base.
## Press E to toggle. State persists across sector transitions via GameState.

@onready var panel: Control = $Panel


func _ready() -> void:
	layer = 12
	if panel:
		panel.visible = GameState.relay_market_open
		if panel.visible:
			panel.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_market"):
		# Only allow opening at home base
		if not GameState.relay_market_open and GameState.current_sector_id != GameState.home_sector_id:
			return
		GameState.relay_market_open = not GameState.relay_market_open
		if panel:
			panel.visible = GameState.relay_market_open
			panel.queue_redraw()
		# Mutual exclusion: close codex and map when market opens
		if GameState.relay_market_open:
			if GameState.codex_open:
				GameState.codex_open = false
				var codex := get_tree().current_scene.get_node_or_null("CodexOverlay")
				if codex and codex.has_node("Panel"):
					codex.get_node("Panel").visible = false
			if GameState.map_overlay_open:
				GameState.map_overlay_open = false
				var map_ov := get_tree().current_scene.get_node_or_null("MapOverlay")
				if map_ov and map_ov.has_node("Panel"):
					map_ov.get_node("Panel").visible = false
		get_viewport().set_input_as_handled()
