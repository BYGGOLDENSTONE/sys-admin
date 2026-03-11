class_name SettingsManager
extends RefCounted

## Persistent user settings — audio volumes and display options.
## Stored as JSON in user://settings.json.

const SETTINGS_PATH: String = "user://settings.json"
static var _cache: Dictionary = {}


static func get_settings() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	_cache = _load_from_disk()
	return _cache


static func save(data: Dictionary) -> void:
	_cache = data
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[Settings] Cannot write settings")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[Settings] Saved")


static func apply_all(settings: Dictionary) -> void:
	## Apply master volume and display settings globally.
	var master: int = clampi(int(settings.get("master_volume", 80)), 0, 100)
	if master == 0:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, linear_to_db(master / 100.0))

	var fs: bool = settings.get("fullscreen", false)
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


static func _load_from_disk() -> Dictionary:
	var defaults := _defaults()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return defaults.duplicate()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return defaults.duplicate()
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return defaults.duplicate()
	file.close()
	var data: Dictionary = json.data
	for key in defaults:
		if not data.has(key):
			data[key] = defaults[key]
	return data


static func _defaults() -> Dictionary:
	return {
		"master_volume": 80,
		"sfx_volume": 80,
		"ambient_volume": 50,
		"fullscreen": false,
	}
