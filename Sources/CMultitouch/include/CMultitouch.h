// Declarations for Apple's private MultitouchSupport.framework (reverse-engineered, stable for years).
// Swift imports C headers directly, so this is all the "binding" we need — no JNI-style glue.
#pragma once
#include <CoreFoundation/CoreFoundation.h>

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state; // 4 = touching (0 notTouching, 1 starting, 2 hovering, 3 making, 5 breaking, ...)
    int32_t fingerID;
    int32_t handID;
    MTVector normalized; // 0...1, origin bottom-left of the trackpad
    float size;
    int32_t unknown1;
    float angle, majorAxis, minorAxis;
    MTVector absolute; // millimetres
    int32_t unknown2, unknown3;
    float density;
} MTTouch;

// Fails the build (not the user's Mac at runtime) if the layout assumption ever breaks.
_Static_assert(sizeof(MTTouch) == 96, "MTTouch layout changed");

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef device, const MTTouch *touches, int32_t count,
                                 double timestamp, int32_t frame);

CFArrayRef MTDeviceCreateList(void) CF_RETURNS_RETAINED; // every trackpad: built-in + Magic Trackpad
void MTRegisterContactFrameCallback(MTDeviceRef device, MTContactCallback callback);
void MTUnregisterContactFrameCallback(MTDeviceRef device, MTContactCallback callback);
int32_t MTDeviceStart(MTDeviceRef device, int32_t mode);
int32_t MTDeviceStop(MTDeviceRef device);
