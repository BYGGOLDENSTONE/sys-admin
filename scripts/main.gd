extends Node2D

@onready var grid_system: Node2D = $GridSystem
@onready var building_manager: Node = $BuildingManager
@onready var building_panel: PanelContainer = $UILayer/BuildingPanel
@onready var camera: Camera2D = $GameCamera
@onready var ui_layer: CanvasLayer = $UILayer
@onready var connection_manager: Node = $ConnectionManager
@onready var connection_layer: Node2D = $ConnectionLayer
@onready var simulation_manager = $SimulationManager
@onready var source_manager: Node = $SourceManager
@onready var source_container: Node2D = $SourceContainer

var _tooltip_scene: PackedScene = preload("res://scenes/ui/building_tooltip.tscn")
var _MapGeneratorScript = preload("res://scripts/map_generator.gd")
var _tooltip: PanelContainer = null
var _undo_manager: Node = null
var _map_generator: RefCounted = null
var _current_seed: int = 0
var _dev_mode: bool = false
var _top_bar: PanelContainer = null
var _shortcut_hints: Label = null
var _shortcut_bg: PanelContainer = null
var _prev_hint_state: int = -1
var _prev_hint_selected: bool = false
var _sound_manager: Node = null
var _gig_manager: Node = null
var _gig_panel: PanelContainer = null
var _contract_terminal: Node2D = null
var _tutorial_manager: Node = null
var _save_manager: Node = null
var _pause_overlay: CanvasLayer = null
var _pause_buttons: VBoxContainer = null
var _pause_options: VBoxContainer = null
var _is_pause_menu_open: bool = false
var _was_paused_before_menu: bool = false
var _demo_complete_shown: bool = false
var _last_cam_pos: Vector2 = Vector2.ZERO
var _benchmark: BenchmarkRunner = null

const WISHLIST_URL: String = "https://store.steampowered.com/app/PLACEHOLDER_APP_ID/SYS_ADMIN/"
const FEEDBACK_URL: String = "https://store.steampowered.com/app/PLACEHOLDER_APP_ID/SYS_ADMIN/discussions/"

## Set this BEFORE _ready() to load a saved game instead of starting new
var load_save_data: Dictionary = {}


func _ready() -> void:
	# Apply saved settings (master volume + fullscreen)
	SettingsManager.apply_all(SettingsManager.get_settings())

	building_panel.building_selected.connect(building_manager.start_placement)

	# Setup tooltip
	_tooltip = _tooltip_scene.instantiate()
	ui_layer.add_child(_tooltip)
	building_manager.building_hovered.connect(_tooltip.show_for_building)
	building_manager.building_unhovered.connect(_tooltip.hide_tooltip)
	building_manager.source_hovered.connect(_tooltip.show_for_source)
	building_manager.source_unhovered.connect(_tooltip.hide_tooltip)

	# Wire up connection system
	connection_manager.grid_system = grid_system
	building_manager.connection_manager = connection_manager
	building_manager.connection_layer = connection_layer
	connection_layer.connection_manager = connection_manager
	connection_layer.simulation_manager = simulation_manager

	# Auto-remove connections when building is removed
	building_manager.building_removed.connect(connection_manager.remove_connections_for)

	# Wire up simulation
	simulation_manager.connection_manager = connection_manager
	simulation_manager.building_container = $BuildingContainer
	simulation_manager.source_manager = source_manager
	# Dirty-flag connection cache on topology changes
	connection_manager.connection_added.connect(simulation_manager._invalidate_conn_cache)
	connection_manager.connection_removed.connect(simulation_manager._invalidate_conn_cache)
	building_manager.building_placed.connect(simulation_manager._on_building_placed)
	building_manager.building_removed.connect(simulation_manager._on_building_removed)
	simulation_manager.content_discovered.connect(_on_content_discovered)
	simulation_manager.state_discovered.connect(_on_state_discovered)

	# Setup building detail view (upgrade panel integrated into building panel)
	building_panel.setup_detail(simulation_manager)
	building_manager.building_selected.connect(building_panel.show_building_detail)
	building_manager.building_deselected.connect(building_panel.hide_building_detail)
	building_manager.building_state_changed.connect(building_panel.refresh_detail)
	building_manager.building_state_changed.connect(_tooltip.refresh)

	# Setup gig manager
	_setup_gig_manager()

	# Setup gig panel
	_setup_gig_panel()

	# Setup top bar
	_setup_top_bar()

	# Wire up speed control
	simulation_manager.speed_changed.connect(_on_speed_changed)
	_top_bar.update_speed(1, false)

	# Setup undo manager
	var UndoManagerScript = preload("res://scripts/undo_manager.gd")
	_undo_manager = Node.new()
	_undo_manager.set_script(UndoManagerScript)
	_undo_manager.name = "UndoManager"
	add_child(_undo_manager)
	_undo_manager.building_manager = building_manager
	_undo_manager.connection_manager = connection_manager
	_undo_manager.grid_system = grid_system
	_undo_manager.source_manager = source_manager
	building_manager.undo_manager = _undo_manager

	# Wire up source manager
	source_manager.grid_system = grid_system
	source_manager.source_container = source_container
	building_manager.source_manager = source_manager
	building_manager.building_removed.connect(source_manager.on_building_removed)

	# Determine seed: from save, command-line, or random
	var is_loading: bool = not load_save_data.is_empty()
	if is_loading:
		_current_seed = int(load_save_data.get("seed", randi()))
	else:
		_current_seed = _get_seed_from_args()

	# Seed-based procedural map generation (infinite chunk-based)
	_map_generator = _MapGeneratorScript.new()
	_map_generator.generate_map(_current_seed, source_manager)
	_last_cam_pos = camera.position

	# Setup save manager (before loading state)
	_setup_save_manager()

	# Setup tutorial manager BEFORE gig initialization (so Gig 1 hint is received)
	_setup_tutorial_manager()

	# Give save manager access to map generator for chunk save/load
	_save_manager.map_generator = _map_generator

	# Set active save slot
	var slot: int = int(load_save_data.get("_slot", load_save_data.get("slot", 1)))
	_save_manager.current_slot = slot

	if is_loading and load_save_data.has("seed"):
		# LOAD PATH: restore saved state (includes chunk regeneration)
		_save_manager.apply_state(load_save_data)
		# Find Contract Terminal from loaded buildings
		for child in $BuildingContainer.get_children():
			if child.definition != null and child.definition.building_name == "Contract Terminal":
				_contract_terminal = child
				break
		if _contract_terminal != null and _gig_manager != null:
			_gig_manager.set_contract_terminal(_contract_terminal)
		# Rebuild UI from loaded state
		building_panel.refresh_buttons()
		if _gig_panel:
			_gig_panel.rebuild_from_state()
		# Clear undo stack (fresh session)
		if _undo_manager:
			_undo_manager._undo_stack.clear()
			_undo_manager._redo_stack.clear()
		load_save_data = {}
		print("[Main] Game loaded from save")
		# Procedural gigs — no finale check needed
	else:
		# NEW GAME PATH: place Contract Terminal and initialize gigs
		_place_contract_terminal()
		_gig_manager.initialize()

	# Wire terminal click to gig panel
	building_manager.building_selected.connect(_on_building_selected_for_panel)

	# Center camera on map center
	camera.position = Vector2(256 * 64 + 64, 256 * 64 + 64)

	# Update seed in top bar
	_top_bar.update_seed(_current_seed)

	# Setup shortcut hints
	_setup_shortcut_hints()

	# Setup sound manager
	_setup_sound_manager()

	# Wire gig completion to autosave
	_gig_manager.gig_completed.connect(_on_gig_completed_autosave)

	# Pass post-process material to camera for chromatic aberration
	var post_rect: ColorRect = $PostProcessLayer/PostProcessRect
	camera.set_post_material(post_rect.material as ShaderMaterial)

	# Apply CRT setting from saved preferences
	var _settings := SettingsManager.get_settings()
	if post_rect.material is ShaderMaterial:
		(post_rect.material as ShaderMaterial).set_shader_parameter(
			"scanlines_enabled", _settings.get("crt_enabled", true))

	# Start autosave
	_save_manager.setup_autosave()

	# Setup in-game pause menu (ESC)
	_setup_pause_menu()

	# Enable close request notification for crash save
	get_tree().set_auto_accept_quit(false)

	print("[Main] SYS_ADMIN initialized — %s" % ("loaded save" if is_loading else "new game"))

	# Auto-run benchmark if --benchmark CLI arg is present
	if "--benchmark" in OS.get_cmdline_user_args():
		_run_benchmark()


func _process(_delta: float) -> void:
	# Reset per-frame aggregate stats
	PerfMonitor.reset_building_stats()
	# Update shortcut hints when context changes
	if building_manager and _shortcut_bg and _shortcut_bg.visible:
		var cur_state: int = building_manager._state
		var cur_sel: bool = building_manager._selected_building != null
		if cur_state != _prev_hint_state or cur_sel != _prev_hint_selected:
			_prev_hint_state = cur_state
			_prev_hint_selected = cur_sel
			_update_shortcut_hints()
		# Keep centered (panel auto-sizes to content)
		_center_shortcut_panel()
	# Lazy chunk generation — generate sources as camera reveals new areas
	if _map_generator and camera:
		var cam_pos: Vector2 = camera.global_position
		if cam_pos.distance_squared_to(_last_cam_pos) > 4096.0:  # ~1 tile movement threshold
			_last_cam_pos = cam_pos
			var vp_size: Vector2 = get_viewport_rect().size / camera.zoom
			_map_generator.try_generate_visible_chunks(cam_pos, vp_size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Crash-safe: save before closing
		if _save_manager:
			_save_manager.autosave()
			print("[Main] Emergency save on close")
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	# ESC: toggle pause menu (always available)
	if event.keycode == KEY_ESCAPE:
		_toggle_pause_menu()
		return
	# Block all other input when pause menu is open
	if _is_pause_menu_open:
		return
	if event.ctrl_pressed:
		match event.keycode:
			KEY_Z:
				_undo_manager.undo()
				_undo_manager.safe_reset_undoing()
			KEY_Y:
				_undo_manager.redo()
				_undo_manager.safe_reset_undoing()
			KEY_S:
				if _save_manager:
					_save_manager.save_game()
					_show_gig_notification("GAME SAVED", Color("#44ddff"))
		return
	match event.keycode:
		KEY_SPACE:
			simulation_manager.toggle_pause()
		KEY_1:
			simulation_manager.set_speed(1)
		KEY_2:
			simulation_manager.set_speed(2)
		KEY_3:
			simulation_manager.set_speed(3)
		KEY_F7:
			_run_benchmark()
		KEY_H:
			_toggle_shortcut_hints()
		KEY_G:
			if _gig_panel:
				_gig_panel.toggle()
		KEY_Q:
			# Center camera on Contract Terminal
			camera.center_on(Vector2(256 * 64 + 64, 256 * 64 + 64))


func _run_benchmark(auto_report: bool = false) -> void:
	if _benchmark != null:
		print("[Benchmark] --- Live Stats ---")
		print(_benchmark.get_summary())
		return
	_benchmark = BenchmarkRunner.new()
	_benchmark.setup(building_manager, connection_manager, grid_system, simulation_manager, source_manager)
	_benchmark.run(auto_report)


func _get_seed_from_args() -> int:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--seed="):
			return int(arg.substr(7))
	return randi()


func _setup_top_bar() -> void:
	var TopBarScript = preload("res://scripts/ui/top_bar.gd")
	_top_bar = PanelContainer.new()
	_top_bar.set_script(TopBarScript)
	_top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	_top_bar.offset_right = -224.0  # Leave space for building panel
	ui_layer.add_child(_top_bar)



func _setup_shortcut_hints() -> void:
	# Background panel for readability
	_shortcut_bg = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.08, 0.75)
	style.border_color = Color(0.15, 0.35, 0.5, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.content_margin_left = 14
	style.content_margin_right = 14
	_shortcut_bg.add_theme_stylebox_override("panel", style)
	_shortcut_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_shortcut_bg)

	_shortcut_hints = Label.new()
	_shortcut_hints.add_theme_font_override("font", preload("res://assets/fonts/JetBrainsMono-Regular.ttf"))
	_shortcut_hints.add_theme_font_size_override("font_size", 11)
	_shortcut_hints.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 0.85))
	_shortcut_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shortcut_hints.autowrap_mode = TextServer.AUTOWRAP_OFF
	_shortcut_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shortcut_bg.add_child(_shortcut_hints)
	_update_shortcut_hints()


func _center_shortcut_panel() -> void:
	if _shortcut_bg == null:
		return
	var vp_w: float = get_viewport().get_visible_rect().size.x
	var panel_w: float = _shortcut_bg.size.x
	_shortcut_bg.position = Vector2((vp_w - panel_w) / 2.0, 6.0)


func _update_shortcut_hints() -> void:
	if _shortcut_hints == null:
		return
	var ctx: String = ""
	var bm_state: int = building_manager._state if building_manager else 0
	match bm_state:
		1:  # PLACING
			ctx = "LMB Place | RMB Cancel | R Rotate | T Mirror | Shift+T V-Mirror"
		2:  # CONNECTING
			ctx = "LMB Connect | RMB Cancel"
		3:  # MOVING
			ctx = "LMB Place | RMB Cancel"
		4:  # BOX_SELECTING
			ctx = "Release to Select | RMB Cancel"
		5:  # COPYING
			ctx = "LMB Paste | RMB Cancel"
		_:  # IDLE
			var has_sel: bool = building_manager._selected_building != null if building_manager else false
			var has_multi: bool = not building_manager._selected_buildings.is_empty() if building_manager else false
			if has_multi:
				ctx = "C Copy | Del Delete | Shift+Drag Re-select"
			elif has_sel:
				ctx = "R Rotate | T Mirror | Shift+T V-Mirror | E Filter | C Copy | Ctrl+LMB Move | RMB Delete"
			else:
				ctx = "LMB Select | RMB Delete | Ctrl+LMB Move | Shift+Drag Select"
	var line1: String = ctx
	var line2: String = "Esc Menu | Space Pause | 1-3 Speed | G Contracts | Q Center | Ctrl+S Save | Ctrl+Z Undo | H Hide"
	_shortcut_hints.text = line1 + "\n" + line2
	# Re-center after text change
	call_deferred("_center_shortcut_panel")


func _toggle_shortcut_hints() -> void:
	if _shortcut_bg == null:
		return
	_shortcut_bg.visible = not _shortcut_bg.visible




func _on_speed_changed(multiplier: int, paused: bool) -> void:
	_top_bar.update_speed(multiplier, paused)


func _setup_gig_manager() -> void:
	var GigManagerScript = preload("res://scripts/gig_manager.gd")
	_gig_manager = Node.new()
	_gig_manager.set_script(GigManagerScript)
	_gig_manager.name = "GigManager"
	_gig_manager.building_container = $BuildingContainer
	add_child(_gig_manager)
	# Wire to building panel
	building_panel._gig_manager = _gig_manager
	building_panel.refresh_buttons()
	# Wire unlock signals
	_gig_manager.building_unlocked.connect(_on_building_unlocked)
	_gig_manager.gig_completed.connect(_on_gig_completed)
	_gig_manager.gig_activated.connect(_on_gig_activated)
	_gig_manager.gig_progress_updated.connect(_on_gig_progress_sound)
	# Process deliveries after each simulation tick
	simulation_manager.tick_completed.connect(_on_tick_for_gig)
	simulation_manager.tick_completed.connect(_on_tick_refresh_ui)
	# NOTE: initialize() is called later — after load check in _ready()


func _setup_gig_panel() -> void:
	var GigPanelScript = preload("res://scripts/ui/gig_panel.gd")
	_gig_panel = PanelContainer.new()
	_gig_panel.set_script(GigPanelScript)
	_gig_panel.anchor_left = 0.0
	_gig_panel.anchor_top = 0.0
	_gig_panel.anchor_right = 0.0
	_gig_panel.anchor_bottom = 1.0
	_gig_panel.offset_left = 10.0
	_gig_panel.offset_right = 360.0
	_gig_panel.offset_top = 44.0
	_gig_panel.offset_bottom = -10.0
	ui_layer.add_child(_gig_panel)
	_gig_panel.setup(_gig_manager)
	_gig_panel.play_slide_in()


func _on_building_selected_for_panel(building: Node2D) -> void:
	if building == _contract_terminal and _gig_panel:
		_gig_panel.show_panel()


func _place_contract_terminal() -> void:
	var terminal_def := load("res://resources/buildings/contract_terminal.tres") as BuildingDefinition
	if terminal_def == null:
		push_error("[Main] Cannot load Contract Terminal definition")
		return
	# Center the building at MAP_CENTER (offset by half grid size)
	var center := Vector2i(256 - terminal_def.grid_size.x / 2, 256 - terminal_def.grid_size.y / 2)
	var cell := _find_clear_cell(center, terminal_def.grid_size)
	_contract_terminal = building_manager.place_building_at(terminal_def, cell)
	if _contract_terminal != null and _gig_manager != null:
		_gig_manager.set_contract_terminal(_contract_terminal)
		print("[Main] Contract Terminal placed at (%d,%d)" % [cell.x, cell.y])
	else:
		push_error("[Main] Failed to place Contract Terminal")


func _find_clear_cell(center: Vector2i, building_size: Vector2i) -> Vector2i:
	## Spiral search for a clear cell near center
	if grid_system.can_place(center, building_size):
		return center
	for radius in range(1, 20):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue  # Only check perimeter
				var cell := center + Vector2i(dx, dy)
				if grid_system.can_place(cell, building_size):
					return cell
	return center  # Fallback


func _on_tick_for_gig(_tick_count: int) -> void:
	if _gig_manager:
		_gig_manager.process_deliveries()


func _on_tick_refresh_ui(_tick_count: int) -> void:
	_tooltip.refresh()
	building_panel.refresh_detail()


func _on_gig_completed(gig) -> void:
	_show_gig_notification("GIG COMPLETE: %s" % gig.gig_name, Color("#44ff88"))
	if _sound_manager:
		_sound_manager.play_gig_complete()
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.25)
	if _tutorial_manager:
		_tutorial_manager.on_gig_completed(gig)
	# Check if finale gig (The Net Heist) is done → demo complete
	if not _demo_complete_shown and _gig_manager and _gig_manager.is_gig_completed(18):
		_demo_complete_shown = true
		# Delay to let the last gig complete notification play first
		get_tree().create_timer(2.5).timeout.connect(_show_demo_complete)


func _on_gig_activated(gig) -> void:
	_show_gig_notification("NEW GIG: %s" % gig.gig_name, Color("#00bbee"))
	building_panel.refresh_buttons()
	if _tutorial_manager:
		_tutorial_manager.on_gig_activated(gig)


func _on_gig_progress_sound(_gig, _req_index: int, _current: int, _target: int) -> void:
	if _sound_manager:
		_sound_manager.play_delivery()


func _show_gig_notification(text: String, color: Color) -> void:
	var notif := Label.new()
	notif.text = ">> %s <<" % text
	notif.add_theme_font_size_override("font_size", 24)
	notif.add_theme_color_override("font_color", color)
	notif.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	notif.add_theme_constant_override("outline_size", 5)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 120
	notif.modulate = Color(1, 1, 1, 0)
	notif.scale = Vector2(0.5, 0.5)
	notif.pivot_offset = Vector2(notif.size.x / 2.0, notif.size.y / 2.0)
	ui_layer.add_child(notif)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(notif, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2(1.05, 1.05), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.15).set_delay(0.25)
	tween.tween_property(notif, "position:y", 105.0, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "modulate:a", 0.0, 0.8).set_delay(2.0)
	tween.chain().tween_callback(notif.queue_free)


func _on_building_unlocked(building_name: String) -> void:
	print("[Main] Building unlocked: %s" % building_name)
	_show_unlock_notification(building_name)
	if _sound_manager:
		_sound_manager.play_unlock()
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.18)
	if _tutorial_manager:
		_tutorial_manager.on_building_unlocked(building_name)


func _show_unlock_notification(building_name: String) -> void:
	var notif := Label.new()
	notif.text = ">> %s UNLOCKED <<" % building_name.to_upper()
	notif.add_theme_font_size_override("font_size", 20)
	notif.add_theme_color_override("font_color", Color("#aa77ff"))
	notif.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	notif.add_theme_constant_override("outline_size", 4)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 110
	notif.modulate = Color(1, 1, 1, 0)
	notif.scale = Vector2(0.5, 0.5)
	notif.pivot_offset = Vector2(notif.size.x / 2.0, notif.size.y / 2.0)
	ui_layer.add_child(notif)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(notif, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2(1.05, 1.05), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.15).set_delay(0.25)
	tween.tween_property(notif, "position:y", 95.0, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "modulate:a", 0.0, 0.8).set_delay(2.0)
	tween.chain().tween_callback(notif.queue_free)



func _on_content_discovered(content: int) -> void:
	var display_name: String = DataEnums.content_name(content).to_upper() + " DATA"
	var color: Color = DataEnums.content_color(content)
	_show_discovery_notification(display_name, color)


func _on_state_discovered(state: int) -> void:
	var display_name: String = DataEnums.state_name(state).to_upper() + " STATE"
	var color: Color = DataEnums.state_color(state)
	_show_discovery_notification(display_name, color)


func _show_discovery_notification(display_name: String, color: Color) -> void:
	var notif := Label.new()
	notif.text = "[ %s DISCOVERED ]" % display_name
	notif.add_theme_font_size_override("font_size", 22)
	notif.add_theme_color_override("font_color", color)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.anchors_preset = Control.PRESET_CENTER_TOP
	notif.position.y = 80
	notif.modulate = Color(1, 1, 1, 0)
	notif.scale = Vector2(0.8, 0.8)
	notif.pivot_offset = Vector2(notif.size.x / 2.0, notif.size.y / 2.0)
	ui_layer.add_child(notif)

	# Pop-in + glow + float-up + fade-out
	var tween := create_tween().set_parallel(true)
	# Pop in
	tween.tween_property(notif, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(notif, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Float up
	tween.tween_property(notif, "position:y", 60.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade out
	tween.tween_property(notif, "modulate:a", 0.0, 0.8).set_delay(2.2).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(notif.queue_free)

	# Camera shake + discovery sound — stronger for impact
	if camera.has_method("add_trauma"):
		camera.add_trauma(0.18)
	if _sound_manager:
		_sound_manager.play_discovery()


func _setup_tutorial_manager() -> void:
	var TutorialManagerScript = preload("res://scripts/tutorial_manager.gd")
	_tutorial_manager = Node.new()
	_tutorial_manager.set_script(TutorialManagerScript)
	_tutorial_manager.name = "TutorialManager"
	add_child(_tutorial_manager)
	_tutorial_manager.setup(ui_layer)


func _setup_sound_manager() -> void:
	var SoundManagerScript = preload("res://scripts/sound_manager.gd")
	_sound_manager = Node.new()
	_sound_manager.set_script(SoundManagerScript)
	_sound_manager.name = "SoundManager"
	add_child(_sound_manager)
	# Wire simulation sound
	simulation_manager.sound_manager = _sound_manager
	# Wire building events
	building_manager.building_placed.connect(_on_building_placed_sound)
	building_manager.building_removed.connect(_on_building_removed_sound)
	# Wire cable events
	connection_manager.connection_added.connect(_on_cable_connected_sound)
	connection_manager.connection_removed.connect(_on_cable_removed_sound)
	# City Control: update network coverage on connection changes
	connection_manager.connection_added.connect(func(_c): _update_city_control())
	connection_manager.connection_removed.connect(func(_c): _update_city_control())
	# Port Purity: pre-populate cable types at connection time (blocks before first tick)
	connection_manager.connection_added.connect(_gig_manager.on_ct_connection_added)
	# Port Purity: clear port tracking when cable disconnected from CT
	connection_manager.connection_removed.connect(_gig_manager.on_ct_connection_removed)


func _update_city_control() -> void:
	if _top_bar == null or source_manager == null:
		return
	var all_sources: Array[Node2D] = source_manager.get_all_sources()
	var total: int = all_sources.size()
	var connected: int = 0
	for source in all_sources:
		for conn in connection_manager.connections:
			if conn.from_building == source:
				connected += 1
				break
	_top_bar.update_city_control(connected, total)


func _on_building_placed_sound(_building: Node2D, _cell: Vector2i) -> void:
	_sound_manager.play_building_place()


func _on_building_removed_sound(_building: Node2D, _cell: Vector2i) -> void:
	_sound_manager.play_building_remove()


func _on_cable_connected_sound(_conn: Dictionary) -> void:
	_sound_manager.play_cable_connect()


func _on_cable_removed_sound(_conn: Dictionary) -> void:
	_sound_manager.play_cable_remove()


func _setup_save_manager() -> void:
	var SaveManagerScript = preload("res://scripts/save_manager.gd")
	_save_manager = Node.new()
	_save_manager.set_script(SaveManagerScript)
	_save_manager.name = "SaveManager"
	_save_manager.building_container = $BuildingContainer
	_save_manager.connection_manager = connection_manager
	_save_manager.source_manager = source_manager
	_save_manager.gig_manager = _gig_manager
	_save_manager.simulation_manager = simulation_manager
	_save_manager.current_seed = _current_seed
	add_child(_save_manager)


func _on_gig_completed_autosave(_gig) -> void:
	if _save_manager:
		_save_manager.autosave()


func _toggle_dev_mode() -> void:
	_dev_mode = not _dev_mode
	source_manager.set_dev_mode(_dev_mode)
	_top_bar.set_dev_visible(_dev_mode)
	_update_shortcut_hints()
	print("[Main] Dev mode: %s" % ("ON" if _dev_mode else "OFF"))


# --- Pause Menu ---

func _setup_pause_menu() -> void:
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.layer = 100
	_pause_overlay.visible = false
	add_child(_pause_overlay)

	# Dark overlay (blocks mouse input to game)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.04, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)

	var main_box := VBoxContainer.new()
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_theme_constant_override("separation", 0)
	center.add_child(main_box)

	# PAUSED title
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	main_box.add_child(spacer)

	# Pause buttons
	_pause_buttons = VBoxContainer.new()
	_pause_buttons.add_theme_constant_override("separation", 12)
	_pause_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(_pause_buttons)

	var resume_btn := _create_pause_button("Resume")
	resume_btn.pressed.connect(_close_pause_menu)
	_pause_buttons.add_child(resume_btn)

	var options_btn := _create_pause_button("Options")
	options_btn.pressed.connect(_show_pause_options)
	_pause_buttons.add_child(options_btn)

	var save_btn := _create_pause_button("Save Game")
	save_btn.pressed.connect(_on_pause_save)
	_pause_buttons.add_child(save_btn)

	var feedback_btn := _create_pause_button("Give Feedback")
	feedback_btn.pressed.connect(_on_pause_feedback)
	_pause_buttons.add_child(feedback_btn)

	var quit_btn := _create_pause_button("Quit to Menu")
	quit_btn.pressed.connect(_on_pause_quit)
	_pause_buttons.add_child(quit_btn)

	# Options sub-panel (hidden, swaps with buttons)
	var OptionsPanelScript = preload("res://scripts/ui/options_panel.gd")
	_pause_options = VBoxContainer.new()
	_pause_options.set_script(OptionsPanelScript)
	_pause_options.visible = false
	_pause_options.back_pressed.connect(_hide_pause_options)
	_pause_options.settings_changed.connect(_on_settings_changed)
	main_box.add_child(_pause_options)


func _create_pause_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 46)
	btn.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.9)
	style.border_color = Color(0.0, 0.7, 0.8, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.07, 0.1, 0.16, 0.95)
	hover.border_color = Color(0.0, 0.9, 1.0, 0.9)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.03, 0.05, 0.08, 1.0)
	pressed.border_color = Color(0.0, 1.0, 1.0, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	return btn


func _toggle_pause_menu() -> void:
	if _is_pause_menu_open:
		_close_pause_menu()
	else:
		_open_pause_menu()


func _open_pause_menu() -> void:
	_is_pause_menu_open = true
	_was_paused_before_menu = simulation_manager.is_paused
	if not simulation_manager.is_paused:
		simulation_manager.toggle_pause()
	_pause_overlay.visible = true
	_pause_buttons.visible = true
	_pause_options.visible = false


func _close_pause_menu() -> void:
	_is_pause_menu_open = false
	_pause_overlay.visible = false
	_pause_buttons.visible = true
	_pause_options.visible = false
	if not _was_paused_before_menu and simulation_manager.is_paused:
		simulation_manager.toggle_pause()


func _show_pause_options() -> void:
	_pause_buttons.visible = false
	_pause_options.visible = true


func _hide_pause_options() -> void:
	_pause_options.visible = false
	_pause_buttons.visible = true
	if _sound_manager:
		_sound_manager.apply_settings()


func _on_pause_save() -> void:
	if _save_manager:
		_save_manager.save_game()
	_show_gig_notification("GAME SAVED", Color("#44ddff"))


func _on_pause_feedback() -> void:
	OS.shell_open(FEEDBACK_URL)


func _on_pause_quit() -> void:
	if _save_manager:
		_save_manager.autosave()
	var menu_scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	get_tree().root.add_child(menu)
	queue_free()


func _on_settings_changed() -> void:
	if _sound_manager:
		_sound_manager.apply_settings()
	# Apply CRT toggle to post-process shader
	var settings := SettingsManager.get_settings()
	var post_rect: ColorRect = $PostProcessLayer/PostProcessRect
	if post_rect and post_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = post_rect.material
		mat.set_shader_parameter("scanlines_enabled", settings.get("crt_enabled", true))
	# Update autosave interval
	if _save_manager:
		_save_manager.update_autosave_interval(int(settings.get("autosave_interval", 300)))


# --- Demo Complete Screen ---

func _show_demo_complete() -> void:
	print("[Main] All gigs completed — showing demo complete screen")

	# Pause simulation
	if not simulation_manager.is_paused:
		simulation_manager.toggle_pause()

	var overlay := CanvasLayer.new()
	overlay.layer = 99
	add_child(overlay)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.04, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	# Fade in background
	var bg_tw := create_tween()
	bg_tw.tween_property(bg, "color:a", 0.85, 1.0)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var main_box := VBoxContainer.new()
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_theme_constant_override("separation", 0)
	center.add_child(main_box)

	# "DEMO COMPLETE" title
	var title := Label.new()
	title.text = "DEMO COMPLETE"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.6, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "The full network awaits."
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	main_box.add_child(spacer)

	# Flavor text
	var flavor := Label.new()
	flavor.text = "You've proven yourself, operator. Higher-tier data streams\nand deeper networks are waiting in the full release."
	flavor.add_theme_font_size_override("font_size", 15)
	flavor.add_theme_color_override("font_color", Color(0.4, 0.55, 0.65, 0.7))
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(flavor)

	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 32)
	main_box.add_child(spacer2)

	# Buttons
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 14)
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	main_box.add_child(btn_box)

	var wishlist_btn := _create_demo_complete_button("Wishlist Full Game", Color(0.0, 1.0, 0.6))
	wishlist_btn.pressed.connect(func(): OS.shell_open(WISHLIST_URL))
	btn_box.add_child(wishlist_btn)

	var feedback_btn := _create_demo_complete_button("Give Feedback", Color(0.3, 0.7, 1.0))
	feedback_btn.pressed.connect(func(): OS.shell_open(FEEDBACK_URL))
	btn_box.add_child(feedback_btn)

	var continue_btn := _create_demo_complete_button("Continue Playing", Color(0.6, 0.65, 0.7))
	continue_btn.pressed.connect(func():
		overlay.queue_free()
		if simulation_manager.is_paused:
			simulation_manager.toggle_pause()
	)
	btn_box.add_child(continue_btn)

	# Fade in content
	main_box.modulate = Color(1, 1, 1, 0)
	var content_tw := create_tween()
	content_tw.tween_property(main_box, "modulate:a", 1.0, 0.8).set_delay(0.5)


func _create_demo_complete_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 52)
	btn.add_theme_font_size_override("font_size", 21)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.07, 0.1, 0.16, 0.95)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = Color(0.03, 0.05, 0.08, 1.0)
	pressed.border_color = Color(accent.r, accent.g, accent.b, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(accent.r * 0.8 + 0.2, accent.g * 0.8 + 0.2, accent.b * 0.8 + 0.2))
	btn.add_theme_color_override("font_hover_color", accent)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	return btn
