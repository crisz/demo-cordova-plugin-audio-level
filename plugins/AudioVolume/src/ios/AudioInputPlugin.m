//
//  AudioInputPlugin.m
//  MyApp
//
//  Created by Cristian Traina on 14/04/2020.
//

#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>
#include <AudioToolbox/AudioToolbox.h>

#import "AudioInputPlugin.h"

static AudioStreamBasicDescription AUCanonicalASBD(Float64 sampleRate, UInt32 channel);
static AudioStreamBasicDescription CanonicalASBD(Float64 sampleRate, UInt32 channel);
static OSStatus MyAURenderCallack(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber,
                                  UInt32 inNumberFrames, AudioBufferList *ioData);
// static OSStatus MyPlayAURenderCallack (
//                                    void                        *inRefCon,
//                                    AudioUnitRenderActionFlags  *ioActionFlags,
//                                    const AudioTimeStamp        *inTimeStamp,
//                                    UInt32                      inBusNumber,
//                                    UInt32                      inNumberFrames,
//                                    AudioBufferList             *ioData
//                                    );


@interface AudioInputPlugin ()
- (void)prepareBuffer;
- (void)prepareAUGraph;
- (void)prepareAudioUnit;
- (AudioStreamBasicDescription)auCanonicalASBDSampleRate:(Float64)sampleRate channel:(UInt32)channel;
- (AudioStreamBasicDescription)canonicalASBDSampleRate:(Float64)sampleRate channel:(UInt32)channel;
- (void)write:(UInt32)inNumberFrames data:(AudioBufferList *)ioData;
- (void)read:(UInt32)inNumberFrames data:(AudioBufferList *)ioData;
@end

@implementation AudioInputPlugin

@synthesize secondsOfSilence = __secondsOfSilence;
@synthesize auGraph = __auGraph;
@synthesize isRecording = __isRecording;
@synthesize audioUnit = __audioUnit;
@synthesize phase = __phase;
@synthesize sampleRate = __sampleRate;
// @synthesize isPlaying = __isPlaying;
@synthesize audioUnitOutputFormat = __audioUnitOutputFormat;
@synthesize buffer = __buffer;
@synthesize startingSampleCount = __startingSampleCount;
@synthesize maxSampleCount = __maxSampleCount;

// - (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
// {
//     self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
//     if (self) {
//         // Custom initialization
//     }
//     return self;
// }


// - (void)didReceiveMemoryWarning
// {
//     // Releases the view if it doesn't have a superview.
//     [super didReceiveMemoryWarning];
    
//     // Release any cached data, images, etc that aren't in use.
// }

#pragma mark - View lifecycle

+ (AudioInputPlugin*)getInstance
{
    AudioInputPlugin* aip = [[AudioInputPlugin alloc] init];
    [aip startup];
    NSLog(@"getInstance init");
    return aip;
}

- (void)startup
{

    [self prepareBuffer];

    self.isRecording = NO;
    // self.isPlaying = NO;
    self.secondsOfSilence = 0;
    [self prepareAUGraph];
    [self prepareAudioUnit];
}

- (void)cean
{
    if (self.isRecording)   [self stop:nil];
    AUGraphUninitialize(self.auGraph);
    AUGraphClose(self.auGraph);
    DisposeAUGraph(self.auGraph);
    
    // if (self.isPlaying) [self stop:nil];
    AudioUnitUninitialize(self.audioUnit);
    AudioComponentInstanceDispose(self.audioUnit);
    
    free(self.buffer);
    self.buffer = NULL;
    
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}



- (IBAction)record:(id)sender
{
    if (self.isRecording)   return;
    
    AUGraphStart(self.auGraph);
    AUGraphAddRenderNotify(self.auGraph, MyAURenderCallack, (__bridge void *)(self));
    self.isRecording = YES;
    self.startingSampleCount = 0;
}



- (IBAction)stop:(id)sender
{
    if (self.isRecording) {
        AUGraphRemoveRenderNotify(self.auGraph, MyAURenderCallack, (__bridge void *)(self));
        AUGraphStop(self.auGraph);
    }
    // if (self.isPlaying) {
    //     AudioOutputUnitStop(self.audioUnit);
    // }
    self.isRecording = NO;
    // self.isPlaying = NO;
}

- (void)prepareBuffer
{
    
    uint32_t    bytesPerSample = sizeof(AudioUnitSampleType);
    uint32_t    sec = 1000;
    self.startingSampleCount = 0;
    self.maxSampleCount = (44100 * sec);
    self.buffer = malloc(self.maxSampleCount * bytesPerSample);
}

- (void)prepareAUGraph
{
    AUNode      remoteIONode;
    AudioUnit   remoteIOUnit;
    
    NewAUGraph(&__auGraph);
    AUGraphOpen(self.auGraph);
    
    AudioComponentDescription   cd;
    cd.componentType            = kAudioUnitType_Output;
    cd.componentSubType         = kAudioUnitSubType_RemoteIO;
    cd.componentManufacturer    = kAudioUnitManufacturer_Apple;
    cd.componentFlags           = 0;
    cd.componentFlagsMask       = 0;
    
    AUGraphAddNode(self.auGraph, &cd, &remoteIONode);
    AUGraphNodeInfo(self.auGraph, remoteIONode, NULL, &remoteIOUnit);
    
    UInt32  flag = 1;
    AudioUnitSetProperty(remoteIOUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flag, sizeof(flag));
    
    AudioStreamBasicDescription audioFormat = [self auCanonicalASBDSampleRate:44100.0 channel:1];
    AudioUnitSetProperty(remoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, sizeof(AudioStreamBasicDescription));
    AudioUnitSetProperty(remoteIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(AudioStreamBasicDescription));
    
    AUGraphConnectNodeInput(self.auGraph, remoteIONode, 1, remoteIONode, 0);
    AUGraphInitialize(self.auGraph);
}

- (void)prepareAudioUnit
{

    AudioComponentDescription   cd;
    cd.componentType            = kAudioUnitType_Output;
    cd.componentSubType         = kAudioUnitSubType_RemoteIO;
    cd.componentManufacturer    = kAudioUnitManufacturer_Apple;
    cd.componentFlags           = 0;
    cd.componentFlagsMask       = 0;

    AudioComponent  component = AudioComponentFindNext(NULL, &cd);
    AudioComponentInstanceNew(component, &__audioUnit);
    AudioUnitInitialize(self.audioUnit);
    AURenderCallbackStruct  callbackStruct;
    // callbackStruct.inputProc = MyPlayAURenderCallack;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(AURenderCallbackStruct));

    self.phase = 0.0;
    self.sampleRate = 44100.0;
    
    AudioStreamBasicDescription audioFormat = [self auCanonicalASBDSampleRate:self.sampleRate channel:2];
    
    AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(AudioStreamBasicDescription));
}

- (AudioStreamBasicDescription)auCanonicalASBDSampleRate:(Float64)sampleRate channel:(UInt32)channel
{
    return AUCanonicalASBD(sampleRate, channel);
}

- (AudioStreamBasicDescription)canonicalASBDSampleRate:(Float64)sampleRate channel:(UInt32)channel
{
    return CanonicalASBD(sampleRate, channel);
}

- (void)write:(UInt32)inNumberFrames data:(AudioBufferList *)ioData
{
#if TARGET_IPHONE_SIMULATOR
#else   /* TARGET_IPHONE_SIMULATOR */
#endif  /* TARGET_IPHONE_SIMULATOR */
    /*
    DBGMSG(@"%s, inNumberFrames(%u), startingSampleCount(%u)", __func__, (unsigned int)inNumberFrames, (unsigned int)self.startingSampleCount);
    */
    uint32_t    available = self.maxSampleCount - self.startingSampleCount;
    if (available < inNumberFrames) {
        inNumberFrames = available;
    }
    memcpy(self.buffer + self.startingSampleCount, ioData->mBuffers[0].mData, sizeof(AudioUnitSampleType) * inNumberFrames);
    self.startingSampleCount = self.startingSampleCount + inNumberFrames;
    if (self.maxSampleCount <= self.startingSampleCount) {
        [self stop:nil];
    }
}

- (void)read:(UInt32)inNumberFrames data:(AudioBufferList *)ioData
{
#if TARGET_IPHONE_SIMULATOR
#else   /* TARGET_IPHONE_SIMULATOR */
#endif  /* TARGET_IPHONE_SIMULATOR */
    /*
    DBGMSG(@"%s, inNumberFrames(%u), startingSampleCount(%u)", __func__, (unsigned int)inNumberFrames, (unsigned int)self.startingSampleCount);
    */
    uint32_t    available = self.maxSampleCount - self.startingSampleCount;
    uint32_t    num = inNumberFrames;
    if (available < num) {
        num = available;
    }
    memcpy(ioData->mBuffers[0].mData, self.buffer + self.startingSampleCount, sizeof(AudioUnitSampleType) * num);
    self.startingSampleCount = self.startingSampleCount + num;
    if (self.maxSampleCount <= self.startingSampleCount)
        self.startingSampleCount = 0;
    if (num < inNumberFrames) {
        num = inNumberFrames - num;
        memcpy(ioData->mBuffers[0].mData, self.buffer + self.startingSampleCount, sizeof(AudioUnitSampleType) * num);
        self.startingSampleCount = self.startingSampleCount + num;
    }
    memcpy(ioData->mBuffers[1].mData, ioData->mBuffers[0].mData, sizeof(AudioUnitSampleType) * inNumberFrames);
}

@end

static AudioStreamBasicDescription AUCanonicalASBD(Float64 sampleRate, UInt32 channel)
{
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate         = sampleRate;
    audioFormat.mFormatID           = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags        = kAudioFormatFlagsAudioUnitCanonical;
    audioFormat.mChannelsPerFrame   = channel;
    audioFormat.mBytesPerPacket     = sizeof(AudioUnitSampleType);
    audioFormat.mBytesPerFrame      = sizeof(AudioUnitSampleType);
    audioFormat.mFramesPerPacket    = 1;
    audioFormat.mBitsPerChannel     = 8 * sizeof(AudioUnitSampleType);
    audioFormat.mReserved           = 0;
    return audioFormat;
}

static AudioStreamBasicDescription CanonicalASBD(Float64 sampleRate, UInt32 channel)
{
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate         = sampleRate;
    audioFormat.mFormatID           = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags        = kAudioFormatFlagsCanonical;
    audioFormat.mChannelsPerFrame   = channel;
    audioFormat.mBytesPerPacket     = sizeof(AudioSampleType) * channel;
    audioFormat.mBytesPerFrame      = sizeof(AudioSampleType) * channel;
    audioFormat.mFramesPerPacket    = 1;
    audioFormat.mBitsPerChannel     = 8 * sizeof(AudioSampleType);
    audioFormat.mReserved           = 0;
    return audioFormat;
}

static OSStatus MyAURenderCallack(void *inRefCon,
                                  AudioUnitRenderActionFlags *ioActionFlags,
                                  const AudioTimeStamp *inTimeStamp,
                                  UInt32 inBusNumber,
                                  UInt32 inNumberFrames,
                                  AudioBufferList *ioData)
{
    
//    NSLog(@"%s, inBusNumber:%u, inNumberFrames:%u", __func__, (unsigned int)inBusNumber, (unsigned int)inNumberFrames);
//    NSLog(@"ioData: mNumberBuffers(%u)", (unsigned int)ioData->mNumberBuffers);
    
    AudioInputPlugin *audioInputPlugin = (__bridge AudioInputPlugin *) inRefCon;
    
//    for (unsigned int i = 0; i < ioData->mNumberBuffers; i++) {
//        NSLog(@"ioData->mBuffers[%u]: mNumberChannels(%u), mDataByteSize(%u)",
//               i,
//               (unsigned int)ioData->mBuffers[i].mNumberChannels,
//               (unsigned int)ioData->mBuffers[i].mDataByteSize);
//        ioData->mBuffers[i].mData;
//    }
    
    float accumulator = 0;
    AudioBuffer buffer = ioData->mBuffers[0];
    float * data = (float *)buffer.mData;
    UInt32 numSamples = buffer.mDataByteSize / sizeof(float);

    for (UInt32 i = 0; i < numSamples; i++) {
        accumulator += data[i] * data[i] * 30000000000;
    }
    float power = accumulator / (float)numSamples;
    float decibels = 10 * log10f(power);
    
    if (decibels > 30) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // audioInputPlugin.stateLabel.text = @"Talking";
            // send talking
        });
        
        audioInputPlugin.secondsOfSilence = 0;
        
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            // audioInputPlugin.stateLabel.text = @"Silence";
            // send silence
        });
        
        audioInputPlugin.secondsOfSilence += 1.0 * numSamples  / 44100.0;
    }
    
    
    
    NSLog(@"Decibels %f", decibels);
    NSLog(@"Seconds of silence: %f", audioInputPlugin.secondsOfSilence);
    
    [audioInputPlugin write:inNumberFrames data:ioData];
    return noErr;
}

// static OSStatus MyPlayAURenderCallack (
//                                        void                        *inRefCon,
//                                        AudioUnitRenderActionFlags  *ioActionFlags,
//                                        const AudioTimeStamp        *inTimeStamp,
//                                        UInt32                      inBusNumber,
//                                        UInt32                      inNumberFrames,
//                                        AudioBufferList             *ioData
//                                        )
// {
//     ViewController *viewController = (__bridge ViewController *) inRefCon;
//     [viewController read:inNumberFrames data:ioData];
    
//     /*
//     float   freq = 440 * 2.0 * M_PI / viewController.sampleRate;
//     double  phase = viewController.phase;
//     AudioUnitSampleType *outL = ioData->mBuffers[0].mData;
//     AudioUnitSampleType *outR = ioData->mBuffers[1].mData;
//     for (int i = 0; i < inNumberFrames; i++) {
//         float   wave = sin(phase);
//         AudioUnitSampleType sample = wave * (1 << kAudioUnitSampleFractionBits);
//         *outL++ = sample;
//         *outR++ = sample;
//         phase = phase + freq;
//     }
//     viewController.phase = phase;
//     */
//     return noErr;
// }
