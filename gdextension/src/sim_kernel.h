#ifndef SIM_KERNEL_H
#define SIM_KERNEL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <vector>
#include <unordered_map>
#include "packed_key.h"

namespace godot {

class SimKernel : public RefCounted {
    GDCLASS(SimKernel, RefCounted);

protected:
    static void _bind_methods();

public:
    // Building processing types
    static constexpr int BTYPE_NONE       = 0;
    static constexpr int BTYPE_CLASSIFIER = 1;
    static constexpr int BTYPE_SEPARATOR  = 2;
    static constexpr int BTYPE_SPLITTER   = 3;
    static constexpr int BTYPE_MERGER     = 4;
    static constexpr int BTYPE_TRASH      = 5;
    static constexpr int BTYPE_PRODUCER   = 6;
    // BTYPE 7-8 reserved (Compiler removed in v4)
    static constexpr int BTYPE_STORAGE    = 9;
    static constexpr int BTYPE_DUAL_INPUT = 10; // storage-based dual-input
    static constexpr int BTYPE_INLINE     = 11; // cable rendezvous (storageless)

    SimKernel();
    ~SimKernel();

    // --- Configuration (called on topology change) ---
    void configure_sources(Array source_port_entries);
    void configure_buildings(Array building_entries);
    void configure_graph(Dictionary conn_from, Dictionary conn_to,
                         Dictionary output_ports, Array conn_push_meta);

    // --- Tick execution ---
    Dictionary run_tick(Array conns, Dictionary splitter_next, Dictionary blocked_ports);

    // --- Stall tracking (Pass 1-4 combined) ---
    /// Full stall tracking: transit stall + capacity check + back-pressure propagation.
    /// building_active: PackedInt32Array indexed by _bslots order (1=active, 0=inactive)
    /// Returns: Dictionary {conn_idx → true} for stalled connections.
    Dictionary update_stalls(Array conns, PackedInt32Array building_active, int max_passes);

private:
    // --- Internal data structures ---
    struct SourcePort {
        int conn_idx;
        int gen_rate;
        int src_idx;
        int64_t src_bid; // source building instance_id
        String from_port;
    };
    struct SourceDef {
        std::vector<float> content_cdf;
        std::vector<int> content_vals;
        std::vector<float> state_cdf;
        std::vector<int> state_vals;
        int enc_tier;
        int cor_tier;
    };
    struct BuildingSlot {
        int64_t bid;
        int type;
        int capacity;
        int processing_rate;
        int forward_rate;
        Dictionary stored_data; // reference to building.stored_data
        int filter_value;
        int separator_mode; // 0=state, 1=content
        int selected_tier;
        // Producer
        int prod_input_key, prod_output_content, prod_output_state, prod_consume_amount;
        int prod_t2_extra_content, prod_t2_extra_amount;
        int prod_t3_extra_content, prod_t3_extra_amount;
        // DualInput
        int dual_fuel_matches, dual_key_content, dual_key_cost;
        int dual_output_state, dual_output_tag;
        std::vector<int> dual_primary_states;
        std::vector<int> dual_tier_key_costs;
        std::vector<int> dual_required_fuel_tags;
    };
    struct ConnMeta {
        int64_t target_bid;
        int accepts_mask; // bit(content*4+state) set if target accepts
        bool is_ct;
        bool unlimited_accept; // routing/trash = always accept
        int capacity; // 0 = unlimited
    };

    std::vector<SourcePort> _source_ports;
    std::vector<SourceDef> _source_defs;
    std::vector<BuildingSlot> _bslots;
    std::unordered_map<int64_t, int> _bid_to_slot;
    std::vector<ConnMeta> _conn_meta;

    // Graph (copies from GDScript)
    std::unordered_map<int64_t, std::vector<int>> _g_conn_from;
    std::unordered_map<int64_t, std::vector<int>> _g_conn_to;
    Dictionary _g_output_ports_raw; // bid → {port_name → conn_idx} — kept as Godot Dictionary for String key compat

    // --- Internal helpers (packed key ops in packed_key.h) ---
    bool _is_stalled(Array &conns, int ci);
    int _push_to_transit(Array &conns, int64_t from_bid, int packed_key, int amount,
                         const String &from_port, Array &ct_pushes);
    int _get_total_stored(Dictionary &sd);

    // Phase implementations
    void _do_generation(Array &conns, Array &ct_pushes, Array &discoveries);
    void _do_storage_forward(Array &conns, Array &ct_pushes, Array &working);
    void _do_processing(Array &conns, Dictionary &splitter_next,
                        Array &ct_pushes, Array &working, Array &sounds);
    void _do_inline_rendezvous(Array &conns, Array &ct_pushes, Array &working, Array &sounds);
};

} // namespace godot

#endif // SIM_KERNEL_H
