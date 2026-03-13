#ifndef TRANSIT_SIMULATOR_H
#define TRANSIT_SIMULATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

namespace godot {

class TransitSimulator : public RefCounted {
    GDCLASS(TransitSimulator, RefCounted);

protected:
    static void _bind_methods();

public:
    static constexpr double TRANSIT_GRIDS_PER_SEC = 3.0;
    static constexpr double TRANSIT_MIN_SPACING_GRIDS = 1.5;

    TransitSimulator();
    ~TransitSimulator();

    /// Advance all in-flight transit items for smooth visual movement.
    /// conns: Array[Dictionary] — each conn may have "transit" Array of {t, ...} items.
    void advance_transit(Array conns, double delta, int speed_multiplier);

    /// Get cable length in grid cells from cached polyline data.
    double get_cable_length_grids(Dictionary conn, int tile_size);
};

} // namespace godot

#endif // TRANSIT_SIMULATOR_H
