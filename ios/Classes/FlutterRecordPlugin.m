#import "FlutterRecordPlugin.h"
#import <flutter_record/flutter_record-Swift.h>

@implementation FlutterRecordPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterRecordPlugin registerWithRegistrar:registrar];
}
@end
