#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "transit_simulator.h"
#include "polyline_helper.h"
#include "stall_propagator.h"
#include "delivery_engine.h"

using namespace godot;

void initialize_sysadmin_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    ClassDB::register_class<TransitSimulator>();
    ClassDB::register_class<PolylineHelper>();
    ClassDB::register_class<StallPropagator>();
    ClassDB::register_class<DeliveryEngine>();
}

void uninitialize_sysadmin_module(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {
GDExtensionBool GDE_EXPORT sysadmin_library_init(
    GDExtensionInterfaceGetProcAddress p_get_proc_address,
    const GDExtensionClassLibraryPtr p_library,
    GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_sysadmin_module);
    init_obj.register_terminator(uninitialize_sysadmin_module);
    init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}
}
