#ifndef STALL_PROPAGATOR_H
#define STALL_PROPAGATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class StallPropagator : public RefCounted {
    GDCLASS(StallPropagator, RefCounted);

protected:
    static void _bind_methods();

public:
    StallPropagator();
    ~StallPropagator();

    /// Propagate stalls backward through the connection graph.
    /// direct_stalls: Dictionary {conn_index: true} — initial stalled connections
    /// conn_from: Dictionary {building_id: Array[int]} — output connection indices per building
    /// conn_to: Dictionary {building_id: Array[int]} — input connection indices per building
    /// max_passes: number of propagation passes (typically 3)
    /// Returns: Dictionary {conn_index: true} — all stalled connections after propagation
    Dictionary propagate_stalls(Dictionary direct_stalls, Dictionary conn_from, Dictionary conn_to, int max_passes);
};

} // namespace godot

#endif // STALL_PROPAGATOR_H
