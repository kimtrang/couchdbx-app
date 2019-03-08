//
//  LaunchAtLoginController.m
//
//  Copyright 2011 Tomáš Znamenáček
//  Copyright 2010 Ben Clark-Robinson
//
// (The MIT License)
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the ‘Software’),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "LaunchAtLoginController.h"

static NSString *const StartAtLoginKey = @"launchAtLogin";

@interface LaunchAtLoginController ()
@property(assign) LSSharedFileListRef loginItems;
@end

@implementation LaunchAtLoginController
@synthesize loginItems;

#pragma mark Change Observing

void sharedFileListDidChange(LSSharedFileListRef inList, void *context)
{
    LaunchAtLoginController *self = (id) context;
    [self willChangeValueForKey:StartAtLoginKey];
    [self didChangeValueForKey:StartAtLoginKey];
}

#pragma mark Initialization

- (id) init
{
    [super init];
    loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    LSSharedFileListAddObserver(loginItems, CFRunLoopGetMain(),
        (CFStringRef)NSDefaultRunLoopMode, sharedFileListDidChange, self);
    return self;
}

- (void) dealloc
{
    LSSharedFileListRemoveObserver(loginItems, CFRunLoopGetMain(),
        (CFStringRef)NSDefaultRunLoopMode, sharedFileListDidChange, self);
    CFRelease(loginItems);
    [super dealloc];
}

#pragma mark Launch List Control

- (LSSharedFileListItemRef) findItemWithURL: (NSURL*) wantedURL inFileList: (LSSharedFileListRef) fileList
{
    if (wantedURL == NULL || fileList == NULL)
        return NULL;

    NSArray *listSnapshot = [NSMakeCollectable(LSSharedFileListCopySnapshot(fileList, NULL)) autorelease];
    for (id itemObject in listSnapshot) {
        LSSharedFileListItemRef item = (LSSharedFileListItemRef) itemObject;
        UInt32 resolutionFlags = kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;
        CFURLRef currentItemURL = NULL;
        OSStatus err = LSSharedFileListItemResolve(item, resolutionFlags, &currentItemURL, /*outRef*/ NULL);
        if (err == noErr) {
            Boolean foundIt = CFEqual(currentItemURL, wantedURL);
            CFRelease(currentItemURL);
            if (foundIt) {
                return item;
            }
        }
    }

    return NULL;
}

- (BOOL) willLaunchAtLogin: (NSURL*) itemURL
{
    return !![self findItemWithURL:itemURL inFileList:loginItems];
}

- (void) setLaunchAtLogin: (BOOL) enabled forURL: (NSURL*) itemURL
{
    LSSharedFileListItemRef appItem = [self findItemWithURL:itemURL inFileList:loginItems];
    if (enabled && !appItem) {
        LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemBeforeFirst,
            NULL, NULL, (CFURLRef)itemURL, NULL, NULL);
    } else if (!enabled && appItem)
        LSSharedFileListItemRemove(loginItems, appItem);
}

#pragma mark Basic Interface

- (NSURL*) appURL
{
    return [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
}

- (void) setLaunchAtLogin: (BOOL) enabled
{
    [self willChangeValueForKey:StartAtLoginKey];
    [self setLaunchAtLogin:enabled forURL:[self appURL]];
    [self didChangeValueForKey:StartAtLoginKey];
}

- (BOOL) launchAtLogin
{
    return [self willLaunchAtLogin:[self appURL]];
}

@end