extends Node
## Tracks all credit transactions and provides history.
## Thin wrapper over GameState.player_credits with logging.

signal transaction_logged(entry: Dictionary)

# Transaction history for current session
var ledger: Array[Dictionary] = []

enum Source {
	SYNC_COMPLETION,
	RELAY_CONTRIBUTION,
	RELIC_DEMAND_SPIKE,
	RECIPE_CRAFTING,
}

var source_names: Dictionary = {
	Source.SYNC_COMPLETION: "Sync Completion",
	Source.RELAY_CONTRIBUTION: "Relay Contribution",
	Source.RELIC_DEMAND_SPIKE: "Demand Spike",
	Source.RECIPE_CRAFTING: "Recipe Crafting",
}


func earn(amount: int, source: Source, metadata: Dictionary = {}) -> void:
	GameState.add_credits(amount)
	var entry := {
		"type": "earn",
		"amount": amount,
		"source": source,
		"source_name": source_names.get(source, "Unknown"),
		"metadata": metadata,
		"timestamp": Time.get_unix_time_from_system(),
	}
	ledger.append(entry)
	transaction_logged.emit(entry)


func spend(amount: int, description: String, metadata: Dictionary = {}) -> bool:
	if not GameState.spend_credits(amount):
		return false
	var entry := {
		"type": "spend",
		"amount": amount,
		"description": description,
		"metadata": metadata,
		"timestamp": Time.get_unix_time_from_system(),
	}
	ledger.append(entry)
	transaction_logged.emit(entry)
	return true


func get_balance() -> int:
	return GameState.player_credits


func get_recent_transactions(count: int = 10) -> Array[Dictionary]:
	var start := maxi(0, ledger.size() - count)
	return ledger.slice(start)
