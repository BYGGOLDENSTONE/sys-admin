#include "stall_propagator.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void StallPropagator::_bind_methods() {
    ClassDB::bind_method(D_METHOD("propagate_stalls", "direct_stalls", "conn_from", "conn_to", "max_passes"), &StallPropagator::propagate_stalls);
}

StallPropagator::StallPropagator() {}
StallPropagator::~StallPropagator() {}

Dictionary StallPropagator::propagate_stalls(Dictionary direct_stalls, Dictionary conn_from, Dictionary conn_to, int max_passes) {
    // Start with a copy of direct stalls
    Dictionary stalled = direct_stalls.duplicate();

    for (int pass = 0; pass < max_passes; pass++) {
        Dictionary newly_stalled;
        Array building_ids = conn_from.keys();
        int bid_count = building_ids.size();

        for (int b = 0; b < bid_count; b++) {
            Variant bid = building_ids[b];
            Array out_indices = conn_from[bid];
            int out_count = out_indices.size();
            if (out_count == 0) continue;

            // Check if ALL outputs of this building are stalled
            bool all_blocked = true;
            for (int o = 0; o < out_count; o++) {
                Variant oi = out_indices[o];
                if (!stalled.has(oi) && !newly_stalled.has(oi)) {
                    all_blocked = false;
                    break;
                }
            }
            if (!all_blocked) continue;

            // All outputs blocked — mark all input connections to this building as stalled
            if (!conn_to.has(bid)) continue;
            Array in_indices = conn_to[bid];
            int in_count = in_indices.size();
            for (int ii = 0; ii < in_count; ii++) {
                Variant idx = in_indices[ii];
                if (!stalled.has(idx)) {
                    newly_stalled[idx] = true;
                }
            }
        }

        if (newly_stalled.is_empty()) break;
        stalled.merge(newly_stalled);
    }

    return stalled;
}
