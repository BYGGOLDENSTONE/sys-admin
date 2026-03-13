class_name PerfMonitor
## Centralized performance monitor — static vars updated by hot-path scripts,
## exposed via Godot's Performance.add_custom_monitor() for debugger Monitors tab.

# --- Simulation Manager ---
static var sim_cache_us: float = 0.0        ## _rebuild_conn_cache() microseconds
static var sim_transit_us: float = 0.0       ## _advance_transit() microseconds
static var sim_deliver_us: float = 0.0       ## _deliver_arrived() microseconds
static var sim_tick_us: float = 0.0          ## _on_sim_tick() total microseconds
static var sim_connections: int = 0          ## Total connection count
static var sim_transit_items: int = 0        ## Total transit items in flight

# --- Connection Layer ---
static var conn_draw_us: float = 0.0         ## _draw() total microseconds
static var conn_draw_items_us: float = 0.0   ## _draw_transit_items() total microseconds
static var conn_draw_calls: int = 0          ## Number of _draw_transit_items() calls per frame

# --- Grid System ---
static var grid_draw_us: float = 0.0         ## _draw() total microseconds
static var grid_pcb_us: float = 0.0          ## _draw_pcb_pattern() microseconds

# --- Buildings ---
static var bldg_draw_us: float = 0.0         ## Aggregate _draw() microseconds (all buildings)
static var bldg_draw_count: int = 0          ## Number of buildings drawn this frame
static var bldg_total_count: int = 0         ## Total building count

# --- Frame totals ---
static var frame_sim_us: float = 0.0         ## sim _process() total (cache + transit + deliver)

static var _registered: bool = false


static func register_monitors() -> void:
	if _registered:
		return
	_registered = true

	# Simulation
	Performance.add_custom_monitor("sysadmin/sim_cache_us", func(): return sim_cache_us)
	Performance.add_custom_monitor("sysadmin/sim_transit_us", func(): return sim_transit_us)
	Performance.add_custom_monitor("sysadmin/sim_deliver_us", func(): return sim_deliver_us)
	Performance.add_custom_monitor("sysadmin/sim_tick_us", func(): return sim_tick_us)
	Performance.add_custom_monitor("sysadmin/sim_connections", func(): return sim_connections)
	Performance.add_custom_monitor("sysadmin/sim_transit_items", func(): return sim_transit_items)

	# Connection Layer
	Performance.add_custom_monitor("sysadmin/conn_draw_us", func(): return conn_draw_us)
	Performance.add_custom_monitor("sysadmin/conn_draw_items_us", func(): return conn_draw_items_us)
	Performance.add_custom_monitor("sysadmin/conn_draw_calls", func(): return conn_draw_calls)

	# Grid System
	Performance.add_custom_monitor("sysadmin/grid_draw_us", func(): return grid_draw_us)
	Performance.add_custom_monitor("sysadmin/grid_pcb_us", func(): return grid_pcb_us)

	# Buildings
	Performance.add_custom_monitor("sysadmin/bldg_draw_us", func(): return bldg_draw_us)
	Performance.add_custom_monitor("sysadmin/bldg_draw_count", func(): return bldg_draw_count)
	Performance.add_custom_monitor("sysadmin/bldg_total_count", func(): return bldg_total_count)

	# Frame total
	Performance.add_custom_monitor("sysadmin/frame_sim_us", func(): return frame_sim_us)

	print("[PerfMonitor] %d custom monitors registered" % 14)


## Call once per frame from building container to reset aggregate building stats
static func reset_building_stats() -> void:
	bldg_draw_us = 0.0
	bldg_draw_count = 0
	bldg_total_count = 0
