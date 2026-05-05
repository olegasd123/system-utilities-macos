#include "MacSensorBridge.h"

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>
#include <mach/mach.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    kHidEventTypeTemperature = 15,
    kHidPageAppleVendor = 0xff00,
    kHidUsageAppleVendorTemperature = 0x0005,
    kHidEventFieldTemperatureLevel = kHidEventTypeTemperature << 16,
    kSmcSelector = 2,
    kSmcCommandReadBytes = 5,
    kSmcCommandReadKeyInfo = 9,
};

extern CFTypeRef IOHIDServiceClientCopyEvent(
    IOHIDServiceClientRef service,
    int64_t eventType,
    int32_t options,
    int64_t timestamp
);
extern double IOHIDEventGetFloatValue(CFTypeRef event, int32_t field);

typedef struct {
    uint8_t major;
    uint8_t minor;
    uint8_t build;
    uint8_t reserved;
    uint16_t release;
} SmcVersion;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SmcPLimitData;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
} SmcKeyInfoData;

typedef struct {
    uint32_t key;
    SmcVersion vers;
    SmcPLimitData pLimitData;
    SmcKeyInfoData keyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
} SmcParamStruct;

typedef struct {
    uint32_t dataType;
    uint8_t bytes[32];
    size_t size;
} SmcValue;

struct MacSensorContext {
    IOHIDEventSystemClientRef hidClient;
    CFArrayRef hidServices;
    io_connect_t smcConnection;
};

typedef struct {
    const char *key;
    const char *label;
} SmcTemperatureKey;

static const SmcTemperatureKey kTemperatureKeys[] = {
    {"TC0P", "CPU Proximity"},
    {"TC0D", "CPU Die"},
    {"TC0E", "CPU PECI"},
    {"TC0F", "CPU Core"},
    {"TC0H", "CPU Heatsink"},
    {"TG0P", "GPU Proximity"},
    {"TG0D", "GPU Die"},
};

static char *copyCString(const char *string);
static void appendReading(MacSensorReading **readings, size_t *count, const char *label, double value);
static char *copyHidProductName(IOHIDServiceClientRef service, size_t index);
static io_connect_t openSmcConnection(void);
static int smcReadKey(io_connect_t connection, const char *key, SmcValue *value);
static int smcCall(io_connect_t connection, const SmcParamStruct *input, SmcParamStruct *output);
static uint32_t smcKeyCode(const char *key);
static void smcDataTypeString(uint32_t dataType, char out[5]);
static int parseTemperature(const SmcValue *value, double *temperature);
static int parseFanRpm(const SmcValue *value, double *rpm);
static int parseInteger(const SmcValue *value, uint32_t *integer);
static int parseFloat(const uint8_t bytes[32], double *value);
static char *parseAscii(const SmcValue *value);

MacSensorContext *MacSensorContextCreate(void) {
    MacSensorContext *context = calloc(1, sizeof(MacSensorContext));
    if (context == NULL) {
        return NULL;
    }

    context->hidClient = IOHIDEventSystemClientCreateSimpleClient(NULL);
    if (context->hidClient != NULL) {
        context->hidServices = IOHIDEventSystemClientCopyServices(context->hidClient);
    }

    context->smcConnection = openSmcConnection();
    return context;
}

void MacSensorContextDestroy(MacSensorContext *context) {
    if (context == NULL) {
        return;
    }
    if (context->hidServices != NULL) {
        CFRelease(context->hidServices);
    }
    if (context->hidClient != NULL) {
        CFRelease(context->hidClient);
    }
    if (context->smcConnection != 0) {
        IOServiceClose(context->smcConnection);
    }
    free(context);
}

size_t MacSensorCopyHidTemperatures(MacSensorContext *context, MacSensorReading **readings) {
    if (readings == NULL) {
        return 0;
    }
    *readings = NULL;
    if (context == NULL || context->hidServices == NULL) {
        return 0;
    }

    size_t count = 0;
    CFIndex serviceCount = CFArrayGetCount(context->hidServices);
    for (CFIndex index = 0; index < serviceCount; index++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(context->hidServices, index);
        if (service == NULL) {
            continue;
        }
        if (!IOHIDServiceClientConformsTo(
                service,
                kHidPageAppleVendor,
                kHidUsageAppleVendorTemperature
            )) {
            continue;
        }

        CFTypeRef event = IOHIDServiceClientCopyEvent(
            service,
            kHidEventTypeTemperature,
            0,
            0
        );
        if (event == NULL) {
            continue;
        }

        double value = IOHIDEventGetFloatValue(event, kHidEventFieldTemperatureLevel);
        CFRelease(event);
        if (!isfinite(value)) {
            continue;
        }

        char *label = copyHidProductName(service, (size_t)index);
        appendReading(readings, &count, label, value);
        free(label);
    }

    return count;
}

size_t MacSensorCopySmcTemperatures(MacSensorContext *context, MacSensorReading **readings) {
    if (readings == NULL) {
        return 0;
    }
    *readings = NULL;
    if (context == NULL || context->smcConnection == 0) {
        return 0;
    }

    size_t count = 0;
    for (size_t index = 0; index < sizeof(kTemperatureKeys) / sizeof(kTemperatureKeys[0]); index++) {
        SmcValue value;
        double temperature = 0;
        if (smcReadKey(context->smcConnection, kTemperatureKeys[index].key, &value) == 0 &&
            parseTemperature(&value, &temperature)) {
            appendReading(readings, &count, kTemperatureKeys[index].label, temperature);
        }
    }
    return count;
}

size_t MacSensorCopyFans(MacSensorContext *context, MacSensorReading **readings) {
    if (readings == NULL) {
        return 0;
    }
    *readings = NULL;
    if (context == NULL || context->smcConnection == 0) {
        return 0;
    }

    uint32_t fanCount = 0;
    SmcValue countValue;
    if (smcReadKey(context->smcConnection, "FNum", &countValue) == 0) {
        parseInteger(&countValue, &fanCount);
    }
    if (fanCount == 0 || fanCount > 16) {
        fanCount = 8;
    }

    size_t count = 0;
    for (uint32_t index = 0; index < fanCount; index++) {
        char key[5] = {0};
        snprintf(key, sizeof(key), "F%uAc", index);

        SmcValue value;
        double rpm = 0;
        if (smcReadKey(context->smcConnection, key, &value) != 0 ||
            !parseFanRpm(&value, &rpm)) {
            continue;
        }

        char labelKey[5] = {0};
        snprintf(labelKey, sizeof(labelKey), "F%uID", index);
        char fallbackLabel[16] = {0};
        snprintf(fallbackLabel, sizeof(fallbackLabel), "Fan %u", index + 1);

        char *label = NULL;
        SmcValue labelValue;
        if (smcReadKey(context->smcConnection, labelKey, &labelValue) == 0) {
            label = parseAscii(&labelValue);
        }
        appendReading(readings, &count, label != NULL ? label : fallbackLabel, rpm);
        free(label);
    }
    return count;
}

void MacSensorReadingsFree(MacSensorReading *readings, size_t count) {
    if (readings == NULL) {
        return;
    }
    for (size_t index = 0; index < count; index++) {
        free(readings[index].label);
    }
    free(readings);
}

static char *copyCString(const char *string) {
    if (string == NULL) {
        return NULL;
    }
    size_t length = strlen(string);
    char *copy = malloc(length + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, string, length + 1);
    return copy;
}

static void appendReading(MacSensorReading **readings, size_t *count, const char *label, double value) {
    if (!isfinite(value) || label == NULL || label[0] == '\0') {
        return;
    }

    MacSensorReading *next = realloc(*readings, sizeof(MacSensorReading) * (*count + 1));
    if (next == NULL) {
        return;
    }

    *readings = next;
    (*readings)[*count].label = copyCString(label);
    (*readings)[*count].value = value;
    if ((*readings)[*count].label == NULL) {
        return;
    }
    *count += 1;
}

static char *copyHidProductName(IOHIDServiceClientRef service, size_t index) {
    CFTypeRef raw = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
    if (raw == NULL || CFGetTypeID(raw) != CFStringGetTypeID()) {
        if (raw != NULL) {
            CFRelease(raw);
        }
        char fallback[32] = {0};
        snprintf(fallback, sizeof(fallback), "Sensor %zu", index);
        return copyCString(fallback);
    }

    char buffer[256] = {0};
    Boolean ok = CFStringGetCString((CFStringRef)raw, buffer, sizeof(buffer), kCFStringEncodingUTF8);
    CFRelease(raw);
    if (!ok) {
        char fallback[32] = {0};
        snprintf(fallback, sizeof(fallback), "Sensor %zu", index);
        return copyCString(fallback);
    }
    return copyCString(buffer);
}

static io_connect_t openSmcConnection(void) {
    CFMutableDictionaryRef matching = IOServiceMatching("AppleSMC");
    if (matching == NULL) {
        return 0;
    }

    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, matching);
    if (service == 0) {
        return 0;
    }

    io_connect_t connection = 0;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    return result == KERN_SUCCESS ? connection : 0;
}

static int smcReadKey(io_connect_t connection, const char *key, SmcValue *value) {
    if (connection == 0 || key == NULL || strlen(key) != 4 || value == NULL) {
        return -1;
    }

    SmcParamStruct input;
    SmcParamStruct output;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = smcKeyCode(key);
    input.data8 = kSmcCommandReadKeyInfo;
    if (smcCall(connection, &input, &output) != 0 || output.result != 0) {
        return -1;
    }

    SmcKeyInfoData keyInfo = output.keyInfo;
    memset(&input, 0, sizeof(input));
    memset(&output, 0, sizeof(output));
    input.key = smcKeyCode(key);
    input.keyInfo = keyInfo;
    input.data8 = kSmcCommandReadBytes;
    if (smcCall(connection, &input, &output) != 0 || output.result != 0) {
        return -1;
    }

    value->dataType = keyInfo.dataType;
    value->size = keyInfo.dataSize > 32 ? 32 : keyInfo.dataSize;
    memcpy(value->bytes, output.bytes, sizeof(value->bytes));
    return 0;
}

static int smcCall(io_connect_t connection, const SmcParamStruct *input, SmcParamStruct *output) {
    size_t outputSize = sizeof(SmcParamStruct);
    kern_return_t result = IOConnectCallStructMethod(
        connection,
        kSmcSelector,
        input,
        sizeof(SmcParamStruct),
        output,
        &outputSize
    );
    return result == KERN_SUCCESS ? 0 : -1;
}

static uint32_t smcKeyCode(const char *key) {
    return ((uint32_t)(uint8_t)key[0] << 24)
        | ((uint32_t)(uint8_t)key[1] << 16)
        | ((uint32_t)(uint8_t)key[2] << 8)
        | (uint32_t)(uint8_t)key[3];
}

static void smcDataTypeString(uint32_t dataType, char out[5]) {
    out[0] = (char)((dataType >> 24) & 0xff);
    out[1] = (char)((dataType >> 16) & 0xff);
    out[2] = (char)((dataType >> 8) & 0xff);
    out[3] = (char)(dataType & 0xff);
    out[4] = '\0';
}

static int parseTemperature(const SmcValue *value, double *temperature) {
    char type[5];
    smcDataTypeString(value->dataType, type);

    if (strcmp(type, "sp78") == 0 && value->size >= 2) {
        int16_t raw = (int16_t)((value->bytes[0] << 8) | value->bytes[1]);
        *temperature = (double)raw / 256.0;
        return isfinite(*temperature);
    }

    if (strcmp(type, "flt ") == 0 && value->size >= 4) {
        return parseFloat(value->bytes, temperature);
    }

    return 0;
}

static int parseFanRpm(const SmcValue *value, double *rpm) {
    char type[5];
    smcDataTypeString(value->dataType, type);

    if (strcmp(type, "fpe2") == 0 && value->size >= 2) {
        uint16_t raw = (uint16_t)((value->bytes[0] << 8) | value->bytes[1]);
        *rpm = (double)raw / 4.0;
    } else if (strcmp(type, "flt ") == 0 && value->size >= 4) {
        if (!parseFloat(value->bytes, rpm)) {
            return 0;
        }
    } else {
        uint32_t integer = 0;
        if (!parseInteger(value, &integer)) {
            return 0;
        }
        *rpm = (double)integer;
    }

    return isfinite(*rpm) && *rpm >= 0 && *rpm <= 30000;
}

static int parseInteger(const SmcValue *value, uint32_t *integer) {
    char type[5];
    smcDataTypeString(value->dataType, type);

    if (strcmp(type, "ui8 ") == 0 && value->size >= 1) {
        *integer = value->bytes[0];
        return 1;
    }
    if (strcmp(type, "ui16") == 0 && value->size >= 2) {
        *integer = ((uint32_t)value->bytes[0] << 8) | value->bytes[1];
        return 1;
    }
    if (strcmp(type, "ui32") == 0 && value->size >= 4) {
        *integer = ((uint32_t)value->bytes[0] << 24)
            | ((uint32_t)value->bytes[1] << 16)
            | ((uint32_t)value->bytes[2] << 8)
            | value->bytes[3];
        return 1;
    }
    return 0;
}

static int parseFloat(const uint8_t bytes[32], double *value) {
    uint32_t nativeBits = 0;
    memcpy(&nativeBits, bytes, sizeof(nativeBits));

    float nativeValue = 0;
    memcpy(&nativeValue, &nativeBits, sizeof(nativeValue));

    uint32_t swappedBits = __builtin_bswap32(nativeBits);
    float swappedValue = 0;
    memcpy(&swappedValue, &swappedBits, sizeof(swappedValue));

    if (isfinite(nativeValue) && fabsf(nativeValue) >= 1.0f) {
        *value = nativeValue;
        return 1;
    }
    if (isfinite(swappedValue) && fabsf(swappedValue) >= 1.0f) {
        *value = swappedValue;
        return 1;
    }
    if (isfinite(nativeValue)) {
        *value = nativeValue;
        return 1;
    }
    if (isfinite(swappedValue)) {
        *value = swappedValue;
        return 1;
    }
    return 0;
}

static char *parseAscii(const SmcValue *value) {
    size_t end = 0;
    while (end < value->size && end < 32 && value->bytes[end] != 0) {
        end++;
    }
    while (end > 0 && (value->bytes[end - 1] == ' ' || value->bytes[end - 1] == '\t')) {
        end--;
    }
    if (end == 0) {
        return NULL;
    }

    char *text = malloc(end + 1);
    if (text == NULL) {
        return NULL;
    }
    memcpy(text, value->bytes, end);
    text[end] = '\0';
    return text;
}
