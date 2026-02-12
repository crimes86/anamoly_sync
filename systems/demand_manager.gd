extends Node
## Manages relic demand multipliers, spotlight rotations, and recipe requirements.
## Drives the long-tail economy by shifting which relic families are valuable.

signal spotlight_changed(family: String, multiplier: float)
signal demand_updated()
signal recipe_crafted(recipe_id: String, result: Dictionary)

# Current spotlight family and its multiplier
var active_spotlight: String = ""
var spotlight_multiplier: float = 1.0

# Demand multipliers per relic family (base = 1.0)
var family_demand: Dictionary = {}

# Recipe requirements: recipe_id -> array of {relic_id, quantity}
var recipes: Dictionary = {}

# Meta config loaded from data/meta_config.json
var meta_config: Dictionary = {}

# Recipes the player has already crafted (one-time only)
var crafted_recipes: Array[String] = []


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


func rotate_spotlight() -> void:
	## Cycle spotlight to the next family.
	var families: Array = meta_config.get("families", [])
	if families.is_empty():
		return
	var current_index: int = families.find(active_spotlight)
	var next_index: int = (current_index + 1) % families.size()
	set_spotlight(families[next_index], spotlight_multiplier)


func can_craft(recipe_id: String) -> bool:
	## Check if the player owns all ingredients for a recipe and hasn't crafted it yet.
	if not recipes.has(recipe_id):
		return false
	if recipe_id in crafted_recipes:
		return false
	var ingredients: Array = recipes[recipe_id].get("ingredients", [])
	for ingredient in ingredients:
		var relic_id: String = ingredient.get("relic_id", "")
		var needed: int = ingredient.get("quantity", 0)
		if RelicDB.count_relic(relic_id) < needed:
			return false
	return true


func is_crafted(recipe_id: String) -> bool:
	return recipe_id in crafted_recipes


func craft_recipe(recipe_id: String) -> bool:
	## Require ingredients in vault but don't consume them. One-time per recipe.
	if not can_craft(recipe_id):
		return false
	var recipe: Dictionary = recipes[recipe_id]

	# Mark as crafted (one-time)
	crafted_recipes.append(recipe_id)

	# Apply result
	var result: Dictionary = recipe.get("result", {})
	_apply_craft_result(result)
	recipe_crafted.emit(recipe_id, result)
	return true


func _apply_craft_result(result: Dictionary) -> void:
	var result_type: String = result.get("type", "")
	match result_type:
		"ship_modifier":
			var stat: String = result.get("stat", "")
			var value = result.get("value", 0)
			if stat == "sync_rate":
				# Multiplicative: chain multiply
				var current: float = GameState.ship_upgrades.get(stat, 1.0)
				GameState.ship_upgrades[stat] = current * float(value)
			else:
				# Additive: accumulate (max_health, warp_charge_time)
				var current: float = GameState.ship_upgrades.get(stat, 0.0)
				GameState.ship_upgrades[stat] = current + float(value)
		"vault_capacity":
			GameState.vault_capacity += int(result.get("value", 0))
