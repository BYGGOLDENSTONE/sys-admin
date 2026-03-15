extends Node

## Tracks level progression: current level, max reached, win condition.

signal level_completed(level: int)

var current_level: int = 1
var max_level_reached: int = 1

var _completed_levels: Dictionary = {}  ## level_idx → true
var _win_triggered: bool = false  ## Prevents double-fire


func check_win_condition(connected: int, total: int) -> void:
	## Called when network coverage changes. Emits level_completed at 100%.
	if _win_triggered:
		return
	if total <= 0 or connected < total:
		return
	# Level 9 (endless) has no win condition
	var data: Dictionary = LevelConfig.get_level(current_level)
	if data.is_infinite:
		return
	# Already completed this level in a previous session
	if _completed_levels.has(current_level):
		return

	_win_triggered = true
	_completed_levels[current_level] = true
	if current_level < LevelConfig.MAX_LEVEL:
		max_level_reached = maxi(max_level_reached, current_level + 1)
	print("[LevelManager] Level %d completed — network 100%%" % current_level)
	level_completed.emit(current_level)


func start_level(level: int) -> void:
	current_level = clampi(level, 1, LevelConfig.MAX_LEVEL)
	_win_triggered = false
	print("[LevelManager] Starting level %d" % current_level)


func is_level_completed(level: int) -> bool:
	return _completed_levels.has(level)


func get_save_data() -> Dictionary:
	var completed: Array = []
	for lvl in _completed_levels:
		completed.append(lvl)
	return {
		"current_level": current_level,
		"max_level_reached": max_level_reached,
		"completed_levels": completed,
	}


func load_save_data(data: Dictionary) -> void:
	current_level = int(data.get("current_level", 1))
	max_level_reached = int(data.get("max_level_reached", 1))
	_completed_levels.clear()
	for lvl in data.get("completed_levels", []):
		_completed_levels[int(lvl)] = true
	_win_triggered = _completed_levels.has(current_level)
