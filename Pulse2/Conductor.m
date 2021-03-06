//
//  Conductor.m
//  Pulse2
//
//  Created by Henry Thiemann on 5/5/15.
//  Copyright (c) 2015 Henry Thiemann. All rights reserved.
//

#import "Conductor.h"

@implementation Conductor

double _bpm;
double _beats;
double _masterVolume;

- (instancetype)initWithAudioController:(AEAudioController *)audioController {
    self = [super init];
    
    if (self) {
        self.audioController = audioController;
        self.shouldCheckLevels = false;
        self.theMinigameLoop = nil;
    }
    
    return self;
}

- (void)loadSoundscapeWithPlistNamed:(NSString *)plist {
    
    NSString *pathToPlist = [[NSBundle mainBundle] pathForResource:plist ofType:@"plist"];
    self.data = [[NSDictionary alloc] initWithContentsOfFile:pathToPlist];
    
    NSString *extension = [_data objectForKey:@"extension"];
    _bpm = [[_data objectForKey:@"bpm"] doubleValue];
    _beats = [[_data objectForKey:@"beats"] doubleValue];
    
    NSDictionary *audioFileData = [_data objectForKey:@"audio files"];
    
    self.audioFilePlayers = [[NSMutableDictionary alloc] init];
    self.channelGroups = [[NSMutableDictionary alloc] init];
    
    for (NSString *filename in [audioFileData allKeys]) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:filename withExtension:extension];
        
        AEAudioFilePlayer *player = [AEAudioFilePlayer audioFilePlayerWithURL:url audioController:_audioController error:NULL];
        player.loop = YES;
        player.channelIsPlaying = NO;
        player.volume = 0;
        
        AEChannelGroupRef group = [_audioController createChannelGroup];
        [_audioController addChannels:[NSArray arrayWithObject:player] toChannelGroup:group];
        
        [_audioFilePlayers setObject:player forKey:filename];
        [_channelGroups setObject:[NSValue valueWithPointer:group] forKey:filename];
    }
    
    AudioComponentDescription component = AEAudioComponentDescriptionMake(kAudioUnitManufacturer_Apple,
                                                                          kAudioUnitType_MusicDevice,
                                                                          kAudioUnitSubType_Sampler);
    NSError *error = NULL;
    self.collisionSound = [[AEAudioUnitChannel alloc] initWithComponentDescription:component audioController:_audioController error:&error];
    if (!_collisionSound) {
        // report error
    } else {
        
        NSURL *presetURL = [[NSBundle mainBundle] URLForResource:@"piano" withExtension:@"aupreset"];
        
        OSStatus result = noErr;
        AUSamplerInstrumentData auPreset = {0};
        auPreset.fileURL = (__bridge CFURLRef)presetURL;
        auPreset.instrumentType = kInstrumentType_AUPreset;
        result = AudioUnitSetProperty(_collisionSound.audioUnit,
                                      kAUSamplerProperty_LoadInstrument,
                                      kAudioUnitScope_Global,
                                      0,
                                      &auPreset,
                                      sizeof(auPreset));
    }
    
    [_audioController addChannels:[NSArray arrayWithObject:_collisionSound]];
    
    self.collisionNotes = [_data objectForKey:@"collision notes"];
    
    _shouldCheckLevels = true;
    _masterVolume = 1;
}

- (void)releaseSoundscape
{
    _shouldCheckLevels = false;
    [self performSelector:@selector(decreaseVolume) withObject:nil afterDelay:0.01];
    
}

- (void)decreaseVolume {
    if (_masterVolume > 0) {
        _masterVolume -= 0.05;
        for (NSString *loopName in _channelGroups) {
            AEChannelGroupRef group = [[_channelGroups objectForKey:loopName] pointerValue];
            [_audioController setVolume:_masterVolume forChannelGroup:group];
        }
        [self performSelector:@selector(decreaseVolume) withObject:nil afterDelay:0.05];
    } else {
        [self stop];
        [_audioController removeChannels:[_audioFilePlayers allValues]];
        
        _audioFilePlayers = nil;
        _channelGroups = nil;
        _data = nil;
    }
}

- (void)start {
    for (NSString *filename in _audioFilePlayers) {
        AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:filename];
        player.channelIsPlaying = YES;
    }
}

- (void)stop {
    for (NSString *filename in _audioFilePlayers) {
        AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:filename];
        player.channelIsPlaying = NO;
    }
}

-(void)playCollisionSoundWithVelocity:(int)vel {
    int r = arc4random_uniform((int)[_collisionNotes count]);
    MusicDeviceMIDIEvent(_collisionSound.audioUnit, 0x90, (UInt32)[_collisionNotes[r] integerValue], vel, 0);
}

- (void)setVolumeForLoop:(NSString *)loopName withVolume:(double)volume {
    AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:loopName];
    player.volume = volume;
}

- (void)fadeVolumeForLoop:(NSString *)loopName withDuration:(double)duration fadeIn:(BOOL)fadeIn{ //doesn't fade yet
    AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:loopName];
    [UIView animateWithDuration:duration animations:^(void){
       if(fadeIn)
           player.volume = 1;
       else
           player.volume = 0;
    }];
}

- (void)setMinigameLoop:(NSString *)loopName {
    if (loopName == nil) {
        for (NSString *name in _audioFilePlayers) {
            AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:name];
            if (player.volume > 0) {
                [UIView animateWithDuration:1.0 animations:^{
                    player.volume = 1.0;
                }];
            }
        }
    } else {
        _theMinigameLoop = [_audioFilePlayers objectForKey:loopName];
        for (NSString *name in _audioFilePlayers) {
            AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:name];
            if (player.volume > 0) {
                [UIView animateWithDuration:1.0 animations:^{
                    player.volume = 0.5;
                }];
            }
        }
        [UIView animateWithDuration:1.0 animations:^{
            _theMinigameLoop.volume = 1.0;
        }];
    }
}

- (double)getPowerLevelForLoop:(NSString *)loopName {
    // return if not in game scene
    if (!_shouldCheckLevels)
        return 0;
    
    AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:loopName];
    AEChannelGroupRef group = [[_channelGroups objectForKey:loopName] pointerValue];
    
    Float32 powerLevel, peakLevel;
    [_audioController averagePowerLevel:&powerLevel peakHoldLevel:&peakLevel forGroup:group];
    
    return pow(10, powerLevel / 40) * player.volume;
}

- (double)getCurrentBeatForLoop:(NSString *)loopName {
    AEAudioFilePlayer *player = [_audioFilePlayers objectForKey:loopName];
    return _beats * (player.currentTime / player.duration);
}

- (NSArray *)getFilenames {
    return [[_data objectForKey:@"audio files"] allKeys];
}

- (NSString *)getSoundscapeName
{
    return [_data objectForKey: @"name"];
}

@end
