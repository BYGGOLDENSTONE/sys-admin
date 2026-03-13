#ifndef POLYLINE_HELPER_H
#define POLYLINE_HELPER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

class PolylineHelper : public RefCounted {
    GDCLASS(PolylineHelper, RefCounted);

protected:
    static void _bind_methods();

public:
    PolylineHelper();
    ~PolylineHelper();

    /// Build cumulative distance array from segment lengths.
    /// Returns PackedFloat64Array where [i] = sum of seg_lengths[0..i].
    PackedFloat64Array build_cumulative_distances(Array seg_lengths);

    /// Find position along polyline at normalized t [0..1].
    /// Uses binary search on cumulative distances for O(log n).
    Vector2 point_along_path(PackedVector2Array points, PackedFloat64Array cumulative, double total, double t);

    /// Batch compute all transit item positions in one C++ call.
    /// Returns PackedVector2Array of positions (one per visible transit item).
    /// Items with t < min_render_t get Vector2(NAN, NAN) as sentinel.
    PackedVector2Array batch_transit_positions(PackedVector2Array points, PackedFloat64Array cumulative, double total, Array transit, double min_render_t);
};

} // namespace godot

#endif // POLYLINE_HELPER_H
