#include "sim_kernel.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cstdlib>

using namespace godot;

void SimKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure_sources", "source_port_entries"), &SimKernel::configure_sources);
    ClassDB::bind_method(D_METHOD("configure_buildings", "building_entries"), &SimKernel::configure_buildings);
    ClassDB::bind_method(D_METHOD("configure_graph", "conn_from", "conn_to", "output_ports", "conn_push_meta"),
                         &SimKernel::configure_graph);
    ClassDB::bind_method(D_METHOD("run_tick", "conns", "splitter_next", "blocked_ports"), &SimKernel::run_tick);
    ClassDB::bind_method(D_METHOD("update_stalls", "conns", "building_active", "max_passes"), &SimKernel::update_stalls);
}

SimKernel::SimKernel() {}
SimKernel::~SimKernel() {}

// ─── Configuration ───

void SimKernel::configure_sources(Array source_port_entries) {
    _source_ports.clear();
    _source_defs.clear();
    std::unordered_map<int, int> src_id_to_def; // source instance_id → def index

    for (int i = 0; i < source_port_entries.size(); i++) {
        Dictionary e = source_port_entries[i];
        SourcePort sp;
        sp.conn_idx = (int)(int64_t)e["conn_idx"];
        sp.gen_rate = (int)(int64_t)e["gen_rate"];
        sp.src_bid = (int64_t)e["src_bid"];
        sp.from_port = String(e.get("from_port", String()));
        int src_id = (int)(int64_t)e["src_id"];

        auto it = src_id_to_def.find(src_id);
        if (it != src_id_to_def.end()) {
            sp.src_idx = it->second;
        } else {
            SourceDef sd;
            // Build content CDF
            Dictionary cw = e["content_weights"];
            Array cw_keys = cw.keys();
            float cum = 0.0f;
            for (int j = 0; j < cw_keys.size(); j++) {
                int cid = (int)(int64_t)cw_keys[j];
                float w = (float)(double)cw[cw_keys[j]];
                cum += w;
                sd.content_cdf.push_back(cum);
                sd.content_vals.push_back(cid);
            }
            // Build state CDF
            Dictionary sw = e["state_weights"];
            Array sw_keys = sw.keys();
            cum = 0.0f;
            for (int j = 0; j < sw_keys.size(); j++) {
                int sid = (int)(int64_t)sw_keys[j];
                float w = (float)(double)sw[sw_keys[j]];
                cum += w;
                sd.state_cdf.push_back(cum);
                sd.state_vals.push_back(sid);
            }
            sd.enc_max_tier = (int)(int64_t)e.get("enc_max_tier", 0);
            sd.cor_max_tier = (int)(int64_t)e.get("cor_max_tier", 0);

            sp.src_idx = (int)_source_defs.size();
            src_id_to_def[src_id] = sp.src_idx;
            _source_defs.push_back(sd);
        }
        _source_ports.push_back(sp);
    }
}

void SimKernel::configure_buildings(Array building_entries) {
    _bslots.clear();
    _bid_to_slot.clear();

    for (int i = 0; i < building_entries.size(); i++) {
        Dictionary e = building_entries[i];
        BuildingSlot bs;
        bs.bid = (int64_t)e["bid"];
        bs.type = (int)(int64_t)e["type"];
        bs.capacity = (int)(int64_t)e.get("capacity", 0);
        bs.processing_rate = (int)(int64_t)e.get("processing_rate", 1);
        bs.forward_rate = (int)(int64_t)e.get("forward_rate", 0);
        bs.stored_data = e.get("stored_data", Dictionary());
        bs.filter_value = (int)(int64_t)e.get("filter_value", 0);
        bs.separator_mode = (int)(int64_t)e.get("separator_mode", 0);
        bs.selected_tier = (int)(int64_t)e.get("selected_tier", 1);
        // Producer
        bs.prod_input_key = (int)(int64_t)e.get("prod_input_key", 0);
        bs.prod_output_content = (int)(int64_t)e.get("prod_output_content", 0);
        bs.prod_output_state = (int)(int64_t)e.get("prod_output_state", 0);
        bs.prod_consume_amount = (int)(int64_t)e.get("prod_consume_amount", 1);
        bs.prod_t2_extra_content = (int)(int64_t)e.get("prod_t2_extra_content", -1);
        bs.prod_t2_extra_amount = (int)(int64_t)e.get("prod_t2_extra_amount", 0);
        bs.prod_t3_extra_content = (int)(int64_t)e.get("prod_t3_extra_content", -1);
        bs.prod_t3_extra_amount = (int)(int64_t)e.get("prod_t3_extra_amount", 0);
        // DualInput
        bs.dual_fuel_matches = (int)(int64_t)e.get("dual_fuel_matches", 0);
        bs.dual_key_content = (int)(int64_t)e.get("dual_key_content", 6);
        bs.dual_key_cost = (int)(int64_t)e.get("dual_key_cost", 1);
        bs.dual_output_state = (int)(int64_t)e.get("dual_output_state", 0);
        bs.dual_output_tag = (int)(int64_t)e.get("dual_output_tag", 0);
        // Arrays
        if (e.has("dual_primary_states")) {
            PackedInt32Array ps = e["dual_primary_states"];
            for (int j = 0; j < ps.size(); j++) bs.dual_primary_states.push_back(ps[j]);
        }
        if (e.has("dual_tier_key_costs")) {
            PackedInt32Array tc = e["dual_tier_key_costs"];
            for (int j = 0; j < tc.size(); j++) bs.dual_tier_key_costs.push_back(tc[j]);
        }
        if (e.has("dual_required_fuel_tags")) {
            PackedInt32Array ft = e["dual_required_fuel_tags"];
            for (int j = 0; j < ft.size(); j++) bs.dual_required_fuel_tags.push_back(ft[j]);
        }

        _bid_to_slot[bs.bid] = (int)_bslots.size();
        _bslots.push_back(bs);
    }
}

void SimKernel::configure_graph(Dictionary conn_from, Dictionary conn_to,
                                Dictionary output_ports, Array conn_push_meta) {
    _g_conn_from.clear();
    _g_conn_to.clear();
    _g_output_ports_raw = Dictionary();
    _conn_meta.clear();

    // conn_from: bid → Array[int]
    Array cf_keys = conn_from.keys();
    for (int i = 0; i < cf_keys.size(); i++) {
        int64_t bid = (int64_t)cf_keys[i];
        Array indices = conn_from[cf_keys[i]];
        std::vector<int> v;
        for (int j = 0; j < indices.size(); j++) v.push_back((int)(int64_t)indices[j]);
        _g_conn_from[bid] = v;
    }
    // conn_to: bid → Array[int]
    Array ct_keys = conn_to.keys();
    for (int i = 0; i < ct_keys.size(); i++) {
        int64_t bid = (int64_t)ct_keys[i];
        Array indices = conn_to[ct_keys[i]];
        std::vector<int> v;
        for (int j = 0; j < indices.size(); j++) v.push_back((int)(int64_t)indices[j]);
        _g_conn_to[bid] = v;
    }
    // output_ports: kept as raw Dictionary for String key compatibility
    _g_output_ports_raw = output_ports;
    // conn_push_meta: per connection
    _conn_meta.resize(conn_push_meta.size());
    for (int i = 0; i < conn_push_meta.size(); i++) {
        Dictionary m = conn_push_meta[i];
        ConnMeta &cm = _conn_meta[i];
        cm.target_bid = (int64_t)m["target_bid"];
        cm.accepts_mask = (int)(int64_t)m.get("accepts_mask", 0x0FFFFFFF);
        cm.is_ct = (bool)m.get("is_ct", false);
        cm.unlimited_accept = (bool)m.get("unlimited_accept", false);
        cm.capacity = (int)(int64_t)m.get("capacity", 0);
    }
}

// ─── Internal helpers ───

bool SimKernel::_is_stalled(Array &conns, int ci) {
    if (ci < 0 || ci >= conns.size()) return true;
    Dictionary conn = conns[ci];
    if (!conn.has("transit")) return false;
    Array transit = conn["transit"];
    if (transit.size() == 0) return false;
    Dictionary front = transit[0];
    return (double)front["t"] >= 1.0;
}

int SimKernel::_get_total_stored(Dictionary &sd) {
    int total = 0;
    Array vals = sd.values();
    for (int i = 0; i < vals.size(); i++) {
        total += (int)(int64_t)vals[i];
    }
    return total;
}

int SimKernel::_push_to_transit(Array &conns, int64_t from_bid, int packed_key, int amount,
                                const String &from_port, Array &ct_pushes) {
    auto it = _g_conn_from.find(from_bid);
    if (it == _g_conn_from.end()) return 0;

    const std::vector<int> &out_indices = it->second;
    if (out_indices.empty()) return 0;

    int content = is_packet(packed_key) ? -1 : unpack_content(packed_key);
    int state = is_packet(packed_key) ? 0 : unpack_state(packed_key);

    int targets_count = 0;
    // Count valid targets first (for even distribution)
    for (int ci : out_indices) {
        if (!from_port.is_empty()) {
            Dictionary conn = conns[ci];
            String fp = conn["from_port"];
            if (fp != from_port) continue;
        }
        targets_count++;
    }
    if (targets_count == 0) return 0;

    int per_target = amount > targets_count ? amount / targets_count : 1;
    int total_sent = 0;

    for (int ci : out_indices) {
        if (amount <= 0) break;
        Dictionary conn = conns[ci];

        if (!from_port.is_empty()) {
            String fp = conn["from_port"];
            if (fp != from_port) continue;
        }

        int to_send = per_target < amount ? per_target : amount;
        if (to_send <= 0) break;

        // Stall check
        if (_is_stalled(conns, ci)) continue;

        // Connection metadata checks
        if (ci < (int)_conn_meta.size()) {
            const ConnMeta &cm = _conn_meta[ci];

            // CT: defer to GDScript for purity
            if (cm.is_ct) {
                Dictionary push_event;
                push_event["conn_idx"] = ci;
                push_event["packed_key"] = packed_key;
                push_event["amount"] = to_send;
                ct_pushes.push_back(push_event);
                amount -= to_send;
                total_sent += to_send;
                continue;
            }

            // accepts_data check (pre-computed mask)
            if (!cm.unlimited_accept && content >= 0) {
                int bit = content * 4 + state;
                if (bit < 28 && !((cm.accepts_mask >> bit) & 1)) continue;
            }

            // Capacity check for storage buildings
            if (cm.capacity > 0 && !cm.unlimited_accept) {
                auto slot_it = _bid_to_slot.find(cm.target_bid);
                if (slot_it != _bid_to_slot.end()) {
                    Dictionary &sd = _bslots[slot_it->second].stored_data;
                    if (_get_total_stored(sd) >= cm.capacity) continue;
                }
            }
        }

        // Push transit item
        if (!conn.has("transit")) {
            conn["transit"] = Array();
        }
        Array transit = conn["transit"];
        Dictionary new_item;
        new_item["key"] = packed_key;
        new_item["amount"] = to_send;
        new_item["t"] = 0.0;
        transit.push_back(new_item);

        amount -= to_send;
        total_sent += to_send;
    }
    return total_sent;
}

// ─── Tick phases ───

void SimKernel::_do_generation(Array &conns, Array &ct_pushes, Array &discoveries) {
    for (const auto &sp : _source_ports) {
        if (sp.src_idx < 0 || sp.src_idx >= (int)_source_defs.size()) continue;
        const SourceDef &sd = _source_defs[sp.src_idx];

        int64_t src_bid = sp.src_bid;
        const String &from_port = sp.from_port;

        for (int i = 0; i < sp.gen_rate; i++) {
            // Roll content
            int content = 0;
            float r = UtilityFunctions::randf();
            for (int j = 0; j < (int)sd.content_cdf.size(); j++) {
                if (r <= sd.content_cdf[j]) { content = sd.content_vals[j]; break; }
            }
            // Roll state
            int state = 0;
            r = UtilityFunctions::randf();
            for (int j = 0; j < (int)sd.state_cdf.size(); j++) {
                if (r <= sd.state_cdf[j]) { state = sd.state_vals[j]; break; }
            }
            // Roll tier
            int tier = 0;
            if (state == 1 && sd.enc_max_tier > 0) { // ENCRYPTED
                tier = UtilityFunctions::randi_range(1, sd.enc_max_tier > 1 ? sd.enc_max_tier : 1);
            } else if (state == 2 && sd.cor_max_tier > 0) { // CORRUPTED
                tier = UtilityFunctions::randi_range(1, sd.cor_max_tier > 1 ? sd.cor_max_tier : 1);
            } else if (state == 3) { // MALWARE
                tier = 1;
            }

            int packed_key = pack_key(content, state, tier, 0);
            _push_to_transit(conns, src_bid, packed_key, 1, from_port, ct_pushes);

            // Track discoveries
            Dictionary disc;
            disc["content"] = content;
            disc["state"] = state;
            discoveries.push_back(disc);
        }
    }
}

void SimKernel::_do_storage_forward(Array &conns, Array &ct_pushes, Array &working) {
    for (auto &bs : _bslots) {
        if (bs.type != BTYPE_STORAGE) continue;
        if (_get_total_stored(bs.stored_data) <= 0) continue;

        int max_fwd = bs.forward_rate > 0 ? bs.forward_rate : _get_total_stored(bs.stored_data);
        if (max_fwd < 1) max_fwd = 1;
        int sent = 0;

        Array keys = bs.stored_data.keys();
        for (int ki = 0; ki < keys.size(); ki++) {
            if (sent >= max_fwd) break;
            int key = (int)(int64_t)keys[ki];
            int avail = (int)(int64_t)bs.stored_data[keys[ki]];
            if (avail <= 0) continue;
            if (is_packet(key)) continue;

            int to_fwd = avail < (max_fwd - sent) ? avail : (max_fwd - sent);
            int pushed = _push_to_transit(conns, bs.bid, key, to_fwd, String(), ct_pushes);
            if (pushed > 0) {
                bs.stored_data[keys[ki]] = avail - pushed;
                sent += pushed;
            }
        }
        if (sent > 0) working.push_back(bs.bid);
    }
}

void SimKernel::_do_processing(Array &conns, Dictionary &splitter_next,
                               Array &ct_pushes, Array &working, Array &sounds) {
    for (auto &bs : _bslots) {
        if (_get_total_stored(bs.stored_data) <= 0) continue;

        int processed = 0;
        int max_proc = bs.processing_rate;

        switch (bs.type) {
            case BTYPE_TRASH: {
                processed = _get_total_stored(bs.stored_data);
                if (processed > 0) bs.stored_data.clear();
                break;
            }
            default:
                // Other types: stay in GDScript for now
                break;
        }

        if (processed > 0) {
            working.push_back(bs.bid);
        }

        // Clean up zero entries
        Array keys = bs.stored_data.keys();
        for (int ki = 0; ki < keys.size(); ki++) {
            if ((int)(int64_t)bs.stored_data[keys[ki]] <= 0) {
                bs.stored_data.erase(keys[ki]);
            }
        }
    }
}

void SimKernel::_do_inline_rendezvous(Array &conns, Array &ct_pushes,
                                      Array &working, Array &sounds) {
    // Inline rendezvous for dual-input buildings (Decryptor/Encryptor/Recoverer)
    // These have no storage — primary and secondary items meet on cable ends
    std::unordered_map<int64_t, bool> checked;

    for (auto &bs : _bslots) {
        if (bs.type != BTYPE_INLINE) continue;
        if (checked.count(bs.bid)) continue;
        checked[bs.bid] = true;

        auto in_it = _g_conn_to.find(bs.bid);
        if (in_it == _g_conn_to.end()) continue;
        const std::vector<int> &in_indices = in_it->second;

        for (int attempt = 0; attempt < bs.processing_rate; attempt++) {
            // Find primary and secondary arrived items
            int pri_ci = -1, sec_ci = -1;

            for (int ci : in_indices) {
                if (ci < 0 || ci >= conns.size()) continue;
                Dictionary conn = conns[ci];
                if (!conn.has("transit")) continue;
                Array transit = conn["transit"];
                if (transit.size() == 0) continue;
                Dictionary item = transit[0];
                if ((double)item["t"] < 1.0) continue;

                int ikey = (int)(int64_t)item["key"];
                if (is_packet(ikey)) continue;

                bool is_primary;
                if (bs.dual_fuel_matches) {
                    // Recoverer: fuel = Public state, tier 0
                    bool is_fuel = (unpack_state(ikey) == 0 && unpack_tier(ikey) == 0);
                    is_primary = !is_fuel;
                } else {
                    // Decryptor/Encryptor: fuel = Key content
                    is_primary = (unpack_content(ikey) != bs.dual_key_content);
                }

                // Check primary_input_states
                if (is_primary && !bs.dual_primary_states.empty()) {
                    int s = unpack_state(ikey);
                    bool found = false;
                    for (int ps : bs.dual_primary_states) { if (ps == s) { found = true; break; } }
                    if (!found) continue;
                }

                if (is_primary && pri_ci < 0) pri_ci = ci;
                else if (!is_primary && sec_ci < 0) sec_ci = ci;
            }

            if (pri_ci < 0 || sec_ci < 0) break;

            // Get items
            Array pri_transit = ((Dictionary)conns[pri_ci])["transit"];
            Array sec_transit = ((Dictionary)conns[sec_ci])["transit"];
            Dictionary p_item = pri_transit[0];
            Dictionary s_item = sec_transit[0];
            int pkey = (int)(int64_t)p_item["key"];
            int skey = (int)(int64_t)s_item["key"];

            // Verify secondary matches primary
            bool matches = false;
            if (bs.dual_fuel_matches) {
                // Recoverer: fuel content must match primary content + required tags
                if (unpack_content(skey) != unpack_content(pkey)) break;
                int required_tags = 0;
                int tier = unpack_tier(pkey);
                if (tier > 0 && tier <= (int)bs.dual_required_fuel_tags.size())
                    required_tags = bs.dual_required_fuel_tags[tier - 1];
                matches = (unpack_tags(skey) == required_tags);
            } else {
                // Decryptor/Encryptor: key tier must match data tier (min T1)
                int key_tier = unpack_tier(pkey);
                if (key_tier < 1) key_tier = 1;
                matches = (unpack_tier(skey) == key_tier);
            }
            if (!matches) break;

            // Key/fuel cost
            int tier = unpack_tier(pkey);
            int key_cost = bs.dual_key_cost;
            if (tier > 0 && tier <= (int)bs.dual_tier_key_costs.size())
                key_cost = bs.dual_tier_key_costs[tier - 1];
            if ((int)(int64_t)s_item["amount"] < key_cost) break;

            // Push output
            int out_tags = unpack_tags(pkey) | bs.dual_output_tag;
            int out_key = pack_key(unpack_content(pkey), bs.dual_output_state, tier, out_tags);
            int sent = _push_to_transit(conns, bs.bid, out_key, 1, String(), ct_pushes);
            if (sent <= 0) break;

            // Consume primary
            int p_amt = (int)(int64_t)p_item["amount"] - 1;
            if (p_amt <= 0) pri_transit.remove_at(0);
            else p_item["amount"] = p_amt;

            // Consume secondary
            int s_amt = (int)(int64_t)s_item["amount"] - key_cost;
            if (s_amt <= 0) sec_transit.remove_at(0);
            else s_item["amount"] = s_amt;

            working.push_back(bs.bid);
            sounds.push_back(String("process")); // generic sound
        }
    }
}

// ─── Stall tracking ───

Dictionary SimKernel::update_stalls(Array conns, PackedInt32Array building_active, int max_passes) {
    Dictionary stalled;
    int conn_count = conns.size();

    // Build bid→active lookup from building_active array (indexed by _bslots order)
    std::unordered_map<int64_t, bool> bid_active;
    const int32_t *active_ptr = building_active.ptr();
    for (int i = 0; i < (int)_bslots.size() && i < building_active.size(); i++) {
        bid_active[_bslots[i].bid] = (active_ptr[i] != 0);
    }

    // Pass 1: Direct stalls — transit front stuck OR target full OR source inactive
    for (int ci = 0; ci < conn_count; ci++) {
        Dictionary conn = conns[ci];

        // Check source active
        if (conn.has("from_building")) {
            Object *from_obj = (Object *)(conn["from_building"]);
            if (from_obj) {
                int64_t from_bid = from_obj->get_instance_id();
                auto ait = bid_active.find(from_bid);
                if (ait != bid_active.end() && !ait->second) {
                    continue; // Source inactive — skip (not stalled, just idle)
                }
            }
        }

        // Transit stall: front item at t >= 1.0
        if (conn.has("transit")) {
            Array transit = conn["transit"];
            if (transit.size() > 0) {
                Dictionary front = transit[0];
                if ((double)front["t"] >= 1.0) {
                    stalled[ci] = true;
                    continue;
                }
            }
        }

        // Target capacity check
        if (ci < (int)_conn_meta.size()) {
            const ConnMeta &cm = _conn_meta[ci];
            if (!cm.unlimited_accept && cm.capacity > 0) {
                auto slot_it = _bid_to_slot.find(cm.target_bid);
                if (slot_it != _bid_to_slot.end()) {
                    Dictionary &sd = _bslots[slot_it->second].stored_data;
                    if (_get_total_stored(sd) >= cm.capacity) {
                        stalled[ci] = true;
                        continue;
                    }
                }
            }
        }
    }

    // Pass 2-4: Back-pressure propagation
    for (int pass = 0; pass < max_passes; pass++) {
        Dictionary newly_stalled;
        for (auto &kv : _g_conn_from) {
            int64_t bid = kv.first;
            const std::vector<int> &out_indices = kv.second;

            // Check if ALL output connections are stalled
            bool all_blocked = true;
            for (int oi : out_indices) {
                if (!stalled.has(oi) && !newly_stalled.has(oi)) {
                    all_blocked = false;
                    break;
                }
            }
            if (!all_blocked) continue;

            // Mark ALL input connections as stalled
            auto in_it = _g_conn_to.find(bid);
            if (in_it == _g_conn_to.end()) continue;
            for (int ii : in_it->second) {
                if (!stalled.has(ii)) {
                    newly_stalled[ii] = true;
                }
            }
        }
        if (newly_stalled.is_empty()) break;
        Array nk = newly_stalled.keys();
        for (int i = 0; i < nk.size(); i++) {
            stalled[nk[i]] = true;
        }
    }

    return stalled;
}

// ─── Main tick ───

Dictionary SimKernel::run_tick(Array conns, Dictionary splitter_next, Dictionary blocked_ports) {
    Array working;
    Array ct_pushes;
    Array discoveries;
    Array sounds;

    // Phase 1: Source generation
    _do_generation(conns, ct_pushes, discoveries);

    // Phase 2: Storage forward
    _do_storage_forward(conns, ct_pushes, working);

    // Phase 3: Processing (trash only for now, rest in GDScript)
    _do_processing(conns, splitter_next, ct_pushes, working, sounds);

    // Phase 4: Inline rendezvous
    _do_inline_rendezvous(conns, ct_pushes, working, sounds);

    Dictionary result;
    result["working"] = working;
    result["ct_pushes"] = ct_pushes;
    result["discoveries"] = discoveries;
    result["sounds"] = sounds;
    return result;
}
