#import <Foundation/Foundation.h>

#import "Settings.h"

int main(void) {
    @autoreleasepool {
        [Settings loadSettings];
        printf("enAll=%d enTPAll=%d enMMAll=%d handed=%d\n",
               enAll, enTPAll, enMMAll, enHanded);
        printf("trackpadApps=%lu trackpadCommands=%lu recognitionCommands=%lu\n",
               (unsigned long)[trackpadMap count],
               (unsigned long)[trackpadCommands count],
               (unsigned long)[recognitionCommands count]);
        NSDictionary *allApps = [trackpadMap objectForKey:@"All Applications"];
        printf("allApplicationGestures=%lu\n", (unsigned long)[allApps count]);
    }
    return 0;
}
