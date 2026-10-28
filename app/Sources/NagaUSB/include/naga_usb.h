#ifndef NAGA_USB_H
#define NAGA_USB_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NagaUsbDevice NagaUsbDevice;

typedef struct {
    int connected;
    uint16_t vendor_id;
    uint16_t product_id;
    uint8_t interfaces;
} NagaUsbDeviceInfo;

/* 0 = ok, 1 = not found, 2 = usb error (message in err_buf) */
int naga_usb_open(uint16_t vendor_id, uint16_t product_id, NagaUsbDevice **out, char *err_buf, size_t err_len);
void naga_usb_close(NagaUsbDevice *dev);

/* SET_REPORT control transfer: bmRequestType=0x21 bRequest=0x09 wValue=0x0300 */
int naga_usb_set_report(NagaUsbDevice *dev, uint16_t iface, const uint8_t *data, size_t len, char *err_buf, size_t err_len);

void naga_usb_list(uint16_t vendor_id, uint16_t product_id, NagaUsbDeviceInfo *out);

#ifdef __cplusplus
}
#endif

#endif
