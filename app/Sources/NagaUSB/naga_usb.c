#include "naga_usb.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

struct NagaUsbDevice {
    io_service_t service;
    IOUSBDeviceInterface **device;
};

static void set_err(char *err_buf, size_t err_len, const char *msg) {
    if (!err_buf || err_len == 0) return;
    snprintf(err_buf, err_len, "%s", msg ? msg : "usb error");
}

static IOUSBDeviceInterface **open_device_interface(io_service_t service, char *err_buf, size_t err_len) {
    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(
        service,
        kIOUSBDeviceUserClientTypeID,
        kIOCFPlugInInterfaceID,
        &plugin,
        &score
    );
    if (kr != KERN_SUCCESS || plugin == NULL) {
        set_err(err_buf, err_len, "IOCreatePlugInInterfaceForService failed");
        return NULL;
    }

    IOUSBDeviceInterface **device = NULL;
    HRESULT hr = (*plugin)->QueryInterface(
        plugin,
        CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID650),
        (LPVOID *)&device
    );
    (*plugin)->Release(plugin);

    if (hr != S_OK || device == NULL) {
        set_err(err_buf, err_len, "QueryInterface IOUSBDeviceInterface failed");
        return NULL;
    }

    kr = (*device)->USBDeviceOpen(device);
    if (kr != kIOReturnSuccess) {
        /* Still usable for some control transfers when already open by kernel. */
    }
    return device;
}

int naga_usb_open(uint16_t vendor_id, uint16_t product_id, NagaUsbDevice **out, char *err_buf, size_t err_len) {
    if (!out) return 2;
    *out = NULL;

    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matching) {
        set_err(err_buf, err_len, "IOServiceMatching failed");
        return 2;
    }

    CFNumberRef vid = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &vendor_id);
    CFNumberRef pid = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &product_id);
    CFDictionarySetValue(matching, CFSTR(kUSBVendorID), vid);
    CFDictionarySetValue(matching, CFSTR(kUSBProductID), pid);
    CFRelease(vid);
    CFRelease(pid);

    io_iterator_t iterator = 0;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator);
    if (kr != KERN_SUCCESS) {
        set_err(err_buf, err_len, "IOServiceGetMatchingServices failed");
        return 2;
    }

    io_service_t service = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (!service) {
        set_err(err_buf, err_len, "Razer Naga Trinity not found.");
        return 1;
    }

    IOUSBDeviceInterface **device = open_device_interface(service, err_buf, err_len);
    if (!device) {
        IOObjectRelease(service);
        return 2;
    }

    NagaUsbDevice *dev = calloc(1, sizeof(NagaUsbDevice));
    if (!dev) {
        (*device)->USBDeviceClose(device);
        (*device)->Release(device);
        IOObjectRelease(service);
        set_err(err_buf, err_len, "out of memory");
        return 2;
    }
    dev->service = service;
    dev->device = device;
    *out = dev;
    return 0;
}

void naga_usb_close(NagaUsbDevice *dev) {
    if (!dev) return;
    if (dev->device) {
        (*dev->device)->USBDeviceClose(dev->device);
        (*dev->device)->Release(dev->device);
        dev->device = NULL;
    }
    if (dev->service) {
        IOObjectRelease(dev->service);
        dev->service = 0;
    }
    free(dev);
}

int naga_usb_set_report(
    NagaUsbDevice *dev,
    uint16_t iface,
    const uint8_t *data,
    size_t len,
    char *err_buf,
    size_t err_len
) {
    if (!dev || !dev->device || !data || len == 0) {
        set_err(err_buf, err_len, "invalid set_report args");
        return 2;
    }

    IOUSBDevRequest request;
    memset(&request, 0, sizeof(request));
    request.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBClass, kUSBInterface);
    request.bRequest = 0x09; /* SET_REPORT */
    request.wValue = 0x0300;
    request.wIndex = iface;
    request.wLength = (UInt16)len;
    request.pData = (void *)data;

    IOReturn kr = (*dev->device)->DeviceRequest(dev->device, &request);
    if (kr != kIOReturnSuccess) {
        char tmp[96];
        snprintf(tmp, sizeof(tmp), "DeviceRequest failed: 0x%08x", (unsigned)kr);
        set_err(err_buf, err_len, tmp);
        return 2;
    }
    return 0;
}

void naga_usb_list(uint16_t vendor_id, uint16_t product_id, NagaUsbDeviceInfo *out) {
    if (!out) return;
    memset(out, 0, sizeof(*out));

    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matching) return;

    CFNumberRef vid = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &vendor_id);
    CFNumberRef pid = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt16Type, &product_id);
    CFDictionarySetValue(matching, CFSTR(kUSBVendorID), vid);
    CFDictionarySetValue(matching, CFSTR(kUSBProductID), pid);
    CFRelease(vid);
    CFRelease(pid);

    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) != KERN_SUCCESS) {
        return;
    }

    io_service_t service = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (!service) return;

    char err[64];
    IOUSBDeviceInterface **device = open_device_interface(service, err, sizeof(err));
    uint8_t interfaces = 0;
    if (device) {
        UInt8 numConfig = 0;
        if ((*device)->GetNumberOfConfigurations(device, &numConfig) == kIOReturnSuccess && numConfig > 0) {
            IOUSBConfigurationDescriptorPtr desc = NULL;
            if ((*device)->GetConfigurationDescriptorPtr(device, 0, &desc) == kIOReturnSuccess && desc) {
                interfaces = desc->bNumInterfaces;
            }
        }
        (*device)->USBDeviceClose(device);
        (*device)->Release(device);
    }
    IOObjectRelease(service);

    out->connected = 1;
    out->vendor_id = vendor_id;
    out->product_id = product_id;
    out->interfaces = interfaces;
}
