#include <exception>
#include <stdbool.h>
#include <stdint.h>
#include <string>

#include <lean/lean.h>

#include "runtime/thread.h"

#include "LeanIOSBridge.h"

extern "C" {
lean_object *initialize_lean__ios__runner_Runner(uint8_t builtin);
void lean_initialize();
void lean_init_task_manager();
void lean_enable_initializer_execution();
void lean_io_mark_end_initialization();
lean_object *checkLeanSource(b_lean_obj_arg bundleRoot, b_lean_obj_arg source);
static std::string g_bridge_output;

static bool ensure_lean_initialized() {
  static bool runtime_initialized = false;
  static bool module_initialized = false;
  static bool task_manager_initialized = false;

  if (!runtime_initialized) {
    lean_initialize();
    runtime_initialized = true;
  }

  if (!task_manager_initialized) {
    lean_init_task_manager();
    task_manager_initialized = true;
  }

  // The frontend import path uses `loadExts := true`, which requires initializer execution.
  lean_enable_initializer_execution();

  lean::initialize_thread();

  if (!module_initialized) {
    lean_object *init = initialize_lean__ios__runner_Runner(1);
    if (lean_io_result_is_error(init)) {
      lean_dec_ref(init);
      return false;
    }
    lean_dec_ref(init);
    lean_io_mark_end_initialization();
    module_initialized = true;
  }

  return true;
}

static void run_check_lean_source(const char *bundle_root, const char *source,
                                  std::string &out) {
  try {
    lean_object *bundle_root_obj = lean_mk_string(bundle_root);
    lean_object *source_obj = lean_mk_string(source);
    lean_object *result = checkLeanSource(bundle_root_obj, source_obj);
    if (lean_io_result_is_error(result)) {
      out = "Lean IO call returned an error.";
    } else {
      const char *text = lean_string_cstr(lean_io_result_get_value(result));
      out = text == nullptr ? "(null)" : text;
    }
    lean_dec_ref(result);
  } catch (const std::exception &ex) {
    out = "Native exception: ";
    const char *text = ex.what();
    out += text == nullptr ? "(null)" : text;
  } catch (...) {
    out = "Native exception: unknown C++ exception";
  }
}

const char *lean_ios_check_source(const char *bundle_root, const char *source) {
  if (!ensure_lean_initialized()) {
    g_bridge_output = "Failed to initialize Lean.";
    return g_bridge_output.c_str();
  }

  g_bridge_output.clear();
  run_check_lean_source(bundle_root, source, g_bridge_output);
  return g_bridge_output.c_str();
}
}
