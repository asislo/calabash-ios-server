#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif
//
//  LPDevice.m
//  calabash
//
//  Created by Karl Krukow on 1/30/14.
//  Copyright (c) 2014 Xamarin. All rights reserved.
//

#import "LPDevice.h"
#import "LPTouchUtils.h"
#import <sys/utsname.h>

NSString *const LPDeviceSimKeyModelIdentifier = @"SIMULATOR_MODEL_IDENTIFIER";
NSString *const LPDeviceSimKeyVersionInfo = @"SIMULATOR_VERSION_INFO";

@interface LPDevice ()

@property(strong, nonatomic) NSDictionary *processEnvironment;
@property(strong, nonatomic) NSDictionary *formFactorMap;

- (id) init_private;

- (UIScreen *) mainScreen;
- (UIScreenMode *) currentScreenMode;
- (CGSize) sizeForCurrentScreenMode;
- (CGFloat) scaleForMainScreen;
- (CGFloat) heightForMainScreenBounds;

- (NSString *) physicalDeviceModelIdentifier;
- (NSString *) simulatorModelIdentfier;

@end

@implementation LPDevice

@synthesize screenDimensions = _screenDimensions;
@synthesize sampleFactor = _sampleFactor;
@synthesize modelIdentifier = _modelIdentifier;
@synthesize formFactor = _formFactor;
@synthesize processEnvironment = _processEnvironment;
@synthesize formFactorMap = _formFactorMap;
@synthesize deviceFamily = _deviceFamily;
@synthesize name = _name;

- (id) init {
  @throw [NSException exceptionWithName:@"Cannot call init"
                                 reason:@"This is a singleton class"
                                 userInfo:nil];
}

+ (LPDevice *) sharedDevice {
  static LPDevice *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[LPDevice alloc] init_private];
  });
  return shared;
}

- (id) init_private {
  self = [super init];
  if (self) {
    // For memoizing.
    _sampleFactor = CGFLOAT_MAX;
  }
  return self;
}

#pragma mark - Convenience Methods for Testing

- (UIScreen *) mainScreen {
  return [UIScreen mainScreen];
}

- (UIScreenMode *) currentScreenMode {
  return [[self mainScreen] currentMode];
}

- (CGSize) sizeForCurrentScreenMode {
  return [self currentScreenMode].size;
}

- (CGFloat) scaleForMainScreen {
  return [[self mainScreen] scale];
}

- (CGFloat) heightForMainScreenBounds {
  return [[self mainScreen] bounds].size.height;
}

#pragma mark - iPhone 6 and 6 Plus Support

// http://www.paintcodeapp.com/news/ultimate-guide-to-iphone-resolutions
// Thanks for the inspiration for iPhone 6 form factor sample.
- (CGFloat) sampleFactor {
  if (_sampleFactor != CGFLOAT_MAX) { return _sampleFactor; }

  _sampleFactor = 1.0f;

  CGFloat scale = [UIScreen mainScreen].scale;

  const CGSize IPHONE6_TARGET_SPACE = CGSizeMake(375.0f, 667.0f);
  const CGSize IPHONE6PLUS_TARGET_SPACE = CGSizeMake(414.0f, 736.0f);

  const CGSize IPHONE6PLUS = CGSizeMake(IPHONE6PLUS_TARGET_SPACE.width * scale,
                                        IPHONE6PLUS_TARGET_SPACE.height * scale);

  CGSize IPHONE6 = CGSizeMake(IPHONE6_TARGET_SPACE.width * scale,
                              IPHONE6_TARGET_SPACE.height * scale);

  const CGFloat IPHONE6_SAMPLE = 1.0f;
  const CGFloat IPHONE6PLUS_SAMPLE = 1.0f;
  const CGFloat IPHONE6_DISPLAY_ZOOM_SAMPLE = 1.171875f;

  UIScreen *screen = [UIScreen mainScreen];
  UIScreenMode *screenMode = [screen currentMode];
  CGSize size = screenMode.size;

  if ([self isIPhone6PlusLike]) {
    if (size.width < IPHONE6PLUS.width && size.height < IPHONE6PLUS.height) {
      _sampleFactor = (IPHONE6PLUS.width / size.width);
      _sampleFactor = (IPHONE6PLUS.height / size.height);
    } else {
      _sampleFactor = IPHONE6PLUS_SAMPLE;
    }
  } else if ([self isIPhone6Like]) {
    if (CGSizeEqualToSize(size, IPHONE6)) {
      _sampleFactor = IPHONE6_SAMPLE;
    } else {
      _sampleFactor = IPHONE6_DISPLAY_ZOOM_SAMPLE;
    }
  } else {
    if ([self isSimulator]) {
      if ([self isIPhone6PlusLike]) {
        if (size.width < IPHONE6PLUS.width && size.height < IPHONE6PLUS.height) {
          _sampleFactor = (IPHONE6PLUS.width / size.width);
          _sampleFactor = (IPHONE6PLUS.height / size.height);
        } else {
          _sampleFactor = IPHONE6PLUS_SAMPLE;
        }
      } else if ([self isIPhone6Like]) {
        if (CGSizeEqualToSize(size, IPHONE6)) {
          _sampleFactor = IPHONE6_SAMPLE;
        } else {
          _sampleFactor = IPHONE6_DISPLAY_ZOOM_SAMPLE;
        }
      }
    }
  }
  return _sampleFactor;
}

- (NSDictionary *) screenDimensions {
  if (_screenDimensions) { return _screenDimensions; }

  UIScreen *screen = [UIScreen mainScreen];
  UIScreenMode *screenMode = [screen currentMode];
  CGSize size = screenMode.size;
  CGFloat scale = screen.scale;

  _screenDimensions = @{
                        @"height" : @(size.height),
                        @"width" : @(size.width),
                        @"scale" : @(scale),
                        @"sample" : @([self sampleFactor])
                        };

  return _screenDimensions;
}

// http://www.everyi.com/by-identifier/ipod-iphone-ipad-specs-by-model-identifier.html
- (NSDictionary *) formFactorMap {
  if (_formFactorMap) { return _formFactorMap; }

  _formFactorMap =

  @{

    // iPhone 4/4s and iPod 4th
    @"iPhone3,1" : @"iphone 3.5in",
    @"iPhone3,3" : @"iphone 3.5in",
    @"iPhone4,1" : @"iphone 3.5in",
    @"iPod4,1"   : @"iphone 3.5in",

    // iPhone 5/5c/5s and iPod 5th + 6th
    @"iPhone5,1" : @"iphone 4in",
    @"iPhone5,2" : @"iphone 4in",
    @"iPhone5,3" : @"iphone 4in",
    @"iPhone5,4" : @"iphone 4in",
    @"iPhone6,1" : @"iphone 4in",
    @"iPhone6,2" : @"iphone 4in",
    @"iPhone6,3" : @"iphone 4in",
    @"iPhone6,4" : @"iphone 4in",
    @"iPod5,1"   : @"iphone 4in",
    @"iPod6,1"   : @"iphone 4in",

    // iPhone 6/6s
    @"iPhone7,2" : @"iphone 6",
    @"iPhone8,1" : @"iphone 6",

    // iPhone 6+
    @"iPhone7,1" : @"iphone 6+",
    @"iPhone8,2" : @"iphone 6+",

    // iPad Pro
    @"iPad6,8" : @"ipad pro"

    };

  return _formFactorMap;
}

- (NSDictionary *) processEnvironment {
  if (_processEnvironment) { return _processEnvironment; }
  _processEnvironment = [[NSProcessInfo processInfo] environment];
  return _processEnvironment;
}

- (NSString *) simulatorModelIdentfier {
  return [self.processEnvironment objectForKey:LPDeviceSimKeyModelIdentifier];
}

- (NSString *) simulatorVersionInfo {
  return [self.processEnvironment objectForKey:LPDeviceSimKeyVersionInfo];
}

- (NSString *) physicalDeviceModelIdentifier {
  struct utsname systemInfo;
  uname(&systemInfo);
  return @(systemInfo.machine);
}

- (NSString *) deviceFamily {
  if (_deviceFamily) { return _deviceFamily; }
  _deviceFamily = [[UIDevice currentDevice] model];
  return _deviceFamily;
}

- (NSString *) name {
  if (_name) { return _name; }
  _name = [[UIDevice currentDevice] name];
  return _name;
}

// The hardware name of the device.
- (NSString *) modelIdentifier {
  if (_modelIdentifier) { return _modelIdentifier; }
  if ([self isSimulator]) {
    _modelIdentifier = [self simulatorModelIdentfier];
  } else {
    _modelIdentifier = [self physicalDeviceModelIdentifier];
  }
  return _modelIdentifier;
}

- (NSString *) formFactor {
  if (_formFactor) { return _formFactor; }

  NSString *modelIdentifier = [self modelIdentifier];
  NSString *value = [self.formFactorMap objectForKey:modelIdentifier];

  if (value) {
    _formFactor = value;
  } else {
    if ([self isIPad]) {
      _formFactor = @"ipad";
    } else {
      _formFactor = modelIdentifier;
    }
  }
  return _formFactor;
}

- (BOOL) isSimulator {
  return [self simulatorModelIdentfier] != nil;
}

- (BOOL) isPhysicalDevice {
  return ![self isSimulator];
}

- (BOOL) isIPhone6Like {
  return [[self formFactor] isEqualToString:@"iphone 6"];
}

- (BOOL) isIPhone6PlusLike {
  return [[self formFactor] isEqualToString:@"iphone 6+"];
}

- (BOOL) isIPad {
  return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
}

- (BOOL) isIPadPro {
  return [[self formFactor] isEqualToString:@"ipad pro"];
}

- (BOOL) isIPhone4Like {
  return [[self formFactor] isEqualToString:@"iphone 3.5in"];
}

- (BOOL) isIPhone5Like {
  return [[self formFactor] isEqualToString:@"iphone 4in"];
}

- (BOOL) isLetterBox {
  CGFloat scale = [self scaleForMainScreen];
  if ([self isIPad] || [self isIPhone4Like] || scale != 2.0) {
    return NO;
  } else {
    return [self heightForMainScreenBounds] * scale == 960;
  }
}

@end
