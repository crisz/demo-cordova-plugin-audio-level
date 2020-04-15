
/********* AudioVolume.m Cordova Plugin Implementation *******/
//
//  AudioVolume.m
//  MyApp
//
//  Created by Cristian Traina on 14/04/2020.
//

#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>
#include <AudioToolbox/AudioToolbox.h>
#include "AudioInputPlugin.h"

@interface AudioVolume : CDVPlugin {
  // Member variables go here.
}

- (void)coolMethod:(CDVInvokedUrlCommand*)command;
@end

@implementation AudioVolume

- (void)coolMethod:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    AudioInputPlugin* aip = [AudioInputPlugin getInstance];

    NSString* echo = [NSString stringWithUTF8String:str];

    if (echo != nil && [echo length] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


@end

