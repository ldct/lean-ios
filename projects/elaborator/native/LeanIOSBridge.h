#ifndef LEAN_IOS_BRIDGE_H
#define LEAN_IOS_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

const char *lean_ios_check_source(const char *bundle_root, const char *source);

#ifdef __cplusplus
}
#endif

#endif
