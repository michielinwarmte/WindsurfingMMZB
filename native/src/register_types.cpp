// The game's native library (the test of 13 November 2026): tells Godot about its classes.

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "native_lake_waves.h"

using namespace godot;

static void initialize_windsurf_native(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(NativeLakeWaves);
}

static void uninitialize_windsurf_native(ModuleInitializationLevel level) {
}

extern "C" {

// The entry point named in Game/native/windsurf_native.gdextension.
GDExtensionBool GDE_EXPORT windsurf_native_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		const GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
	init.register_initializer(initialize_windsurf_native);
	init.register_terminator(uninitialize_windsurf_native);
	init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init.init();
}

} // extern "C"
