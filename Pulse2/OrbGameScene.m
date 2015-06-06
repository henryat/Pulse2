//
//  SongTrainScene.m
//  protogame191
//
//  Created by Ben McK on 5/5/15.
//  Copyright (c) 2015 Henry Thiemann. All rights reserved.
//

#import "OrbGameScene.h"

@implementation OrbGameScene

#pragma mark - INITIALIZATION

- (instancetype)initWithLoopData:(LoopData *)data conductor:(Conductor *)conductor size:(CGSize)size {
    self = [super initWithSize:size];
    if (self) {
        self.loopData = data;
        self.conductor = conductor;
    }
    
    return self;
}

- (void) didMoveToView:(SKView *)view
{
    // setup scene
    self.backgroundColor = [SKColor colorWithRed:10.0/255 green:55.0/255 blue:70.0/255 alpha:1.0];
    self.scaleMode = SKSceneScaleModeAspectFit;
    
    // setup global variables
    _nextBeat = [self getNearestHigherBeat];
    _resetLoopTime = 0;
    _resetLoopBeat = NO;
    _streakCounter = 0;
    _lastBeat = -1; // this signals we don't know what last beat is.
    float screenWidth = [UIScreen mainScreen].bounds.size.width;
    _leftTrackCenter = screenWidth/3;
    _rightTrackCenter = screenWidth*2/3;
    
    
    [_conductor addObserver:self forKeyPath:@"currentBeat" options:0 context:nil];
    self.view.frameInterval = 2;
    
    // add nodes
    [self addButtons];
    [self addTrain];
    [self initStreakDisplay];
    [self addBackButton];
    
    NSString *hihatPath = [[NSBundle mainBundle] pathForResource:@"hi_hat" ofType:@"caf"];
    NSURL *hihatURL = [NSURL fileURLWithPath:hihatPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)hihatURL, &_hihatSound);
}

-(void) addButtons
{
    float screenWidth = [UIScreen mainScreen].bounds.size.width;
    // left button
    SKSpriteNode *leftButton = [SKSpriteNode spriteNodeWithColor:[UIColor blueColor] size:CGSizeMake(screenWidth/2,100)];
    leftButton.position = CGPointMake(leftButton.frame.size.width/2, leftButton.frame.size.height/2);
    leftButton.name = @"leftButton";//how the node is identified later
    leftButton.color = [SKColor purpleColor];
    [self addChild:leftButton];
    // right button
    SKSpriteNode *rightButton = [SKSpriteNode spriteNodeWithColor:[UIColor blueColor] size:CGSizeMake(screenWidth/2,100)];
    rightButton.position = CGPointMake(screenWidth/2 + rightButton.frame.size.width/2, rightButton.frame.size.height/2);
    rightButton.name = @"rightButton";//how the node is identified later
    rightButton.color = [SKColor greenColor];
    [self addChild:rightButton];
}

- (void)addTrain
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    _train = [SKSpriteNode spriteNodeWithImageNamed:@"train"];
    _train.position = CGPointMake(screenWidth/2, screenHeight/3);
    [self addChild:_train];
}

- (void)addBackButton
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    SKSpriteNode *backButton = [SKSpriteNode spriteNodeWithImageNamed:@"blurGlow2"];
    backButton.position = CGPointMake(screenWidth/2, screenHeight);
    backButton.name = @"backButton";//how the node is identified later
    backButton.color = [SKColor greenColor];
    backButton.colorBlendFactor = .9;
    [self addChild:backButton];
}

-(void)initStreakDisplay
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    _streakDisplay = [SKLabelNode labelNodeWithText:[NSString stringWithFormat:@"%i", _streakCounter]];
    _streakDisplay.fontSize = 18;
    _streakDisplay.fontColor = [UIColor whiteColor];
    _streakDisplay.fontName = @"Avenir-Medium";
    [_streakDisplay setPosition: CGPointMake(screenWidth - 25, screenHeight - 60)];
    _streakDisplay.alpha = .6;
    _streakDisplay.userInteractionEnabled = NO;
    [self addChild:_streakDisplay];
}

#pragma mark - INTERACTION

- (void)displayDirections
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Train Trax"
                                                    message:@"Hop to the rhythm of this loop to keep the train on the tracks! 20 successful hops in a row will unlock this loop!"
                                                   delegate:nil
                                          cancelButtonTitle:@"Thanks Bruh"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];
    
    if ([node.name isEqualToString:@"leftButton"]) {
        [self hop:@"left"];
    } else if ([node.name isEqualToString:@"rightButton"]) {
        [self hop:@"right"];
    } else if ([node.name isEqualToString:@"backButton"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ReturnToGameScene" object:self userInfo:nil];
    }
}

- (void)hop:(NSString *)direction {
    CGFloat jumpDuration = .25;
    CGFloat destination = [direction isEqualToString:@"left"] ? _leftTrackCenter : _rightTrackCenter;
    CGFloat distance = destination - _train.position.x ;
    SKAction *moveFirstHalf = [SKAction moveByX:distance/2 y:0 duration:jumpDuration/2];
    SKAction *rise = [SKAction scaleTo:1.4 duration:jumpDuration/2];
    rise.timingMode = SKActionTimingEaseOut;
    SKAction *moveSecondHalf = [SKAction moveByX:distance/2 y:0 duration:jumpDuration/2];
    SKAction *fall = [SKAction scaleTo:1 duration:jumpDuration/2];
    fall.timingMode = SKActionTimingEaseIn;
    SKAction *jumpFirstHalf = [SKAction group:@[moveFirstHalf, rise]];
    SKAction *jumpSecondHalf = [SKAction group:@[moveSecondHalf, fall]];
    SKAction *jump = [SKAction sequence:@[jumpFirstHalf, jumpSecondHalf]];
    _trainIsJumping = YES;
    [_train runAction:jump completion:^(void){
        _trainIsJumping = NO;
        CGPoint location = _train.frame.origin;
        NSArray *nodes = [self nodesAtPoint:location];
        BOOL trackFound = NO;
        for (SKNode *node in nodes) {
            if([node.name isEqualToString:@"track"])
                trackFound = YES;
        }
        if(!trackFound){
            [self flashColoredScreen:[UIColor redColor]];
            _streakCounter = 0;
        }
    }];
    AudioServicesPlaySystemSound(_hihatSound);
}

- (void)flashColoredScreen:(UIColor *)colorToFlash
{
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGRect rect = CGRectMake(0, 0, screenWidth, screenHeight);
    SKShapeNode *coloredCover = [SKShapeNode shapeNodeWithRect:rect];
    coloredCover.fillColor = colorToFlash;
    coloredCover.userInteractionEnabled = NO;
    [self addChild:coloredCover];
    SKAction *fadeOut = [SKAction fadeAlphaTo:0 duration:.4];
    [coloredCover runAction:fadeOut completion:^(void){
        [self removeChildrenInArray:@[coloredCover]];
    }];
}

- (void)updateStreakCounterDisplay
{
    _streakDisplay.text = [NSString stringWithFormat:@"%i", _streakCounter];
}

#pragma mark - TRAIN TRACKS

- (double)getFirstBeat
{
    NSDictionary *beatMap = [_loopData getBeatMap];
    NSArray *sortedKeys = [self sortedBeats:beatMap];
    return ((NSNumber *)sortedKeys[0]).doubleValue;
}

- (double)getNearestHigherBeat
{
    NSDictionary *beatMap = [_loopData getBeatMap];
    NSArray *sortedKeys = [self sortedBeats:beatMap];
    double currBeat = [_conductor getCurrentBeatForLoop:[_loopData getLoopName]];
    for(int i = 0; i < beatMap.count; i ++){
        if(((NSNumber *)sortedKeys[i]).doubleValue > currBeat)
            return ((NSNumber *)sortedKeys[i]).doubleValue;
    }
    return ((NSNumber *)sortedKeys[0]).doubleValue;
}

- (double)getNextBeat:(NSDictionary *)beatMap
{
    NSArray *sortedKeys = [self sortedBeats:beatMap];
    // check if user has hit the beat yet if not, turn on filter/fire mistakes
    int indexOfNextKey = (int)[sortedKeys indexOfObject:[NSNumber numberWithDouble:_nextBeat]] + 1;
    if(indexOfNextKey >= sortedKeys.count){
        indexOfNextKey = 0;
        _resetLoopTime = CACurrentMediaTime();
        _lastBeat = _nextBeat;
        _resetLoopBeat = YES;
    }
    return ((NSNumber *)sortedKeys[indexOfNextKey]).doubleValue;
}

- (NSArray *)sortedBeats:(NSDictionary *)beatMap
{
    NSArray *sortedKeys = [[beatMap allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSNumber *num1 = obj1;
        NSNumber *num2 = obj2;
        if ( num1.doubleValue < num2.doubleValue ) {
            return (NSComparisonResult)NSOrderedAscending;
        }
        return (NSComparisonResult)NSOrderedDescending;
    }];
    return sortedKeys;
}

- (void)drawTrack:(NSNumber *)voiceNumber beatLength:(double)beatLength duration:(double)animationDuration
{
    // initialize variables
    int noteNumber = voiceNumber.intValue + 1;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGFloat initialDistance = screenHeight - _train.position.y;
    // calculate track length
    CGFloat trackSpacing = 20;
    CGFloat distancePerBeat = initialDistance/2;
    CGFloat length = distancePerBeat * beatLength - trackSpacing;
    // initialize track
    SKSpriteNode *track = [self buildTrack:length];
    CGFloat xPos = noteNumber == 1 ? _leftTrackCenter : _rightTrackCenter; // only built for two instruments
    [track setPosition:CGPointMake(xPos - track.size.width/2, screenHeight)];
    track.zPosition = -1;
    [self addChild:track];
    // move track
    [self moveTrack:track initialDistance:initialDistance duration:animationDuration];
}

- (SKSpriteNode *)buildTrack:(double)length
{
    CGFloat trackWidth = _train.size.width/_train.xScale - 10;
    SKSpriteNode *track = [SKSpriteNode spriteNodeWithColor:[UIColor clearColor] size:CGSizeMake(trackWidth, length)];
    
    //build side rails
    SKSpriteNode *leftRail = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(2, length)];
    SKSpriteNode *rightRail = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(2, length)];
    leftRail.position = CGPointMake(8, length/2);
    rightRail.position = CGPointMake(trackWidth - 8, length/2);
    [track addChild:leftRail];
    [track addChild:rightRail];
    
    //build cross hatches
    CGFloat spacing = 15;
    for(CGFloat startingPosition = 2; startingPosition < length; startingPosition += spacing){
        SKSpriteNode *railCross = [SKSpriteNode spriteNodeWithColor:[UIColor yellowColor] size:CGSizeMake(trackWidth, .7)];
        railCross.position = CGPointMake(trackWidth/2, startingPosition);
        [track addChild:railCross];
    }
    
    // return track
    track.name = @"track";
    return track;
}

- (void)moveTrack:(SKSpriteNode *)track initialDistance:(CGFloat)initialDistance duration:(double)animationDuration
{
    //  move track
    SKAction *moveTrackToTrain = [SKAction moveToY:_train.position.y  duration:animationDuration];
    CGFloat outDestination = _train.position.y - track.size.height - _train.size.height/2;
    CGFloat outDistance = _train.position.y - outDestination;
    SKAction *moveTrackOut = [SKAction moveToY:outDestination duration:animationDuration * (outDistance/initialDistance)];
    [track runAction:moveTrackToTrain completion:^(void){
        if((track.position.x >= _train.frame.origin.x - 10 && track.position.x <= _train.frame.origin.x + 10) ||
           _trainIsJumping){ // evaluate what makes this true at this point in time
            _streakCounter ++;
            if(_streakCounter == 20){
                [self flashColoredScreen:[UIColor greenColor]];
                _streakDisplay.colorBlendFactor = .8;
                _streakDisplay.color = [UIColor greenColor];
            }
        } else {
            _streakCounter = 0;
            [self flashColoredScreen:[UIColor redColor]];
        }
        [self updateStreakCounterDisplay];
        [track runAction:moveTrackOut completion:^(void){
            [self removeChildrenInArray:@[track]];
        }];
    }];
}

- (void)update:(NSTimeInterval)currentTime {
    double currTime = [_conductor getCurrentBeatForLoop:[_loopData getLoopName]];
    double preBeat = 2;
    double firingTime = currTime + preBeat;
    double animationDuration = preBeat * 60/[_loopData getBPM];
    if(firingTime > [_loopData getNumBeats]){ // now it oscilates from 0 to 16
        firingTime -= [_loopData getNumBeats];
    }
    if(firingTime > _nextBeat && (!_resetLoopBeat || (_resetLoopBeat && firingTime < .5 + [self getFirstBeat]
                                                      && (_resetLoopTime && (CACurrentMediaTime() - _resetLoopTime > [_loopData getNumBeats]-_lastBeat-preBeat))))){
        _resetLoopBeat = NO;
        NSDictionary *beatMap = [_loopData getBeatMap];
        NSArray *beatsToFire = [beatMap objectForKey:[NSNumber numberWithDouble:_nextBeat]];
        double beatAfter = [self getNextBeat:beatMap];
        for(NSNumber *voiceNumber in beatsToFire){
            float beatLength = beatAfter - _nextBeat;
            if(_resetLoopBeat)
                beatLength += [_loopData getNumBeats];
            [self drawTrack:voiceNumber beatLength:beatLength duration:animationDuration];
        }
        _nextBeat = beatAfter;// update next beat by iterating through keys
    }
}

@end