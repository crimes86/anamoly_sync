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
	if event.is_action_pressed("toggle_map"):
		GameState.map_overlay_open = not GameState.map_overlay_open
		if panel:
			panel.visible = GameState.map_overlay_open
			panel.queue_redraw()
		# Mutual exclusion: close other overlays when map opens
		if GameState.map_overlay_open:
			if GameState.codex_open:
				GameState.codex_open = false
				var codex_overlay := get_tree().current_scene.get_node_or_null("CodexOverlay")
				if codex_overlay and codex_overlay.has_node("Panel"):
					codex_overlay.get_node("Panel").visible = false
			if GameState.relay_market_open:
				GameState.relay_market_open = false
				var market := get_tree().current_scene.get_node_or_null("RelayMarket")
				if market and market.has_node("Panel"):
					market.get_node("Panel").visible = false
		get_viewport().set_input_as_handled()
