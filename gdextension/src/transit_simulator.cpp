#include "transit_simulator.h"
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>

using namespace godot;

void TransitSimulator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("advance_transit", "conns", "delta", "speed_multiplier"), &TransitSimulator::advance_transit);
    ClassDB::bind_method(D_METHOD("get_cable_length_grids", "conn", "tile_size"), &TransitSimulator::get_cable_length_grids);
}

TransitSimulator::TransitSimulator() {}
TransitSimulator::~TransitSimulator() {}

double TransitSimulator::get_cable_length_grids(Dictionary conn, int tile_size) {
    if (conn.has("_cached_cable_grids")) {
        return (double)conn["_cached_cable_grids"];
    }
    double total_length = 0.0;
    if (conn.has("_cached_total_length")) {
        total_length = (double)conn["_cached_total_length"];
    }
    double grids = total_length / (double)tile_size;
    if (grids < 1.0) grids = 1.0;
    conn["_cached_cable_grids"] = grids;
    return grids;
}

void TransitSimulator::advance_transit(Array conns, double delta, int speed_multiplier) {
    int conn_count = conns.size();
    for (int ci = 0; ci < conn_count; ci++) {
        Dictionary conn = conns[ci];
        if (!conn.has("transit")) continue;

        Array transit = conn["transit"];
        int item_count = transit.size();
        if (item_count == 0) continue;

        // If front item is stuck at destination, freeze entire cable
        Dictionary front = transit[0];
        double front_t = (double)front["t"];
        if (front_t >= 1.0) continue;

        // Get cable length in grids (use GDScript's cached value if available)
        double cable_grids = 0.0;
        if (conn.has("_cached_length_grids")) {
            cable_grids = (double)conn["_cached_length_grids"];
        } else if (conn.has("_cached_total_length")) {
            double total_length = (double)conn["_cached_total_length"];
            cable_grids = total_length / 64.0;  // TILE_SIZE = 64
        }
        if (cable_grids < 1.0) cable_grids = 1.0;

        double t_advance = (TRANSIT_GRIDS_PER_SEC * (double)speed_multiplier * delta) / cable_grids;
        double min_spacing = TRANSIT_MIN_SPACING_GRIDS / cable_grids;

        // Advance front-to-back: each item can't get closer than min_spacing to the one ahead
        double prev_t = 2.0; // sentinel: no limit for front item
        for (int i = 0; i < item_count; i++) {
            Dictionary item = transit[i];
            double old_t = (double)item["t"];
            double new_t = old_t + t_advance;
            if (new_t > 1.0) new_t = 1.0;
            if (i > 0) {
                double limit = prev_t - min_spacing;
                if (new_t > limit) new_t = limit;
            }
            // Never move backwards
            if (new_t < old_t) new_t = old_t;
            item["t"] = new_t;
            prev_t = new_t;
        }
    }
}
