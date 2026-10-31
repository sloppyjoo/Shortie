// Lets Swift use a few C definitions that Apple doesn't ship in the SDK.
//
// MultitouchSupport is the private Apple framework that reports where each
// finger is on a trackpad. It isn't documented, so these definitions come from
// the open-source projects that use it (MiddleClick, OpenMultitouchSupport).
// We load it at runtime rather than linking it, so if Apple ever removes it,
// Shortie keeps working and gestures simply switch off.

#include <CoreFoundation/CoreFoundation.h>

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

/// One finger touching the trackpad, as reported in a single frame.
typedef struct {
    int frame;
    double timestamp;
    /// Stays the same for a finger from the moment it lands until it lifts.
    int identifier;
    /// 1 starting, 2 hovering, 3 landing, 4 touching, 5 lifting, 6 lingering, 7 gone.
    int state;
    int fingerID;
    int handID;
    /// Position from 0 to 1 across the trackpad, measured from the bottom-left.
    MTVector normalized;
    /// How much of the finger is in contact.
    float size;
    int unknown1;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absolute;
    int unknown2;
    int unknown3;
    float density;
} MTTouch;

typedef void *MTDeviceRef;

typedef int (*MTContactCallbackFunction)(MTDeviceRef device, const MTTouch *touches, int count, double timestamp, int frame);
typedef CFArrayRef (*MTDeviceCreateListFunction)(void);
typedef void (*MTRegisterContactFrameCallbackFunction)(MTDeviceRef device, MTContactCallbackFunction callback);
typedef void (*MTDeviceStartFunction)(MTDeviceRef device, int mode);
typedef void (*MTDeviceStopFunction)(MTDeviceRef device);
typedef void (*MTUnregisterContactFrameCallbackFunction)(MTDeviceRef device, MTContactCallbackFunction callback);
/// Width and height of the touch surface, in hundredths of a millimetre.
typedef int (*MTDeviceGetSensorSurfaceDimensionsFunction)(MTDeviceRef device, int *width, int *height);
