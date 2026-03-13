#include "polyline_helper.h"
#include <godot_cpp/core/class_db.hpp>
#include <cmath>

using namespace godot;

void PolylineHelper::_bind_methods() {
    ClassDB::bind_method(D_METHOD("build_cumulative_distances", "seg_lengths"), &PolylineHelper::build_cumulative_distances);
    ClassDB::bind_method(D_METHOD("point_along_path", "points", "cumulative", "total", "t"), &PolylineHelper::point_along_path);
    ClassDB::bind_method(D_METHOD("batch_transit_positions", "points", "cumulative", "total", "transit", "min_render_t"), &PolylineHelper::batch_transit_positions);
}

PolylineHelper::PolylineHelper() {}
PolylineHelper::~PolylineHelper() {}

PackedFloat64Array PolylineHelper::build_cumulative_distances(Array seg_lengths) {
    PackedFloat64Array result;
    int count = seg_lengths.size();
    result.resize(count);
    double accum = 0.0;
    for (int i = 0; i < count; i++) {
        accum += (double)seg_lengths[i];
        result[i] = accum;
    }
    return result;
}

Vector2 PolylineHelper::point_along_path(PackedVector2Array points, PackedFloat64Array cumulative, double total, double t) {
    if (points.size() < 2 || cumulative.size() == 0 || total <= 0.0) {
        return points.size() > 0 ? points[0] : Vector2(0, 0);
    }

    double target_dist = t * total;
    if (target_dist <= 0.0) return points[0];
    if (target_dist >= total) return points[points.size() - 1];

    // Binary search: find first cumulative[i] >= target_dist
    int lo = 0;
    int hi = cumulative.size() - 1;
    while (lo < hi) {
        int mid = (lo + hi) >> 1;
        if (cumulative[mid] < target_dist) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    // lo is the segment index where the target falls
    int seg = lo;
    double seg_start = (seg > 0) ? cumulative[seg - 1] : 0.0;
    double seg_end = cumulative[seg];
    double seg_len = seg_end - seg_start;
    double local_t = (seg_len > 0.0) ? (target_dist - seg_start) / seg_len : 0.0;

    return points[seg].lerp(points[seg + 1], (float)local_t);
}

PackedVector2Array PolylineHelper::batch_transit_positions(PackedVector2Array points, PackedFloat64Array cumulative, double total, Array transit, double min_render_t) {
    int item_count = transit.size();
    PackedVector2Array result;
    result.resize(item_count);

    for (int i = 0; i < item_count; i++) {
        Dictionary item = transit[i];
        double item_t = (double)item["t"];
        if (item_t < min_render_t) {
            result[i] = Vector2(NAN, NAN); // sentinel: don't render
        } else {
            result[i] = point_along_path(points, cumulative, total, item_t);
        }
    }
    return result;
}
