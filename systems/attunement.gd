extends Node
## Handles anomaly sync/attunement logic.
## Attached to each anomaly instance in a sector.

signal sync_started()
signal sync_progress_changed(progress: float)
signal sync_completed(anomaly_family: String)
signal sync_lost()

# Sync state
var is_syncing: bool = false
var sync_progress: float = 0.0  # 0.0 to 1.0
var sync_complete: bool = false

# Anomaly properties (set by sector when spawning)
var anomaly_family: String = ""
var base_sync_rate: float = 0.1  # per second at base distance
var stability: float = 1.0

# De-sync rate when player leaves orbit
const DESYNC_RATE: float = 0.03  # per second

# Orbit tier thresholds (distance from anomaly center)
const ORBIT_CORE_RADIUS: float = 80.0
const ORBIT_MID_RADIUS: float = 180.0
const ORBIT_OUTER_RADIUS: float = 320.0

# Sync speed multipliers per orbit tier
const TIER_MULTIPLIERS: Dictionary = {
	"core": 3.0,
	"mid": 1.5,
	"outer": 0.6,
}


func get_orbit_tier(distance: float) -> String:
	if distance <= ORBIT_CORE_RADIUS:
		return "core"
	elif distance <= ORBIT_MID_RADIUS:
		return "mid"
	elif distance <= ORBIT_OUTER_RADIUS:
		return "outer"
	return "none"


func get_distance_modifier(distance: float) -> float:
	var tier := get_orbit_tier(distance)
	return TIER_MULTIPLIERS.get(tier, 0.0)


func update_sync(delta: float, distance_to_player: float, ship_modifier: float = 1.0) -> void:
	if sync_complete:
		return

	var tier := get_orbit_tier(distance_to_player)

	if tier == "none":
		# Player is outside orbit — de-sync
		if sync_progress > 0.0 and not sync_complete:
			sync_progress = maxf(0.0, sync_progress - DESYNC_RATE * delta)
			sync_progress_changed.emit(sync_progress)
			if sync_progress <= 0.0 and is_syncing:
				is_syncing = false
				sync_lost.emit()
		return

	# Player is in orbit — sync
	if not is_syncing:
		is_syncing = true
		sync_started.emit()

	var distance_mod := get_distance_modifier(distance_to_player)
	var sync_rate: float = base_sync_rate * distance_mod * ship_modifier * stability
	sync_progress = minf(1.0, sync_progress + sync_rate * delta)
	sync_progress_changed.emit(sync_progress)

	if sync_progress >= 1.0:
		sync_complete = true
		sync_completed.emit(anomaly_family)


func reset() -> void:
	is_syncing = false
	sync_progress = 0.0
	sync_complete = false
