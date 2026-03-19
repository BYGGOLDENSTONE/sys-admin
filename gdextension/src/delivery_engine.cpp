#include "delivery_engine.h"
#include "packed_key.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void DeliveryEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("deliver_arrived", "conns",
        "conn_target_types", "conn_target_filters", "conn_target_bids",
        "target_ports", "output_ports", "splitter_next"),
        &DeliveryEngine::deliver_arrived);
}

DeliveryEngine::DeliveryEngine() {}
DeliveryEngine::~DeliveryEngine() {}

Dictionary DeliveryEngine::deliver_arrived(
    Array conns,
    PackedInt32Array conn_target_types,
    PackedInt32Array conn_target_filters,
    Array conn_target_bids,
    Dictionary target_ports,
    Dictionary output_ports,
    Dictionary splitter_next)
{
    Array remaining;
    Array working;

    int conn_count = conns.size();
    const int32_t *types_ptr = conn_target_types.ptr();
    const int32_t *filters_ptr = conn_target_filters.ptr();

    for (int ci = 0; ci < conn_count; ci++) {
        Dictionary conn = conns[ci];
        if (!conn.has("transit")) continue;

        Array transit = conn["transit"];
        if (transit.size() == 0) continue;

        // Check if front item has arrived
        Dictionary front = transit[0];
        double front_t = (double)front["t"];
        if (front_t < 1.0) continue;

        // Get target building info from pre-computed arrays
        int type = types_ptr[ci];
        int64_t bid = (int64_t)conn_target_bids[ci];

        if (type == TYPE_TRASH) {
            // Trash: remove all arrived items instantly
            bool did_work = false;
            while (transit.size() > 0) {
                Dictionary item = transit[0];
                if ((double)item["t"] < 1.0) break;
                transit.remove_at(0);
                did_work = true;
            }
            if (did_work) {
                working.push_back(bid);
            }
        } else if (type >= TYPE_CLASSIFIER && type <= TYPE_MERGER) {
            // Routing buildings: passthrough
            int filter = filters_ptr[ci];
            bool did_work = false;

            while (transit.size() > 0) {
                Dictionary item = transit[0];
                if ((double)item["t"] < 1.0) break;

                if (_try_routing(conns, item, bid, type, filter,
                                 target_ports, output_ports, splitter_next)) {
                    transit.remove_at(0);
                    did_work = true;
                } else {
                    // Passthrough failed — leave for GDScript fallback
                    remaining.push_back(ci);
                    break;
                }
            }
            if (did_work) {
                working.push_back(bid);
            }
        } else {
            // Regular or inline: let GDScript handle
            remaining.push_back(ci);
        }
    }

    Dictionary result;
    result["remaining"] = remaining;
    result["working"] = working;
    return result;
}

bool DeliveryEngine::_try_routing(
    Array &conns,
    Dictionary &item,
    int64_t bid,
    int type,
    int filter,
    Dictionary &target_ports,
    Dictionary &output_ports,
    Dictionary &splitter_next)
{
    // Get output port names for this building
    if (!target_ports.has(bid)) return false;
    Array ports = target_ports[bid];
    if (ports.size() == 0) return false;

    String output_port;

    // Extract content/state from packed key for routing decisions
    int64_t packed_key = (int64_t)item["key"];
    int item_content = unpack_content(packed_key);
    int item_state = unpack_state(packed_key);

    switch (type) {
        case TYPE_CLASSIFIER: {
            if (ports.size() < 2) return false;
            if (!output_ports.has(bid)) return false;
            Dictionary bid_ports = output_ports[bid];
            String p0 = ports[0];
            String p1 = ports[1];
            if (!bid_ports.has(p0) || !bid_ports.has(p1)) return false;
            output_port = (item_content == filter) ? p0 : p1;
            break;
        }
        case TYPE_SCANNER: {
            if (ports.size() < 2) return false;
            if (!output_ports.has(bid)) return false;
            Dictionary bid_ports = output_ports[bid];
            String p0 = ports[0];
            String p1 = ports[1];
            if (!bid_ports.has(p0) || !bid_ports.has(p1)) return false;
            int item_sub_type = unpack_sub_type(packed_key);
            output_port = (item_sub_type == filter) ? p0 : p1;
            break;
        }
        case TYPE_SEPARATOR_STATE: {
            if (ports.size() < 2) return false;
            if (!output_ports.has(bid)) return false;
            Dictionary bid_ports = output_ports[bid];
            String p0 = ports[0];
            String p1 = ports[1];
            if (!bid_ports.has(p0) || !bid_ports.has(p1)) return false;
            output_port = (item_state == filter) ? p0 : p1;
            break;
        }
        case TYPE_SEPARATOR_CONTENT: {
            if (ports.size() < 2) return false;
            if (!output_ports.has(bid)) return false;
            Dictionary bid_ports = output_ports[bid];
            String p0 = ports[0];
            String p1 = ports[1];
            if (!bid_ports.has(p0) || !bid_ports.has(p1)) return false;
            output_port = (item_content == filter) ? p0 : p1;
            break;
        }
        case TYPE_SPLITTER: {
            int port_count = ports.size();
            if (port_count == 0) return false;
            int next_idx = 0;
            if (splitter_next.has(bid)) {
                next_idx = (int)(int64_t)splitter_next[bid];
            }
            next_idx = next_idx % port_count;
            output_port = ports[next_idx];
            splitter_next[bid] = (next_idx + 1) % port_count;
            break;
        }
        case TYPE_MERGER: {
            output_port = ports[0];
            break;
        }
        default:
            return false;
    }

    // Find output connection for this port
    if (!output_ports.has(bid)) return false;
    Dictionary bid_ports = output_ports[bid];
    if (!bid_ports.has(output_port)) return false;
    int out_ci = (int)(int64_t)bid_ports[output_port];

    if (out_ci < 0 || out_ci >= conns.size()) return false;

    // Check if output cable is stalled (front item at t >= 1.0)
    Dictionary out_conn = conns[out_ci];
    if (out_conn.has("transit")) {
        Array out_transit = out_conn["transit"];
        if (out_transit.size() > 0) {
            Dictionary out_front = out_transit[0];
            if ((double)out_front["t"] >= 1.0) {
                return false; // Output cable stalled
            }
        }
    }

    // Forward: create slim transit item (key + amount + t only)
    Dictionary new_item;
    new_item["key"] = item["key"];
    new_item["amount"] = item["amount"];
    new_item["t"] = 0.0;

    if (!out_conn.has("transit")) {
        out_conn["transit"] = Array();
    }
    Array out_transit = out_conn["transit"];
    out_transit.push_back(new_item);

    return true;
}
