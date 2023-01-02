//
//  InterfaceController.mm
//  CroMagRallyWatch WatchKit Extension
//
//  Created by Willie Chang on 12/1/22.
//

#import "InterfaceController.h"
#import <AVFoundation/AVFoundation.h>
#include <thread>
#import <UIKit/UIKit.h>
#include "CroMagRally.hpp"

@interface InterfaceController ()

@end


@implementation InterfaceController {
    std::thread gameThread;
    WKInterfaceImage *imageView;
    unsigned char *pixels;
    CGContextRef contextRef;
    CGImageRef imageRef;
    
    float scrollProgress;
    CGPoint touchBeganLocation;
    
    AVAudioEngine *audioEngine;
    AVAudioPlayerNode *audioPlayerNode;
    AVAudioMixerNode *audioMixerNode;
    AVAudioPCMBuffer *audioPCMBufferA;
    AVAudioPCMBuffer *audioPCMBufferB;
    AVAudioFormat *audioFormat;
    AVAudioFormat *audioMixerFormat;
    bool audioPlaying;
    bool playBufferB;
    NSTimeInterval lastPlayTime;
    NSTimeInterval targetPlayTimeInterval;
}

- (void)frameUpdate:(id)context {
    memcpy(pixels, gPixels, NUM_GRAPHICS_BYTES);
    imageRef = CGBitmapContextCreateImage(contextRef);
    
    @autoreleasepool {
        UIImage* image = [UIImage imageWithCGImage:imageRef];
        [imageView setImage:image];
    }
    
    CGImageRelease(imageRef);
    
    if (gCrashThud) {
        [[WKInterfaceDevice currentDevice] playHaptic:WKHapticTypeClick];
        gCrashThud = false;
    }
    
    [self.pauseButton setHidden:!gCanSteer];
    
    if (audioPlaying && [NSDate timeIntervalSinceReferenceDate] - lastPlayTime > targetPlayTimeInterval) {
        if (playBufferB) {
            [audioPlayerNode scheduleBuffer:audioPCMBufferB atTime:nil options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataConsumed completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {}];
        } else {
            [audioPlayerNode scheduleBuffer:audioPCMBufferA atTime:nil options:AVAudioPlayerNodeBufferInterruptsAtLoop completionCallbackType:AVAudioPlayerNodeCompletionDataConsumed completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {}];
        }
        [self updateAudioBuffer];
        lastPlayTime = [NSDate timeIntervalSinceReferenceDate];
        playBufferB = !playBufferB;
    }
}

- (void)updateAudioBuffer {
    if (playBufferB) {
        float *const *audioBuffer = audioPCMBufferB.floatChannelData;
        GetAudio(audioBuffer, NUM_SAMPLES * 2);
    } else {
        float *const *audioBuffer = audioPCMBufferA.floatChannelData;
        GetAudio(audioBuffer, NUM_SAMPLES * 2);
    }
}

//- (void)playAudioBuffer:(id)context {
//    if (!audioPlaying) return;
//    [audioPlayerNode scheduleBuffer:audioPCMBuffer atTime:nil options:AVAudioPlayerNodeBufferInterrupts completionCallbackType:AVAudioPlayerNodeCompletionDataConsumed completionHandler:^(AVAudioPlayerNodeCompletionCallbackType callbackType) {
//        [self playAudioBuffer:nil];
//    }];
//    [self updateAudioBuffer];
//}

- (void)setInputFlags:(Byte)inputFlags {
    gInputFlags |= inputFlags;
}

- (void)crownDidRotate:(WKCrownSequencer *)crownSequencer rotationalDelta:(double)rotationalDelta {
    if (gCanSteer) {
        gInputSteer = rotationalDelta;
    } else {
        scrollProgress += rotationalDelta;
        if (scrollProgress >= .1) {
            [self setInputFlags:INPUT_FLAG_UP];
            scrollProgress = fmodf(scrollProgress, .1);
        } else if (scrollProgress <= -.1) {
            [self setInputFlags:INPUT_FLAG_DN];
            scrollProgress = fmodf(scrollProgress, .1);
        }
    }
}

- (void)crownDidBecomeIdle:(nullable WKCrownSequencer *)crownSequencer {
    gInputSteer = 0;
}

- (IBAction)handleTouch:(WKTapGestureRecognizer *)sender {
    CGPoint currentLocation = sender.locationInObject;
    if (sender.state == WKGestureRecognizerStateBegan) {
        touchBeganLocation = currentLocation;
        if (currentLocation.x <= sender.objectBounds.size.width / 2) {
            if (currentLocation.y <= sender.objectBounds.size.height / 2) {
                gInputDecel = true;
            } else {
                gInputBrake = true;
            }
        }
    } else if (sender.state == WKGestureRecognizerStateEnded) {
        gInputDecel = false;
        gInputBrake = false;
        float xDiff = currentLocation.x - touchBeganLocation.x;
        float yDiff = currentLocation.y - touchBeganLocation.y;
        if (abs(xDiff) < 20 && abs(yDiff) < 20) {
            [self setInputFlags:INPUT_FLAG_OK];
        } else if (abs(yDiff) < 20 && xDiff >= 20) {
            [self setInputFlags:INPUT_FLAG_ESC];
        } else if (currentLocation.x > sender.objectBounds.size.width / 2) {
            if (yDiff < -20) {
                [self setInputFlags:INPUT_FLAG_FWRD];
            } else if (yDiff >= 20) {
                [self setInputFlags:INPUT_FLAG_BWRD];
            }
        }
    }
}

- (IBAction)pressedPause {
    [self setInputFlags:INPUT_FLAG_PAUSE];
}

- (void)awakeWithContext:(id)context {
    // Configure interface objects here.
        
    // CROWN
    self.crownSequencer.delegate = self;
    
    // GRAPHICS
    imageView = [self gameImageView];
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    pixels = (unsigned char *) malloc(NUM_GRAPHICS_BYTES);
    contextRef = CGBitmapContextCreate(pixels, WIDTH, HEIGHT, 8, NUM_GRPHICS_CHANNELS * WIDTH, colorSpaceRef, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpaceRef);
    
    // AUDIO
    audioEngine = [[AVAudioEngine alloc] init];
    audioPlayerNode = [[AVAudioPlayerNode alloc] init];
    audioMixerNode = audioEngine.mainMixerNode;
    audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32 sampleRate:44100 channels:2 interleaved:false];
    audioPCMBufferA = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:NUM_SAMPLES];
    audioPCMBufferA.frameLength = NUM_SAMPLES;
    audioPCMBufferB = [[AVAudioPCMBuffer alloc] initWithPCMFormat:audioFormat frameCapacity:NUM_SAMPLES];
    audioPCMBufferB.frameLength = NUM_SAMPLES;
    audioMixerFormat = [audioMixerNode outputFormatForBus:0];
    [audioEngine attachNode:audioPlayerNode];
    [audioEngine connect:audioPlayerNode to:audioMixerNode format:audioMixerFormat];
    [audioEngine startAndReturnError:nil];
    [audioPlayerNode play];
    targetPlayTimeInterval = 0.99 * NUM_SAMPLES / 44100;
    
    // INITIALIZE GAME
    NSString *resPath = [[NSBundle mainBundle] resourcePath];
    gameThread = std::thread(GameThread, std::string([resPath UTF8String]));
    
    // WAIT FOR FRAME TO BE READY
    [self updateAudioBuffer];
    do {
        [NSThread sleepForTimeInterval:0.01];
    } while (!gPixelsReady);
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [self.crownSequencer focus];
    audioPlaying = true;
    [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(frameUpdate:) userInfo:nil repeats:YES];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    audioPlaying = false;
}

@end



