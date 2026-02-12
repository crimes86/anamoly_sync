extends Node
## Manages relic demand multipliers, spotlight rotations, and recipe requirements.
## Drives the long-tail economy by shifting which relic families are valuable.

signal spotlight_changed(family: String, multiplier: float)
signal demand_updated()

# Current spotlight family and its multiplier
var active_spotlight: String = ""
var spotlight_multiplier: float = 1.0

# Demand multipliers per relic family (base = 1.0)
var family_demand: Dictionary = {}

# Recipe requirements: recipe_id -> array of {relic_id, quantity}
var recipes: Dictionary = {}

# Meta config loaded from data/meta_config.json
var meta_config: Dictionary = {}


func _ready() -> void:
	_load_meta_config()
	_apply_initial_demand()


func _load_meta_config() -> void:
	var file := FileAccess.open("res://data/meta_config.json", FileAccess.READ)
	if file == null:
		push_warning("DemandManager: Could not load meta_config.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_warning("DemandManager: Failed to parse meta_config.json")
		return
	meta_config = json.data


func _apply_initial_demand() -> void:
	# Set base demand for all families
	for family in meta_config.get("families", []):
		family_demand[family] = 1.0

	# Load recipes
	recipes = meta_config.get("recipes", {})

	# Apply initial spotlight
	var spotlight: Dictionary = meta_config.get("spotlight", {})
	if not spotlight.is_empty():
		set_spotlight(spotlight.get("family", ""), spotlight.get("multiplier", 2.0))

	# Calculate recipe-driven demand
	_recalculate_recipe_demand()


func set_spotlight(family: String, multiplier: float) -> void:
	active_spotlight = family
	spotlight_multiplier = multiplier
	spotlight_changed.emit(family, multiplier)
	demand_updated.emit()


func _recalculate_recipe_demand() -> void:
	## Recipes that require specific relics boost demand for those families.
	for recipe_id in recipes:
		var ingredients: Array = recipes[recipe_id].get("ingredients", [])
		for ingredient in ingredients:
			var relic_id: String = ingredient.get("relic_id", "")
			var relic_def: Dictionary = RelicDB.relic_definitions.get(relic_id, {})
			var family: String = relic_def.get("family", "")
			if family != "":
				family_demand[family] = family_demand.get(family, 1.0) + 0.5


func get_effective_value(relic: Dictionary) -> float:
	var rarity_weight: float = float(relic.get("rarity", 1))
	var family: String = relic.get("family", "")
	var demand: float = family_demand.get(family, 1.0)

	# Apply spotlight bonus
	if family == active_spotlight:
		demand *= spotlight_multiplier

	return rarity_weight * demand * relic.get("base_power", 1)
