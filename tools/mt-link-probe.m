#import <Foundation/Foundation.h>

typedef const void *MTDeviceRef;
extern CFMutableArrayRef MTDeviceCreateList(void);

int main(void) {
    @autoreleasepool {
        CFMutableArrayRef devices = MTDeviceCreateList();
        CFIndex count = devices ? CFArrayGetCount(devices) : 0;
        NSLog(@"Multitouch devices: %ld", (long)count);
        if (devices) {
            CFRelease(devices);
        }
    }
    return 0;
}
