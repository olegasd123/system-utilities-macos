#ifndef MAC_SENSOR_BRIDGE_H
#define MAC_SENSOR_BRIDGE_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MacSensorContext MacSensorContext;

typedef struct {
    char *label;
    double value;
} MacSensorReading;

MacSensorContext *MacSensorContextCreate(void);
void MacSensorContextDestroy(MacSensorContext *context);

size_t MacSensorCopyHidTemperatures(MacSensorContext *context, MacSensorReading **readings);
size_t MacSensorCopySmcTemperatures(MacSensorContext *context, MacSensorReading **readings);
size_t MacSensorCopyFans(MacSensorContext *context, MacSensorReading **readings);
void MacSensorReadingsFree(MacSensorReading *readings, size_t count);

#ifdef __cplusplus
}
#endif

#endif
