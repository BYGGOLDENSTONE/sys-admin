#ifndef DELIVERY_ENGINE_H
#define DELIVERY_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

namespace godot {

class DeliveryEngine : public RefCounted {
    GDCLASS(DeliveryEngine, RefCounted);

protected:
    static void _bind_methods();

public:
    // Building type constants (must match GDScript)
    static constexpr int TYPE_REGULAR = 0;
    static constexpr int TYPE_CLASSIFIER = 1;
    static constexpr int TYPE_SEPARATOR_STATE = 2;
    static constexpr int TYPE_SEPARATOR_CONTENT = 3;
    static constexpr int TYPE_SPLITTER = 4;
    static constexpr int TYPE_MERGER = 5;
    static constexpr int TYPE_TRASH = 6;
    static constexpr int TYPE_INLINE = 7;
    static constexpr int TYPE_SCANNER = 8;

    DeliveryEngine();
    ~DeliveryEngine();

    /// Process delivery for all connections. Handles routing passthrough and trash in C++.
    /// conn_target_types: PackedInt32Array — building type per connection index
    /// conn_target_filters: PackedInt32Array — filter value per connection index
    /// conn_target_bids: Array[int64] — target building instance_id per connection index
    /// target_ports: Dictionary { bid → Array[String] } — output port names per building
    /// output_ports: Dictionary { bid → { port_name → conn_index } }
    /// splitter_next: Dictionary { bid → int } — next port index for splitters (modified in place)
    /// Returns: Dictionary { "remaining": Array[int], "working": Array[int64] }
    Dictionary deliver_arrived(
        Array conns,
        PackedInt32Array conn_target_types,
        PackedInt32Array conn_target_filters,
        Array conn_target_bids,
        Dictionary target_ports,
        Dictionary output_ports,
        Dictionary splitter_next
    );

private:
    bool _try_routing(
        Array &conns,
        Dictionary &item,
        int64_t bid,
        int type,
        int filter,
        Dictionary &target_ports,
        Dictionary &output_ports,
        Dictionary &splitter_next
    );
};

} // namespace godot

#endif // DELIVERY_ENGINE_H
