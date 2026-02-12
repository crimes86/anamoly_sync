extends Control
## Relay Market panel: buy specific relics from NPC network for credits.

var family_filter: String = ""
var buy_feedback_timer: float = 0.0
var buy_feedback_relic: String = ""

const CARD_SIZE: Vector2 = Vector2(220, 100)
const CARD_PADDING: float = 10.0
const HEADER_HEIGHT: float = 36.0
const FILTER_BTN_SIZE: Vector2 = Vector2(80, 26)
const BUY_BTN_SIZE: Vector2 = Vector2(90, 26)
const PRICE_MULTIPLIER: float = 2.5
const FAMILIES: Array[String] = ["FRACTAL", "VOID", "PULSE", "DRIFT", "ECHO"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	RelicDB.vault_changed.connect(_on_data_changed)
	GameState.credits_changed.connect(_on_credits_changed)
	DemandManager.demand_updated.connect(_on_data_changed)


func _on_data_changed(_args: Variant = null) -> void:
	if visible:
		queue_redraw()


func _on_credits_changed(_new_total: int) -> void:
	if visible:
		queue_redraw()


func _process(delta: float) -> void:
	if buy_feedback_timer > 0.0:
		buy_feedback_timer -= delta
		if buy_feedback_timer <= 0.0:
			queue_redraw()


func _get_buy_price(relic: Dictionary) -> int:
	return int(ceilf(DemandManager.get_effective_value(relic) * PRICE_MULTIPLIER))


func _get_sorted_relics() -> Array[Dictionary]:
	## Get all relic definitions, optionally filtered by family, sorted by family then rarity.
	var results: Array[Dictionary] = []
	for relic_id in RelicDB.relic_definitions:
		var relic: Dictionary = RelicDB.relic_definitions[relic_id]
		if family_filter == "" or relic.get("family", "") == family_filter:
			results.append(relic)
	results.sort_custom(func(a, b):
		if a.get("family", "") != b.get("family", ""):
			return a.get("family", "") < b.get("family", "")
		return a.get("rarity", 0) < b.get("rarity", 0)
	)
	return results


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click: Vector2 = event.position

	# Filter button clicks
	var filter_y: float = HEADER_HEIGHT + 8
	if _is_in_rect(click, Rect2(10, filter_y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y)):
		family_filter = ""
		queue_redraw()
		return
	for i in range(FAMILIES.size()):
		var btn_x: float = 10 + (FILTER_BTN_SIZE.x + 6) * (i + 1)
		if _is_in_rect(click, Rect2(btn_x, filter_y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y)):
			family_filter = FAMILIES[i]
			queue_redraw()
			return

	# Buy button clicks on relic cards
	var relics: Array[Dictionary] = _get_sorted_relics()
	var grid_y: float = filter_y + FILTER_BTN_SIZE.y + 14
	var cols: int = maxi(1, int((size.x - 20) / (CARD_SIZE.x + CARD_PADDING)))
	for i in range(relics.size()):
		var col: int = i % cols
		var row: int = i / cols
		var card_pos := Vector2(10 + col * (CARD_SIZE.x + CARD_PADDING), grid_y + row * (CARD_SIZE.y + CARD_PADDING))
		if card_pos.y + CARD_SIZE.y > size.y - 20:
			break
		var btn_pos := Vector2(card_pos.x + CARD_SIZE.x - BUY_BTN_SIZE.x - 8, card_pos.y + CARD_SIZE.y - BUY_BTN_SIZE.y - 8)
		if _is_in_rect(click, Rect2(btn_pos, BUY_BTN_SIZE)):
			_try_buy_relic(relics[i])
			return


func _try_buy_relic(relic_def: Dictionary) -> void:
	var price: int = _get_buy_price(relic_def)
	if GameState.player_credits < price:
		return
	if RelicDB.vault.size() >= GameState.vault_capacity:
		return
	if not CreditLedger.spend(price, "Relay Purchase", {"relic_id": relic_def.get("relic_id", "")}):
		return
	var relic_copy: Dictionary = relic_def.duplicate()
	RelicDB.add_to_vault(relic_copy)
	buy_feedback_relic = relic_def.get("relic_id", "")
	buy_feedback_timer = 2.0
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.06, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.35, 0.55, 0.5), false, 2.0)

	# Header
	draw_string(ThemeDB.fallback_font, Vector2(12, 24), "RELAY MARKET [E]", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.75, 1.0))

	# Credits + vault capacity
	var credits_text: String = "%d CR" % GameState.player_credits
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 200, 24), credits_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.8, 0.3))
	var cap_text: String = "VAULT %d/%d" % [RelicDB.vault.size(), GameState.vault_capacity]
	var cap_col: Color = Color(0.9, 0.3, 0.3) if RelicDB.vault.size() >= GameState.vault_capacity else Color(0.6, 0.6, 0.7)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 200, 40), cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cap_col)

	# Filter buttons
	var filter_y: float = HEADER_HEIGHT + 8
	_draw_filter_buttons(filter_y)

	# Buy feedback
	if buy_feedback_timer > 0.0:
		var fb_name: String = buy_feedback_relic.replace("_", " ").to_upper()
		draw_string(ThemeDB.fallback_font, Vector2(size.x / 2 - 60, filter_y + 18), "PURCHASED %s!" % fb_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.5))

	# Relic grid
	var relics: Array[Dictionary] = _get_sorted_relics()
	var grid_y: float = filter_y + FILTER_BTN_SIZE.y + 14
	if relics.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(12, grid_y + 20), "No relics available.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.4, 0.5))
		return

	var cols: int = maxi(1, int((size.x - 20) / (CARD_SIZE.x + CARD_PADDING)))
	for i in range(relics.size()):
		var col: int = i % cols
		var row: int = i / cols
		var card_pos := Vector2(10 + col * (CARD_SIZE.x + CARD_PADDING), grid_y + row * (CARD_SIZE.y + CARD_PADDING))
		if card_pos.y + CARD_SIZE.y > size.y - 20:
			break
		_draw_market_card(relics[i], card_pos)


func _draw_filter_buttons(y: float) -> void:
	# ALL button
	var all_active: bool = family_filter == ""
	var all_bg: Color = Color(0.15, 0.15, 0.25, 0.9) if all_active else Color(0.08, 0.08, 0.12, 0.8)
	draw_rect(Rect2(10, y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y), all_bg)
	draw_rect(Rect2(10, y, FILTER_BTN_SIZE.x, FILTER_BTN_SIZE.y), Color(0.4, 0.4, 0.5, 0.5), false, 1.0)
	var all_col: Color = Color(0.9, 0.9, 1.0) if all_active else Color(0.5, 0.5, 0.6)
	draw_string(ThemeDB.fallback_font, Vector2(30, y + 18), "ALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, all_col)

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


func _draw_market_card(relic: Dictionary, pos: Vector2) -> void:
	var family: String = relic.get("family", "")
	var family_col: Color = GameState.get_family_color(family)
	var relic_id: String = relic.get("relic_id", "unknown")
	var rarity: int = relic.get("rarity", 1)
	var base_power: int = relic.get("base_power", 0)
	var price: int = _get_buy_price(relic)
	var can_afford: bool = GameState.player_credits >= price
	var vault_full: bool = RelicDB.vault.size() >= GameState.vault_capacity
	var can_buy: bool = can_afford and not vault_full
	var owned: int = RelicDB.count_relic(relic_id)

	# Card background
	draw_rect(Rect2(pos, CARD_SIZE), Color(0.06, 0.06, 0.1, 0.9))
	# Family color bar on left
	draw_rect(Rect2(pos, Vector2(4, CARD_SIZE.y)), family_col)
	# Border
	draw_rect(Rect2(pos, CARD_SIZE), Color(0.25, 0.2, 0.35, 0.6), false, 1.0)

	# Name
	var display_name: String = relic_id.replace("_", " ").to_upper()
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 18), display_name, HORIZONTAL_ALIGNMENT_LEFT, int(CARD_SIZE.x - 16), 11, Color(0.9, 0.9, 0.95))

	# Rarity stars
	for s in range(rarity):
		draw_circle(pos + Vector2(16 + s * 14, 36), 4.0, Color(1.0, 0.85, 0.2, 0.9))

	# Family + owned count
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 56), family, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, family_col)
	if owned > 0:
		draw_string(ThemeDB.fallback_font, pos + Vector2(80, 56), "(%d owned)" % owned, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.6))

	# Power
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 76), "PWR %d" % base_power, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))

	# Price
	var price_col: Color = Color(0.9, 0.8, 0.3) if can_afford else Color(0.6, 0.3, 0.3)
	draw_string(ThemeDB.fallback_font, pos + Vector2(12, 90), "%d CR" % price, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, price_col)

	# Buy button
	var btn_pos := Vector2(pos.x + CARD_SIZE.x - BUY_BTN_SIZE.x - 8, pos.y + CARD_SIZE.y - BUY_BTN_SIZE.y - 8)
	var btn_bg: Color = Color(0.15, 0.35, 0.5, 0.9) if can_buy else Color(0.1, 0.1, 0.15, 0.7)
	draw_rect(Rect2(btn_pos, BUY_BTN_SIZE), btn_bg)
	draw_rect(Rect2(btn_pos, BUY_BTN_SIZE), Color(0.4, 0.5, 0.6, 0.5), false, 1.0)
	var btn_text: String = "VAULT FULL" if vault_full else "BUY"
	var btn_text_col: Color = Color(1.0, 1.0, 1.0) if can_buy else Color(0.35, 0.35, 0.45)
	draw_string(ThemeDB.fallback_font, btn_pos + Vector2(BUY_BTN_SIZE.x / 2 - 14, 18), btn_text, HORIZONTAL_ALIGNMENT_CENTER, int(BUY_BTN_SIZE.x), 11, btn_text_col)


func _is_in_rect(point: Vector2, rect: Rect2) -> bool:
	return rect.has_point(point)
