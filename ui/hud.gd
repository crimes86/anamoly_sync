extends CanvasLayer
## In-sector HUD showing sync progress, ship status, orbit tier, warp/edge jump, and fuel.

@onready var sync_bar: ProgressBar = $SyncBar
@onready var health_bar: ProgressBar = $HealthBar
@onready var warp_bar: ProgressBar = $WarpBar
@onready var orbit_label: Label = $OrbitLabel
@onready var sector_label: Label = $SectorLabel
@onready var credits_label: Label = $CreditsLabel
@onready var fuel_label: Label = $FuelLabel
@onready var relic_popup: Label = $RelicPopup
@onready var edge_jump_bar: ProgressBar = $EdgeJumpBar
@onready var edge_jump_label: Label = $EdgeJumpLabel

var relic_popup_timer: float = 0.0


func _ready() -> void:
	if relic_popup:
		relic_popup.visible = false
	if edge_jump_bar:
		edge_jump_bar.visible = false
	if edge_jump_label:
		edge_jump_label.visible = false
	_update_credits()
	_update_fuel()
	GameState.credits_changed.connect(_on_credits_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)


func _process(delta: float) -> void:
	if relic_popup_timer > 0.0:
		relic_popup_timer -= delta
		if relic_popup_timer <= 0.0 and relic_popup:
			relic_popup.visible = false


func update_sync_bar(progress: float) -> void:
	if sync_bar:
		sync_bar.value = progress * 100.0


func update_health(current: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current


func update_warp_bar(progress: float) -> void:
	if warp_bar:
		warp_bar.value = progress * 100.0


func update_orbit_tier(tier: String) -> void:
	if orbit_label:
		match tier:
			"home":
				orbit_label.text = "DOCKED"
				orbit_label.modulate = Color(0.9, 0.7, 0.2)
			"core":
				orbit_label.text = "CORE ORBIT"
				orbit_label.modulate = Color(1.0, 0.3, 0.3)
			"mid":
				orbit_label.text = "MID ORBIT"
				orbit_label.modulate = Color(1.0, 0.8, 0.3)
			"outer":
				orbit_label.text = "OUTER ORBIT"
				orbit_label.modulate = Color(0.3, 0.8, 1.0)
			_:
				orbit_label.text = "OUT OF RANGE"
				orbit_label.modulate = Color(0.5, 0.5, 0.5)


func set_sector_info(sector_id: String, family: String) -> void:
	if sector_label:
		sector_label.text = "%s | %s" % [sector_id, family]


func show_relic_acquired(family: String) -> void:
	if relic_popup:
		relic_popup.text = "RELIC ACQUIRED [%s]" % family
		relic_popup.visible = true
		relic_popup_timer = 3.0


func update_edge_jump_bar(progress: float) -> void:
	if edge_jump_bar:
		edge_jump_bar.visible = progress > 0.0
		edge_jump_bar.value = progress * 100.0


func show_edge_jump_indicator(direction: String) -> void:
	if edge_jump_label:
		edge_jump_label.text = "JUMPING %s..." % direction.to_upper()
		edge_jump_label.visible = true
	if edge_jump_bar:
		edge_jump_bar.visible = true
		edge_jump_bar.value = 0.0


func hide_edge_jump_indicator() -> void:
	if edge_jump_label:
		edge_jump_label.visible = false
	if edge_jump_bar:
		edge_jump_bar.visible = false


func _update_credits() -> void:
	if credits_label:
		credits_label.text = "%d CR" % GameState.player_credits


func _update_fuel() -> void:
	if fuel_label:
		fuel_label.text = "FUEL %.0f/%.0f" % [GameState.fuel, GameState.max_fuel]


func _on_credits_changed(_new_total: int) -> void:
	_update_credits()


func _on_fuel_changed(_current: float, _max_fuel: float) -> void:
	_update_fuel()
