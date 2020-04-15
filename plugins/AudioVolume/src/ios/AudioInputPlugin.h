//
//  AudioInputPlugin.h
//  MyApp
//
//  Created by Cristian Traina on 14/04/2020.
//

#ifndef AudioInputPlugin_h

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


@interface AudioInputPlugin: NSObject


@property (nonatomic, assign) Float64                       secondsOfSilence;
@property (nonatomic, assign) AUGraph                       auGraph;
@property (nonatomic, assign) BOOL                          isRecording;
@property (nonatomic, assign) AudioUnit                     audioUnit;
@property (nonatomic, assign) double                        phase;
@property (nonatomic, assign) Float64                       sampleRate;
@property (nonatomic, assign) AudioStreamBasicDescription   audioUnitOutputFormat;
@property (nonatomic, assign) AudioUnitSampleType           *buffer;
@property (nonatomic, assign) uint32_t                      startingSampleCount;
@property (nonatomic, assign) uint32_t                      maxSampleCount;
- (IBAction)record:(id)sender;
- (IBAction)stop:(id)sender;
- (void)startup;
+ getInstance;

@end



#define AudioInputPlugin_h


#endif /* AudioInputPlugin_h */
