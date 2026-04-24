#include <stdbool.h>
#include <stdint.h>

#include <lean/lean.h>

#include "runtime/alloc.h"
#include "runtime/object.h"
#include "runtime/thread.h"

#include "LeanIOSBridge.h"

extern "C" {
    lean_object * initialize_example__app_Example(uint8_t builtin);
    uint32_t addOne(uint32_t n);

    uint32_t lean_ios_add_one(uint32_t n) {
        static bool runtime_initialized = false;
        static bool module_initialized = false;

        if (!runtime_initialized) {
            lean::initialize_alloc();
            lean::initialize_object();
            runtime_initialized = true;
        }

        lean::initialize_thread();

        if (!module_initialized) {
            lean_object * init = initialize_example__app_Example(1);
            if (lean_io_result_is_error(init)) {
                lean_dec_ref(init);
                return 0;
            }
            lean_dec_ref(init);
            module_initialized = true;
        }

        return addOne(n);
    }
}
