extends CanvasLayer
## Toggleable Codex Vault / Crafting overlay.
## Press Tab to toggle. State persists across sector transitions via GameState.

@onready var panel: Control = $Panel


func _ready() -> void:
	layer = 11
	if panel:
		panel.visible = GameState.codex_open
		if panel.visible:
			panel.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_codex"):
		GameState.codex_open = not GameState.codex_open
		if panel:
			panel.visible = GameState.codex_open
			panel.queue_redraw()
		# Mutual exclusion: close other overlays when codex opens
		if GameState.codex_open:
			if GameState.map_overlay_open:
				GameState.map_overlay_open = false
				var map_overlay := get_tree().current_scene.get_node_or_null("MapOverlay")
				if map_overlay and map_overlay.has_node("Panel"):
					map_overlay.get_node("Panel").visible = false
			if GameState.relay_market_open:
				GameState.relay_market_open = false
				var market := get_tree().current_scene.get_node_or_null("RelayMarket")
				if market and market.has_node("Panel"):
					market.get_node("Panel").visible = false
		get_viewport().set_input_as_handled()
