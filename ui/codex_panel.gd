extends Control
## Codex panel: draws the Vault grid and Recipe crafting UI.

enum Tab { VAULT, RECIPES }

var active_tab: Tab = Tab.VAULT
var family_filter: String = ""
var craft_feedback_timer: float = 0.0
var craft_feedback_recipe: String = ""

# Scrap state
var selected_relic_index: int = -1  # Index into the filtered relics list
var scrap_feedback_timer: float = 0.0
var scrap_feedback_amount: int = 0
const SCRAP_BTN_SIZE: Vector2 = Vector2(140, 28)

# Layout constants
const TAB_HEIGHT: float = 36.0
const TAB_WIDTH: float = 120.0
const HEADER_HEIGHT: float = 32.0
const CARD_SIZE: Vector2 = Vector2(200, 90)
const CARD_PADDING: float = 10.0
const FILTER_BTN_SIZE: Vector2 = Vector2(80, 26)
const CRAFT_BTN_SIZE: Vector2 = Vector2(110, 32)
const FAMILIES: Array[String] = ["FRACTAL", "VOID", "PULSE", "DRIFT", "ECHO"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	RelicDB.vault_changed.connect(_on_data_changed)
	DemandManager.spotlight_changed.connect(_on_spotlight_changed)
	DemandManager.demand_updated.connect(_on_data_changed)
	DemandManager.recipe_crafted.connect(_on_recipe_crafted)


func _on_data_changed(_args: Variant = null) -> void:
	if visible:
		queue_redraw()


func _on_spotlight_changed(_family: String, _mult: float) -> void:
	if visible:
		queue_redraw()


func _on_recipe_crafted(recipe_id: String, _result: Dictionary) -> void:
	craft_feedback_timer = 2.0
	craft_feedback_recipe = recipe_id
	queue_redraw()


func _process(delta: float) -> void:
	if craft_feedback_timer > 0.0:
		craft_feedback_timer -= delta
		if craft_feedback_timer <= 0.0:
			queue_redraw()
	if scrap_feedback_timer > 0.0:
		scrap_feedback_timer -= delta
		if scrap_feedback_timer <= 0.0:
			queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click: Vector2 = event.position

	# Tab clicks
	var tab_y: float = HEADER_HEIGHT
	if _is_in_rect(click, Rect2(10, tab_y, TAB_WIDTH, TAB_HEIGHT)):
		active_tab = Tab.VAULT
		queue_redraw()
		return
	if _is_in_rect(click, Rect2(10 + TAB_WIDTH + 4, tab_y, TAB_WIDTH, TAB_HEIGHT)):
		active_tab = Tab.RECIPES
		queue_redraw()
		return

	# Spotlight shift button (top right)
	var shift_rect := Rect2(size.x - 150, 4, 140, 26)
	if _is_in_rect(click, shift_rect):
		DemandManager.rotate_spotlight()
		return

	if active_tab == Tab.VAULT:
		_handle_vault_clicks(click)
	elif active_tab == Tab.RECIPES:
		_handle_recipe_clicks(click)


func _draw() -> void:
	if not visible:
		return

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.06, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.4, 0.6, 0.5), false, 2.0)

	_draw_header()
	_draw_tabs()

	match active_tab:
		Tab.VAULT:
			_draw_vault_content()
		Tab.RECIPES:
			_draw_recipes_content()


func _draw_header() -> void:
	# Title
	draw_string(ThemeDB.fallback_font, Vector2(12, 22), "CODEX [Tab]", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.85, 1.0))

	# Spotlight indicator
	var spotlight_family: String = DemandManager.active_spotlight
	var spotlight_col: Color = GameState.get_family_color(spotlight_family) if spotlight_family != "" else Color(0.5, 0.5, 0.5)
	var spotlight_text: String = "SPOTLIGHT: %s (%.1fx)" % [spotlight_family, DemandManager.spotlight_multiplier]
	draw_string(ThemeDB.fallback_font, Vector2(180, 22), spotlight_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, spotlight_col)

	# Shift button
	var shift_rect := Rect2(size.x - 150, 4, 140, 26)
	draw_rect(shift_rect, Color(0.12, 0.12, 0.2, 0.9))
	draw_rect(shift_rect, Color(0.4, 0.5, 0.7, 0.5), false, 1.0)
	draw_string(ThemeDB.fallback_font, shift_rect.position + Vector2(12, 18), "SHIFT SPOTLIGHT", HORIZONTAL_ALIGNMENT_LEFT, 120, 11, Color(0.8, 0.8, 0.9))

	# Active upgrades at bottom
	var upgrades: Dictionary = GameState.ship_upgrades
	if not upgrades.is_empty():
		var ux: float = 12
		var uy: float = size.y - 16
		draw_string(ThemeDB.fallback_font, Vector2(ux, uy), "UPGRADES:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.55, 0.65))
		ux += 75
		for stat in upgrades:
			var val = upgrades[stat]
			var label: String = ""
			match stat:
				"sync_rate":
					label = "SYNC +%.0f%%" % ((float(val) - 1.0) * 100)
				"max_health":
					label = "HULL +%d" % int(val)
				"warp_charge_time":
					label = "WARP %.1fs" % float(val)
			if label != "":
				draw_string(ThemeDB.fallback_font, Vector2(ux, uy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.7, 1.0))
				ux += 110


func _draw_tabs() -> void:
	var tab_y: float = HEADER_HEIGHT
	# VAULT tab
	var vault_bg: Color = Color(0.1, 0.1, 0.18, 0.9) if active_tab == Tab.VAULT else Color(0.06, 0.06, 0.1, 0.7)
	draw_rect(Rect2(10, tab_y, TAB_WIDTH, TAB_HEIGHT), vault_bg)
	draw_rect(Rect2(10, tab_y, TAB_WIDTH, TAB_HEIGHT), Color(0.3, 0.4, 0.6, 0.5), false, 1.0)
	var vault_text_col: Color = Color(0.9, 0.9, 1.0) if active_tab == Tab.VAULT else Color(0.5, 0.5, 0.6)
	draw_string(ThemeDB.fallback_font, Vector2(40, tab_y + 24), "VAULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, vault_text_col)

	# RECIPES tab
	var rx: float = 10 + TAB_WIDTH + 4
	var recipe_bg: Color = Color(0.1, 0.1, 0.18, 0.9) if active_tab == Tab.RECIPES else Color(0.06, 0.06, 0.1, 0.7)
	draw_rect(Rect2(rx, tab_y, TAB_WIDTH, TAB_HEIGHT), recipe_bg)
	draw_rect(Rect2(rx, tab_y, TAB_WIDTH, TAB_HEIGHT), Color(0.3, 0.4, 0.6, 0.5), false, 1.0)
	var recipe_text_col: Color = Color(0.9, 0.9, 1.0) if active_tab == Tab.RECIPES else Color(0.5, 0.5, 0.6)
	draw_string(ThemeDB.fallback_font, Vector2(rx + 22, tab_y + 24), "RECIPES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, recipe_text_col)


# ─── VAULT TAB ───


func _draw_vault_content() -> void:
	var content_y: float = HEADER_HEIGHT + TAB_HEIGHT + 10

	# Filter buttons
	_draw_filter_buttons(content_y)

	# Vault capacity
	var cap_text: String = "%d/%d SLOTS" % [RelicDB.vault.size(), GameState.vault_capacity]
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 110, content_y + 18), cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.6, 0.7))

	# Relic card grid
	var grid_y: float = content_y + FILTER_BTN_SIZE.y + 14
	var relics: Array[Dictionary] = RelicDB.get_vault_by_family(family_filter)
	if relics.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12, grid_y + 20), "No relics in vault." if family_filter == "" else "No %s relics." % family_filter, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.4, 0.5))
		return

	var cols: int = maxi(1, int((size.x - 20) / (CARD_SIZE.x + CARD_PADDING)))
	for i in range(relics.size()):
		var col: int = i % cols
		var row: int = i / cols
		var card_pos := Vector2(10 + col * (CARD_SIZE.x + CARD_PADDING), grid_y + row * (CARD_SIZE.y + CARD_PADDING))
		# Stop if card would go below the upgrades bar
		if card_pos.y + CARD_SIZE.y > size.y - 30:
			break
		var is_selected: bool = (i == selected_relic_index)
		_draw_relic_card(relics[i], card_pos, is_selected)

	# Scrap button and feedback (shown when a relic is selected)
	if selected_relic_index >= 0 and selected_relic_index < relics.size():
		var sel_relic: Dictionary = relics[selected_relic_index]
		var scrap_val: int = int(DemandManager.get_effective_value(sel_relic))
		var scrap_y: float = content_y + 1
		var scrap_x: float = size.x - SCRAP_BTN_SIZE.x - 130
		# Scrap button
		draw_rect(Rect2(scrap_x, scrap_y, SCRAP_BTN_SIZE.x, SCRAP_BTN_SIZE.y), Color(0.5, 0.12, 0.12, 0.9))
		draw_rect(Rect2(scrap_x, scrap_y, SCRAP_BTN_SIZE.x, SCRAP_BTN_SIZE.y), Color(0.7, 0.3, 0.3, 0.6), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(scrap_x + 8, scrap_y + 19), "SCRAP (+%d CR)" % scrap_val, HORIZONTAL_ALIGNMENT_LEFT, int(SCRAP_BTN_SIZE.x - 12), 11, Color(1.0, 0.8, 0.8))

	# Scrap feedback
	if scrap_feedback_timer > 0.0:
		var fb_x: float = size.x - 130
		var fb_y: float = content_y + 19
		draw_string(ThemeDB.fallback_font, Vector2(fb_x, fb_y), "SCRAPPED! +%d CR" % scrap_feedback_amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.5))


func _draw_filter_buttons(y: float) -> void:
	# ALL button
	var all_active: bool = family_filter == ""
	var all_bg: Color = Color(0.15, 0.15, 0.25, 0.9) if all_active else Color(0.08, 0.08, 0.12, 0.8)
	draw_rect(Rect2(10, y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y), all_bg)
	draw_rect(Rect2(10, y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y), Color(0.4, 0.4, 0.5, 0.5), false, 1.0)
	var all_col: Color = Color(0.9, 0.9, 1.0) if all_active else Color(0.5, 0.5, 0.6)
	draw_string(ThemeDB.fallback_font, Vector2(30, y + 18), "ALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, all_col)

	# Per-family buttons
	for i in range(FAMILIES.size()):
		var btn_x: float = 10 + (FILTER_BTN_SIZE.x + 6) * (i + 1)
		var fam: String = FAMILIES[i]
		var fam_col: Color = GameState.get_family_color(fam)
		var is_active: bool = family_filter == fam
		var bg: Color = Color(fam_col.r * 0.3, fam_col.g * 0.3, fam_col.b * 0.3, 0.9) if is_active else Color(0.06, 0.06, 0.1, 0.8)
		draw_rect(Rect2(btn_x, y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y), bg)
		draw_rect(Rect2(btn_x, y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y), Color(fam_col.r, fam_col.g, fam_col.b, 0.5), false, 1.0)
		var text_col: Color = fam_col if is_active else Color(fam_col.r * 0.6, fam_col.g * 0.6, fam_col.b * 0.6)
		draw_string(ThemeDB.fallback_font, Vector2(btn_x + 6, y + 18), fam, HORIZONTAL_ALIGNMENT_LEFT, int(FILTER_BTN_SIZE.x - 10), 10, text_col)


func _draw_relic_card(relic: Dictionary, pos: Vector2, is_selected: bool = false) -> void:
	var family: String = relic.get("family", "")
	var family_col: Color = GameState.get_family_color(family)
	var relic_id: String = relic.get("relic_id", "unknown")
	var rarity: int = relic.get("rarity", 1)
	var base_power: int = relic.get("base_power", 0)
	var eff_value: float = DemandManager.get_effective_value(relic)

	# Card background
	var bg_col: Color = Color(0.1, 0.08, 0.15, 0.95) if is_selected else Color(0.06, 0.06, 0.1, 0.9)
	draw_rect(Rect2(pos, CARD_SIZE), bg_col)
	# Family color bar on left
	draw_rect(Rect2(pos, Vector2(4, CARD_SIZE.y)), family_col)
	# Border — white highlight when selected
	var border_col: Color = Color(1.0, 1.0, 1.0, 0.8) if is_selected else Color(0.2, 0.25, 0.35, 0.6)
	draw_rect(Rect2(pos, CARD_SIZE), border_col, false, 1.5 if is_selected else 1.0)

	# Name
	var display_name: String = relic_id.replace("_", " ").to_upper()
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 18), display_name, HORIZONTAL_ALIGNMENT_LEFT, int(CARD_SIZE.x - 16), 11, Color(0.9, 0.9, 0.95))

	# Rarity stars
	for s in range(rarity):
		draw_circle(pos + Vector2(16 + s * 14, 36), 4.0, Color(1.0, 0.85, 0.2, 0.9))

	# Family label
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 56), family, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, family_col)

	# Power and value
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 76), "PWR %d" % base_power, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))
	draw_string(ThemeDB.fallback_font, pos + Vector2(CARD_SIZE.x - 76, 76), "VAL %.0f" % eff_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.3, 0.9, 0.5))


func _handle_vault_clicks(click: Vector2) -> void:
	var filter_y: float = HEADER_HEIGHT + TAB_HEIGHT + 10
	# ALL button
	if _is_in_rect(click, Rect2(10, filter_y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y)):
		family_filter = ""
		selected_relic_index = -1
		queue_redraw()
		return
	# Per-family buttons
	for i in range(FAMILIES.size()):
		var btn_x: float = 10 + (FILTER_BTN_SIZE.x + 6) * (i + 1)
		if _is_in_rect(click, Rect2(btn_x, filter_y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y)):
			family_filter = FAMILIES[i]
			selected_relic_index = -1
			queue_redraw()
			return

	# Scrap button click
	var relics: Array[Dictionary] = RelicDB.get_vault_by_family(family_filter)
	if selected_relic_index >= 0 and selected_relic_index < relics.size():
		var scrap_y: float = filter_y + 1
		var scrap_x: float = size.x - SCRAP_BTN_SIZE.x - 130
		if _is_in_rect(click, Rect2(scrap_x, scrap_y, SCRAP_BTN_SIZE.x, SCRAP_BTN_SIZE.y)):
			_scrap_selected_relic(relics)
			return

	# Relic card clicks
	var grid_y: float = filter_y + FILTER_BTN_SIZE.y + 14
	var cols: int = maxi(1, int((size.x - 20) / (CARD_SIZE.x + CARD_PADDING)))
	for i in range(relics.size()):
		var col: int = i % cols
		var row: int = i / cols
		var card_pos := Vector2(10 + col * (CARD_SIZE.x + CARD_PADDING), grid_y + row * (CARD_SIZE.y + CARD_PADDING))
		if card_pos.y + CARD_SIZE.y > size.y - 30:
			break
		if _is_in_rect(click, Rect2(card_pos, CARD_SIZE)):
			selected_relic_index = i if selected_relic_index != i else -1
			queue_redraw()
			return

	# Clicked empty space — deselect
	selected_relic_index = -1
	queue_redraw()


func _scrap_selected_relic(filtered_relics: Array[Dictionary]) -> void:
	if selected_relic_index < 0 or selected_relic_index >= filtered_relics.size():
		return
	var relic: Dictionary = filtered_relics[selected_relic_index]
	# Find the actual vault index for this relic instance
	var vault_index: int = -1
	for i in range(RelicDB.vault.size()):
		if RelicDB.vault[i] == relic:
			vault_index = i
			break
	if vault_index < 0:
		return
	var scrap_val: int = int(DemandManager.get_effective_value(relic))
	RelicDB.remove_from_vault(vault_index)
	CreditLedger.earn(scrap_val, CreditLedger.Source.RELIC_SCRAP, {"relic_id": relic.get("relic_id", ""), "family": relic.get("family", "")})
	scrap_feedback_amount = scrap_val
	scrap_feedback_timer = 2.0
	selected_relic_index = -1
	queue_redraw()


# ─── RECIPES TAB ───


func _draw_recipes_content() -> void:
	var recipe_ids: Array = DemandManager.recipes.keys()
	var y_start: float = HEADER_HEIGHT + TAB_HEIGHT + 14
	var recipe_height: float = 130.0

	if recipe_ids.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12, y_start + 20), "No recipes available.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.4, 0.5))
		return

	for i in range(recipe_ids.size()):
		var recipe_id: String = recipe_ids[i]
		var recipe: Dictionary = DemandManager.recipes[recipe_id]
		var recipe_y: float = y_start + i * (recipe_height + 8)
		if recipe_y + recipe_height > size.y - 30:
			break
		_draw_recipe_panel(recipe_id, recipe, Vector2(10, recipe_y), recipe_height)


func _draw_recipe_panel(recipe_id: String, recipe: Dictionary, pos: Vector2, height: float) -> void:
	var panel_width: float = size.x - 20
	var already_crafted: bool = DemandManager.is_crafted(recipe_id)
	var craftable: bool = DemandManager.can_craft(recipe_id)

	# Panel background
	var bg_col: Color = Color(0.04, 0.06, 0.04, 0.9) if already_crafted else Color(0.05, 0.05, 0.09, 0.9)
	draw_rect(Rect2(pos, Vector2(panel_width, height)), bg_col)
	var border_col: Color = Color(0.15, 0.35, 0.2, 0.6) if already_crafted else Color(0.2, 0.25, 0.35, 0.5)
	draw_rect(Rect2(pos, Vector2(panel_width, height)), border_col, false, 1.0)

	# Recipe name
	var name_text: String = recipe.get("name", recipe_id)
	var name_col: Color = Color(0.6, 0.8, 0.6) if already_crafted else Color(0.95, 0.95, 1.0)
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 20), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, name_col)

	# Description
	var desc: String = recipe.get("description", "")
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 38), desc, HORIZONTAL_ALIGNMENT_LEFT, int(panel_width - 160), 11, Color(0.55, 0.55, 0.65))

	# Ingredients
	var ingredients: Array = recipe.get("ingredients", [])
	var ing_y: float = 52.0
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, ing_y + 14), "Requires:", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.55, 0.65))
	ing_y += 18.0
	for ingredient in ingredients:
		var relic_id: String = ingredient.get("relic_id", "")
		var needed: int = ingredient.get("quantity", 0)
		var owned: int = RelicDB.count_relic(relic_id)
		var display_name: String = relic_id.replace("_", " ").to_upper()
		var has_enough: bool = owned >= needed
		var count_color: Color = Color(0.3, 0.9, 0.4) if has_enough else Color(0.9, 0.3, 0.3)
		draw_string(ThemeDB.fallback_font, pos + Vector2(24, ing_y + 14), "%s  %d/%d" % [display_name, owned, needed], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, count_color)
		ing_y += 16.0

	# Result summary
	var result: Dictionary = recipe.get("result", {})
	var result_text: String = _get_result_text(result)
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, height - 12), "Result: %s" % result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.65, 1.0))

	# Craft button or CRAFTED badge
	var btn_pos := Vector2(pos.x + panel_width - CRAFT_BTN_SIZE.x - 12, pos.y + height - CRAFT_BTN_SIZE.y - 10)
	if already_crafted:
		draw_rect(Rect2(btn_pos, CRAFT_BTN_SIZE), Color(0.08, 0.2, 0.1, 0.8))
		draw_rect(Rect2(btn_pos, CRAFT_BTN_SIZE), Color(0.2, 0.5, 0.3, 0.5), false, 1.0)
		draw_string(ThemeDB.fallback_font, btn_pos + Vector2(18, 22), "CRAFTED", HORIZONTAL_ALIGNMENT_CENTER, int(CRAFT_BTN_SIZE.x), 13, Color(0.4, 0.8, 0.5))
	else:
		var btn_color: Color = Color(0.12, 0.45, 0.2, 0.9) if craftable else Color(0.12, 0.12, 0.18, 0.7)
		draw_rect(Rect2(btn_pos, CRAFT_BTN_SIZE), btn_color)
		draw_rect(Rect2(btn_pos, CRAFT_BTN_SIZE), Color(0.4, 0.5, 0.6, 0.5), false, 1.0)
		var btn_text_col: Color = Color(1.0, 1.0, 1.0) if craftable else Color(0.35, 0.35, 0.45)
		draw_string(ThemeDB.fallback_font, btn_pos + Vector2(30, 22), "CRAFT", HORIZONTAL_ALIGNMENT_CENTER, int(CRAFT_BTN_SIZE.x), 13, btn_text_col)

	# Craft success feedback
	if craft_feedback_recipe == recipe_id and craft_feedback_timer > 0.0:
		draw_string(ThemeDB.fallback_font, btn_pos + Vector2(-80, 22), "CRAFTED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 1.0, 0.5))


func _handle_recipe_clicks(click: Vector2) -> void:
	var recipe_ids: Array = DemandManager.recipes.keys()
	var y_start: float = HEADER_HEIGHT + TAB_HEIGHT + 14
	var recipe_height: float = 130.0
	for i in range(recipe_ids.size()):
		var recipe_id: String = recipe_ids[i]
		var recipe_y: float = y_start + i * (recipe_height + 8)
		var panel_width: float = size.x - 20
		# Craft button hitbox
		var btn_pos := Vector2(10 + panel_width - CRAFT_BTN_SIZE.x - 12, recipe_y + recipe_height - CRAFT_BTN_SIZE.y - 10)
		if _is_in_rect(click, Rect2(btn_pos, CRAFT_BTN_SIZE)):
			if DemandManager.can_craft(recipe_id):
				DemandManager.craft_recipe(recipe_id)
			return


func _get_result_text(result: Dictionary) -> String:
	var rtype: String = result.get("type", "")
	match rtype:
		"ship_modifier":
			var stat: String = result.get("stat", "")
			var value = result.get("value", 0)
			match stat:
				"sync_rate":
					return "+%.0f%% sync rate" % ((float(value) - 1.0) * 100)
				"max_health":
					return "+%d max health" % int(value)
				"warp_charge_time":
					return "%.1f sec warp time" % float(value)
				_:
					return "%s %s" % [stat, str(value)]
		"vault_capacity":
			return "+%d vault slots" % int(result.get("value", 0))
		_:
			return str(result)


func _is_in_rect(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)
