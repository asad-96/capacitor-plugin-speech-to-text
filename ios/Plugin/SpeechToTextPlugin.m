#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(SpeechToTextPlugin, "SpeechToText",
           CAP_PLUGIN_METHOD(hasPermission, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(initialize, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(locales, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(stop, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(cancel, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(listen, CAPPluginReturnPromise);
)
