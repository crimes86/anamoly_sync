extends Node
## Relic database and vault management.
## Loads relic definitions from data/relics.json and manages the player vault.

signal vault_changed()

# All possible relics keyed by relic_id
var relic_definitions: Dictionary = {}

# Player vault: array of relic instances the player owns
var vault: Array[Dictionary] = []


func _ready() -> void:
	_load_relic_definitions()


func _load_relic_definitions() -> void:
	var file := FileAccess.open("res://data/relics.json", FileAccess.READ)
	if file == null:
		push_warning("RelicDB: Could not load relics.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_warning("RelicDB: Failed to parse relics.json")
		return
	var data: Dictionary = json.data
	for relic_id in data.get("relics", {}):
		relic_definitions[relic_id] = data["relics"][relic_id]
		relic_definitions[relic_id]["relic_id"] = relic_id


func get_relics_by_family(family: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for relic_id in relic_definitions:
		if relic_definitions[relic_id].get("family") == family:
			results.append(relic_definitions[relic_id])
	return results


func roll_relic(family: String) -> Dictionary:
	## Roll a random relic from the given anomaly family.
	## Rarity is weighted: common drops more than legendary.
	var candidates := get_relics_by_family(family)
	if candidates.is_empty():
		push_warning("RelicDB: No relics found for family '%s'" % family)
		return {}

	# Weighted random by inverse rarity (lower rarity = higher weight)
	var total_weight: float = 0.0
	var weights: Array[float] = []
	for relic in candidates:
		var w: float = 1.0 / float(relic.get("rarity", 1))
		weights.append(w)
		total_weight += w

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for i in range(candidates.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return candidates[i].duplicate()

	return candidates[-1].duplicate()


func add_to_vault(relic: Dictionary) -> bool:
	if vault.size() >= GameState.vault_capacity:
		return false
	vault.append(relic)
	vault_changed.emit()
	return true


func count_relic(relic_id: String) -> int:
	## Count how many of a specific relic the player owns.
	var count: int = 0
	for relic in vault:
		if relic.get("relic_id", "") == relic_id:
			count += 1
	return count


func get_vault_by_family(family: String) -> Array[Dictionary]:
	## Filter vault by family. Empty string returns all.
	var results: Array[Dictionary] = []
	for relic in vault:
		if family == "" or relic.get("family", "") == family:
			results.append(relic)
	return results


func consume_relics(relic_id: String, count: int) -> bool:
	## Remove 'count' relics with matching relic_id from vault.
	## Returns false if insufficient (no partial consumption).
	if count_relic(relic_id) < count:
		return false
	var removed: int = 0
	for i in range(vault.size() - 1, -1, -1):
		if vault[i].get("relic_id", "") == relic_id:
			vault.remove_at(i)
			removed += 1
			if removed >= count:
				break
	vault_changed.emit()
	return true


func remove_from_vault(index: int) -> Dictionary:
	## Remove a relic at the given vault index. Returns the removed relic.
	if index < 0 or index >= vault.size():
		return {}
	var relic: Dictionary = vault[index]
	vault.remove_at(index)
	vault_changed.emit()
	return relic


func get_vault_data() -> Array:
	return vault.duplicate()


func load_vault_data(data: Array) -> void:
	vault.clear()
	for item in data:
		vault.append(item)
	vault_changed.emit()
