//
//  Generated file. Do not edit.
//

#import "GeneratedPluginRegistrant.h"

#if __has_include(<camera/CameraPlugin.h>)
#import <camera/CameraPlugin.h>
#else
@import camera;
#endif

#if __has_include(<firebase_ml_vision/FirebaseMlVisionPlugin.h>)
#import <firebase_ml_vision/FirebaseMlVisionPlugin.h>
#else
@import firebase_ml_vision;
#endif

#if __has_include(<flutter_blue/FlutterBluePlugin.h>)
#import <flutter_blue/FlutterBluePlugin.h>
#else
@import flutter_blue;
#endif

#if __has_include(<image_picker/FLTImagePickerPlugin.h>)
#import <image_picker/FLTImagePickerPlugin.h>
#else
@import image_picker;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [CameraPlugin registerWithRegistrar:[registry registrarForPlugin:@"CameraPlugin"]];
  [FLTFirebaseMlVisionPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseMlVisionPlugin"]];
  [FlutterBluePlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterBluePlugin"]];
  [FLTImagePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTImagePickerPlugin"]];
}

@end
