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

- (instancetype)initWithLoopData:(LoopData *)data graphics:(GraphicsController *)graphics conductor:(Conductor *)conductor size:(CGSize)size {
    self = [super initWithSize:size];
    if (self) {
        self.loopData = data;
        self.conductor = conductor;
        self.graphics = graphics;
        
        self.beatValues = [_loopData getBeatValuesForVoice:0];
        self.ready = NO;
        self.beatChecked = NO;
        self.notePlayed = NO;
        self.noteMissed = NO;
        self.reachedGoal = NO;
        self.targetScore = [_beatValues count];
        self.currentScore = 0;
    }
    
    return self;
}



- (void) didMoveToView:(SKView *)view
{
    // setup scene
    self.backgroundColor = [_graphics getBackgroundColor];
    self.scaleMode = SKSceneScaleModeAspectFit;
        
    [_conductor addObserver:self forKeyPath:@"currentBeat" options:0 context:nil];
    self.view.frameInterval = 2;
    
    // add nodes
    [self addTargets];
    [self addOrb];
    [self addInteractor];
    [self initStreakDisplay];
    [self initHighScoreDisplay];
    _ready = true;
    
    NSString *highScoreString = [NSString stringWithFormat:@"%@HighScore", [_loopData getLoopName]];
    int highScore = (int)[[NSUserDefaults standardUserDefaults] integerForKey:highScoreString];
    _highScoreDisplay.text = [NSString stringWithFormat:@"high score: %d", highScore];
}

- (void)addTargets {
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat targetRadius = 0;
    
    self.targets = [[NSMutableArray alloc] init];
    for (int i = 0; i < 4; i++) {
        SKSpriteNode *target = [SKSpriteNode spriteNodeWithImageNamed:@"orb_game_target"];
        targetRadius = target.size.width/2;
        [_targets addObject:target];
    }
    
    CGFloat spacingValue = (screenWidth - targetRadius * 4)/3;
    CGPoint position1 = CGPointMake(spacingValue + targetRadius, spacingValue*2 + targetRadius*3);
    CGPoint position2 = CGPointMake(screenWidth - position1.x, spacingValue*2 + targetRadius*3);
    CGPoint position3 = CGPointMake(spacingValue + targetRadius, spacingValue + targetRadius);
    CGPoint position4 = CGPointMake(screenWidth - position3.x, spacingValue + targetRadius);
    
    self.targetPositions = [[NSArray alloc] initWithObjects:
                            [NSValue valueWithCGPoint:position1],
                            [NSValue valueWithCGPoint:position2],
                            [NSValue valueWithCGPoint:position3],
                            [NSValue valueWithCGPoint:position4],
                            nil];
    
    for (int i = 0; i < 4; i++) {
        SKSpriteNode *target = _targets[i];
        target.position = [_targetPositions[i] CGPointValue];
        target.name = [NSString stringWithFormat:@"target%i", i];
        [self addChild:target];
    }
    
}

- (void)addOrb {
    self.orb = [SKSpriteNode spriteNodeWithImageNamed:@"orb_game_orb"];
    
    int r1 = arc4random_uniform(4);
    int r2 = arc4random_uniform(4);
    while (r2 == r1) r2 = arc4random_uniform(4);
    
    _prevPosition = [_targetPositions[r1] CGPointValue];
    _nextPosition = [_targetPositions[r2] CGPointValue];
    _prevNum = r1;
    _nextNum = r2;
    
    _orb.position = _prevPosition;
    [self addChild:_orb];
    [_orb setZPosition:-1];
}

- (void)addInteractor {
    self.interactor = [[MinigameInteractor alloc] initWithTexture:[_graphics getTextureForInteractor:[_loopData getLoopName]]];
    
    _interactor.graphics = _graphics;
    [_interactor setUpInteractor];
    
    _interactor.position = CGPointMake(self.size.width/2, self.size.height*0.75);
    _interactor.zPosition = -2;
    _interactor.name = [_loopData getLoopName];
    
    [_interactor connectToConductor:_conductor];
    
    [self addChild:_interactor];
}

-(void)initStreakDisplay
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    _streakDisplay = [SKLabelNode labelNodeWithText:[NSString stringWithFormat:@"streak: %i", _streakCounter]];
    _streakDisplay.fontSize = 16;
    _streakDisplay.fontColor = [UIColor whiteColor];
    _streakDisplay.fontName = @"Avenir-Light";
    [_streakDisplay setPosition: CGPointMake(screenWidth - 10 - _streakDisplay.frame.size.width/2, screenHeight - 40)];
    _streakDisplay.alpha = .6;
    _streakDisplay.userInteractionEnabled = NO;
    [self addChild:_streakDisplay];
}

-(void)initHighScoreDisplay
{
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    _highScoreDisplay = [SKLabelNode labelNodeWithText:[NSString stringWithFormat:@"high score: %i", _streakCounter]];
    _highScoreDisplay.fontSize = 12;
    _highScoreDisplay.fontColor = [UIColor whiteColor];
    _highScoreDisplay.fontName = @"Avenir-Light";
    [_highScoreDisplay setPosition: CGPointMake(screenWidth - 10 - _highScoreDisplay.frame.size.width/2, screenHeight - 20)];
    _highScoreDisplay.alpha = .6;
    _highScoreDisplay.userInteractionEnabled = NO;
    [self addChild:_highScoreDisplay];
}

- (void)updateStreakCounterDisplay
{
    _streakDisplay.text = [NSString stringWithFormat:@"streak: %i", _streakCounter];
    if(_streakCounter > [[_highScoreDisplay.text substringFromIndex:11] integerValue]){
        _highScoreDisplay.text = [NSString stringWithFormat:@"high score: %d", _streakCounter];
        NSString *highScoreString = [NSString stringWithFormat:@"%@HighScore", [_loopData getLoopName]];
        [[NSUserDefaults standardUserDefaults] setInteger:_streakCounter forKey:highScoreString];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:location];
    
    if ([[node.name substringToIndex:6] isEqualToString:@"target"]) {
        SKSpriteNode *target = (SKSpriteNode *)node;
//        int targetNum = [[target.name substringFromIndex:6] integerValue];
        double distance = hypot(target.position.x - _orb.position.x, target.position.y - _orb.position.y);
        if (!_noteMissed && [target intersectsNode:_orb] && distance < 20) {
            [self handleHitOnTarget:target];
            _notePlayed = true;
        } else {
            SKAction *flashOn = [SKAction colorizeWithColor:[UIColor redColor] colorBlendFactor:1.0 duration:0.1];
            SKAction *flashOff = [SKAction colorizeWithColorBlendFactor:0.0 duration:0.7];
            [target runAction:flashOn completion:^{
                [target runAction:flashOff];
            }];
        }
    } else if ([node.name isEqualToString:[_loopData getLoopName]]) {
        int timesBeaten = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"timesSeenOrbGame"];
        [[NSUserDefaults standardUserDefaults] setInteger:timesBeaten + 1 forKey:@"timesSeenOrbGame"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ReturnFromGameScene" object:self userInfo:@{@"reachedGoal":[NSNumber numberWithBool:_reachedGoal]}];
    }
}

- (void)handleHitOnTarget:(SKSpriteNode *)target {
    SKAction *flashOn = [SKAction colorizeWithColor:[UIColor greenColor] colorBlendFactor:1.0 duration:0.1];
    SKAction *flashOff = [SKAction colorizeWithColorBlendFactor:0.0 duration:0.7];
    [target runAction:flashOn completion:^{
        [target runAction:flashOff];
    }];
    
    if (!_reachedGoal) {
        _currentScore++;
        [_interactor setPercentFull:_currentScore/_targetScore];
        if (_currentScore == _targetScore) {
            _reachedGoal = YES;
        }
    }
    _streakCounter ++;
    [self updateStreakCounterDisplay];
}

- (void)handleMissOnTarget:(SKSpriteNode *)target {
    _noteMissed = true;
    SKAction *flashOn = [SKAction colorizeWithColor:[UIColor redColor] colorBlendFactor:1.0 duration:0.1];
    SKAction *flashOff = [SKAction colorizeWithColorBlendFactor:0.0 duration:0.7];
    [target runAction:flashOn completion:^{
        [target runAction:flashOff completion:^{
            _noteMissed = false;
        }];
    }];
    
    if (!_reachedGoal) {
        _currentScore -= 2;
        if (_currentScore < 0) _currentScore = 0;
        [_interactor setPercentFull:_currentScore/_targetScore];
    }
    _streakCounter = 0;
    [self updateStreakCounterDisplay];
}

- (void)displayDirections
{
    // TODO FOR HENRY - CHANGE FILENAME ON NEXT LINE TO BE APPROPRIATE
    SKSpriteNode *directions = [SKSpriteNode spriteNodeWithImageNamed:@"orb_game_directions"];
    directions.position = CGPointMake(self.frame.size.width/2, self.frame.size.height*0.58);
    directions.userInteractionEnabled = NO;
    directions.name = @"directions";
    directions.userInteractionEnabled = NO;
    [self addChild:directions];
    [self performSelector:@selector(fadeOutDirections) withObject:nil afterDelay:4];   // ADJUST DELAY TO BE APPROPRIATE
    
}

- (void)fadeOutDirections
{
    SKSpriteNode *directions = (SKSpriteNode *)[self childNodeWithName:@"directions"];
    SKAction *fadeOut = [SKAction fadeAlphaTo:0 duration:1.5];
    [directions runAction:fadeOut completion:^(void){
        [self removeChildrenInArray:@[directions]];
    }];
}

- (void)setGameValuesForBeat:(double)currentBeat {
    currentBeat = [_conductor getCurrentBeatForLoop:[_loopData getLoopName]];
    
    double prevBeat = -1;
    double nextBeat = -1;
    for (int i = 0; i < [_beatValues count]; i++) {
        if ([_beatValues[i] doubleValue] > currentBeat) {
            prevBeat = [_beatValues[i-1] doubleValue];
            nextBeat = [_beatValues[i] doubleValue];
            break;
        }
    }
    if (nextBeat == -1) {
        prevBeat = [_beatValues[[_beatValues count]-1] doubleValue];
        nextBeat = [_beatValues[0] doubleValue];
    }
    
    if (_prevBeat != prevBeat) {
        int r = arc4random_uniform(4);
        while (r == _nextNum) r = arc4random_uniform(4);
        _prevNum = _nextNum;
        _nextNum = r;
        _prevPosition = _nextPosition;
        _nextPosition = [_targetPositions[r] CGPointValue];
        _beatChecked = false;
        _noteMissed = false;
    }
    
    _prevBeat = prevBeat;
    _nextBeat = nextBeat;
    
}

- (void)update:(NSTimeInterval)currentTime {
    if (!_ready) return;
    
    double currentBeat = [_conductor getCurrentBeatForLoop:[_loopData getLoopName]];
    [self setGameValuesForBeat:currentBeat];
    
    double totalDiff = _nextBeat - _prevBeat;
    double currentDiff = _nextBeat - currentBeat;
    
    if (totalDiff < 0) {
        totalDiff = [_loopData getNumBeats] - _prevBeat;
        currentDiff = [_loopData getNumBeats] - currentBeat;
    }
    
    if (totalDiff - currentDiff > 0.15 && !_beatChecked) {
        if (!_notePlayed) {
            SKSpriteNode *missedTarget;
            for (SKSpriteNode *target in _targets) {
                if ([_orb intersectsNode:target]) {
                    missedTarget = target;
                    break;
                }
            }
            [self handleMissOnTarget:missedTarget];
        }
        _notePlayed = false;
        _beatChecked = true;
    }
    
    double ratio = currentDiff / totalDiff;
//    ratio = pow(ratio, 0.7) * ratio;
    CGPoint position = CGPointMake(_prevPosition.x*ratio + _nextPosition.x*(1-ratio), _prevPosition.y*ratio + _nextPosition.y*(1-ratio));
    
    _orb.position = position;
    
    [_interactor updateAppearance];
    double scale = [_interactor getScale];
    _orb.xScale = scale;
    _orb.yScale = scale;
}

@end
