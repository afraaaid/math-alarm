#import "AlarmEngine.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#include <math.h>

NSNotificationName const SVAlarmEngineDidChangeStateNotification = @"SVAlarmEngineDidChangeStateNotification";
NSNotificationName const SVAlarmEngineWrongAnswerNotification = @"SVAlarmEngineWrongAnswerNotification";

NSString *const SVAlarmCategoryID = @"SVEGLIA_ALARM_CATEGORY";
NSString *const SVOpenMathActionID = @"OPEN_MATH_CHALLENGE";
NSString *const SVWakeUpCategoryID = @"SVEGLIA_WAKEUP_CHECK_CATEGORY";
NSString *const SVWakeUpConfirmActionID = @"CONFIRM_AWAKE";

static void *SVVolumeObservationContext = &SVVolumeObservationContext;

#pragma mark - SVAudioSirenService

@interface SVAudioSirenService ()

@property (nonatomic, strong, nullable) AVAudioPlayer *player;
@property (nonatomic, strong, nullable) AVAudioPlayer *previewPlayer;
@property (nonatomic, strong, nullable) NSTimer *fadeTimer;
@property (nonatomic, strong, nullable) NSTimer *quietTimer;
@property (nonatomic, strong, nullable) NSDate *quietDeadline;
@property (nonatomic, assign) float currentVolumeTarget;
@property (nonatomic, assign) NSTimeInterval currentFadeElapsed;
@property (nonatomic, assign) BOOL fadeInEnabled;

@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign, readwrite) NSInteger previewingSoundRaw;
@property (nonatomic, assign, readwrite) BOOL isQuietWindowActive;
@property (nonatomic, assign, readwrite) NSTimeInterval quietRemainingSeconds;

@end

@implementation SVAudioSirenService

+ (instancetype)shared {
    static SVAudioSirenService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SVAudioSirenService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _previewingSoundRaw = -1;
        _currentVolumeTarget = 1.0f;
    }
    return self;
}

- (NSTimeInterval)quietWindowDuration {
    return 6.0;
}

- (void)startSirenWithSound:(SVAlarmSound)sound fadeIn:(BOOL)fadeIn {
    [self stopPreview];
    [self configureAudioSessionForAlarm];

    AVAudioPlayer *audioPlayer = [self makePlayerForSound:sound];
    if (!audioPlayer) {
        return;
    }

    [self.player stop];
    self.player = audioPlayer;
    self.player.numberOfLoops = -1;
    self.fadeInEnabled = fadeIn;
    self.currentFadeElapsed = 0;
    self.currentVolumeTarget = fadeIn ? 0.15f : 1.0f;
    self.player.volume = self.currentVolumeTarget;
    [self.player prepareToPlay];
    [self.player play];

    self.isPlaying = YES;
    [self resetQuietState];

    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
    if (fadeIn) {
        __weak typeof(self) weakSelf = self;
        self.fadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [weakSelf stepFadeIn];
        }];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineDidChangeStateNotification object:nil];
}

- (void)stopSiren {
    [self.fadeTimer invalidate];
    self.fadeTimer = nil;
    [self resetQuietState];

    [self.player stop];
    self.player = nil;
    self.isPlaying = NO;

    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineDidChangeStateNotification object:nil];
}

- (void)registerTypingActivityWithSmartQuiet:(BOOL)smartQuietEnabled {
    if (!self.isPlaying || !smartQuietEnabled) {
        return;
    }

    self.quietDeadline = [NSDate dateWithTimeIntervalSinceNow:self.quietWindowDuration];
    self.quietRemainingSeconds = self.quietWindowDuration;
    self.isQuietWindowActive = YES;
    self.player.volume = 0.20f;

    if (!self.quietTimer) {
        __weak typeof(self) weakSelf = self;
        self.quietTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            [weakSelf updateQuietCountdown];
        }];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineDidChangeStateNotification object:nil];
}

- (void)togglePreviewForSound:(SVAlarmSound)sound {
    if (self.previewingSoundRaw == (NSInteger)sound) {
        [self stopPreview];
        return;
    }
    [self stopPreview];
    [self configureAudioSessionForAlarm];

    AVAudioPlayer *preview = [self makePlayerForSound:sound];
    if (!preview) {
        return;
    }
    preview.numberOfLoops = -1;
    preview.volume = 0.55f;
    [preview prepareToPlay];
    [preview play];
    self.previewPlayer = preview;
    self.previewingSoundRaw = (NSInteger)sound;
    [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineDidChangeStateNotification object:nil];
}

- (void)stopPreview {
    [self.previewPlayer stop];
    self.previewPlayer = nil;
    if (self.previewingSoundRaw != -1) {
        self.previewingSoundRaw = -1;
        [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineDidChangeStateNotification object:nil];
    }
}

- (void)stepFadeIn {
    if (!self.isPlaying || !self.fadeInEnabled) {
        [self.fadeTimer invalidate];
        self.fadeTimer = nil;
        return;
    }
    self.currentFadeElapsed += 0.25;
    float progress = MIN(1.0f, (float)(self.currentFadeElapsed / 22.0));
    self.currentVolumeTarget = 0.15f + 0.85f * progress;

    if (!self.isQuietWindowActive) {
        self.player.volume = self.currentVolumeTarget;
    }
    if (progress >= 1.0f) {
        self.fadeInEnabled = NO;
        [self.fadeTimer invalidate];
        self.fadeTimer = nil;
    }
}

- (void)updateQuietCountdown {
    if (!self.isPlaying || !self.quietDeadline) {
        [self resetQuietState];
        return;
    }
    NSTimeInterval remaining = [self.quietDeadline timeIntervalSinceNow];
    if (remaining <= 0) {
        [self resetQuietState];
        self.player.volume = MAX(self.currentVolumeTarget, 1.0f);
        self.fadeInEnabled = NO;
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [haptic impactOccurred];
    } else {
        self.quietRemainingSeconds = remaining;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineDidChangeStateNotification object:nil];
}

- (void)resetQuietState {
    [self.quietTimer invalidate];
    self.quietTimer = nil;
    self.quietDeadline = nil;
    self.quietRemainingSeconds = 0;
    self.isQuietWindowActive = NO;
}

- (void)configureAudioSessionForAlarm {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeDefault options:0 error:nil];
    [session setActive:YES error:nil];
}

- (nullable AVAudioPlayer *)makePlayerForSound:(SVAlarmSound)sound {
    NSString *base = SVAlarmSoundBaseName(sound);
    NSURL *url = [[NSBundle mainBundle] URLForResource:base withExtension:@"wav"];
    if (!url) {
        url = [[NSBundle mainBundle] URLForResource:base withExtension:@"wav" subdirectory:@"Sounds"];
    }
    if (url) {
        AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
        if (audioPlayer) {
            return audioPlayer;
        }
    }
    NSData *fallbackData = [self synthesizeEmergencyBeepWAV];
    return [[AVAudioPlayer alloc] initWithData:fallbackData error:nil];
}

- (NSData *)synthesizeEmergencyBeepWAV {
    int32_t sampleRate = 22050;
    int sampleCount = sampleRate * 2;
    uint32_t dataSize = (uint32_t)(sampleCount * 2);
    NSMutableData *pcm = [NSMutableData dataWithCapacity:44 + dataSize];

    uint32_t chunkSize = CFSwapInt32HostToLittle(36 + dataSize);
    uint32_t fmtSize = CFSwapInt32HostToLittle(16);
    uint16_t audioFmt = CFSwapInt16HostToLittle(1);
    uint16_t channels = CFSwapInt16HostToLittle(1);
    uint32_t rateLE = CFSwapInt32HostToLittle((uint32_t)sampleRate);
    uint32_t byteRateLE = CFSwapInt32HostToLittle((uint32_t)(sampleRate * 2));
    uint16_t blockAlignLE = CFSwapInt16HostToLittle(2);
    uint16_t bitsLE = CFSwapInt16HostToLittle(16);
    uint32_t dataSizeLE = CFSwapInt32HostToLittle(dataSize);

    [pcm appendBytes:"RIFF" length:4];
    [pcm appendBytes:&chunkSize length:4];
    [pcm appendBytes:"WAVEfmt " length:8];
    [pcm appendBytes:&fmtSize length:4];
    [pcm appendBytes:&audioFmt length:2];
    [pcm appendBytes:&channels length:2];
    [pcm appendBytes:&rateLE length:4];
    [pcm appendBytes:&byteRateLE length:4];
    [pcm appendBytes:&blockAlignLE length:2];
    [pcm appendBytes:&bitsLE length:2];
    [pcm appendBytes:"data" length:4];
    [pcm appendBytes:&dataSizeLE length:4];

    for (int i = 0; i < sampleCount; i++) {
        double t = (double)i / (double)sampleRate;
        double cycle = fmod(t, 0.5);
        double amp = (cycle < 0.28) ? 26000.0 : 0.0;
        double freq = (cycle < 0.14) ? 1480.0 : 1975.0;
        int16_t sample = CFSwapInt16HostToLittle((int16_t)(amp * sin(2.0 * M_PI * freq * t)));
        [pcm appendBytes:&sample length:2];
    }
    return pcm;
}

@end

#pragma mark - SVVolumeGuard

@interface SVVolumeGuard ()

@property (nonatomic, strong, nullable) MPVolumeView *volumeView;
@property (nonatomic, strong, nullable) NSTimer *reinforceTimer;
@property (nonatomic, assign) BOOL isGuarding;
@property (nonatomic, assign) BOOL isObserving;

@end

@implementation SVVolumeGuard

+ (instancetype)shared {
    static SVVolumeGuard *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SVVolumeGuard alloc] init];
    });
    return instance;
}

- (void)dealloc {
    [self stopGuarding];
}

- (void)startGuarding {
    if (self.isGuarding) {
        [self forceMaxSystemVolume];
        return;
    }
    self.isGuarding = YES;
    [self attachHiddenVolumeViewIfNeeded];
    [self forceMaxSystemVolume];

    if (!self.isObserving) {
        @try {
            [[AVAudioSession sharedInstance] addObserver:self
                                              forKeyPath:@"outputVolume"
                                                 options:NSKeyValueObservingOptionNew
                                                 context:SVVolumeObservationContext];
            self.isObserving = YES;
        } @catch (NSException *exception) {
            self.isObserving = NO;
        }
    }

    [self.reinforceTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.reinforceTimer = [NSTimer scheduledTimerWithTimeInterval:0.4 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (!weakSelf.isGuarding) {
            return;
        }
        if ([AVAudioSession sharedInstance].outputVolume < 0.94f) {
            [weakSelf forceMaxSystemVolume];
        }
    }];
}

- (void)stopGuarding {
    self.isGuarding = NO;
    [self.reinforceTimer invalidate];
    self.reinforceTimer = nil;

    if (self.isObserving) {
        @try {
            [[AVAudioSession sharedInstance] removeObserver:self
                                                 forKeyPath:@"outputVolume"
                                                    context:SVVolumeObservationContext];
        } @catch (NSException *exception) {
        }
        self.isObserving = NO;
    }
    [self.volumeView removeFromSuperview];
    self.volumeView = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (context == SVVolumeObservationContext) {
        float newVol = [AVAudioSession sharedInstance].outputVolume;
        if (newVol < 0.92f) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakSelf.isGuarding) {
                    [weakSelf forceMaxSystemVolume];
                }
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)forceMaxSystemVolume {
    [self attachHiddenVolumeViewIfNeeded];
    UISlider *slider = nil;
    for (UIView *sub in self.volumeView.subviews) {
        if ([sub isKindOfClass:[UISlider class]]) {
            slider = (UISlider *)sub;
            break;
        }
    }
    if (!slider) {
        return;
    }
    if (slider.value < 0.98f) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [slider setValue:1.0f animated:NO];
            [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
    }
}

- (void)attachHiddenVolumeViewIfNeeded {
    if (self.volumeView.superview != nil) {
        return;
    }
    if (!self.volumeView) {
        MPVolumeView *view = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 1, 1)];
        view.alpha = 0.001f;
        view.userInteractionEnabled = NO;
        self.volumeView = view;
    }
    UIWindow *window = [self activeKeyWindow];
    if (window) {
        [window addSubview:self.volumeView];
    }
}

- (nullable UIWindow *)activeKeyWindow {
    UIWindow *fallback = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) {
                    return w;
                }
                if (!fallback) {
                    fallback = w;
                }
            }
        }
    }
    return fallback;
}

@end

#pragma mark - SVAlarmEngine

static NSString *const SVAlarmsKey = @"sveglia.alarms.v1";
static NSString *const SVActiveAlarmIDKey = @"sveglia.activeAlarmID.v1";
static NSString *const SVSolvedCountKey = @"sveglia.solvedCount.v1";
static NSString *const SVCompletedSlotsKey = @"sveglia.completedSlots.v1";
static NSString *const SVWakeUpAlarmIDKey = @"sveglia.wakeUpAlarmID.v1";
static NSString *const SVWakeUpDeadlineKey = @"sveglia.wakeUpDeadline.v1";

@interface SVAlarmEngine ()

@property (nonatomic, strong) NSMutableArray<SVAlarmItem *> *mutableAlarms;
@property (nonatomic, strong, readwrite, nullable) SVAlarmItem *activeAlarm;
@property (nonatomic, copy, readwrite) NSArray<SVMathProblem *> *currentProblems;
@property (nonatomic, assign, readwrite) NSInteger solvedCount;
@property (nonatomic, assign, readwrite) BOOL wrongBannerVisible;
@property (nonatomic, assign, readwrite) UNAuthorizationStatus notificationStatus;
@property (nonatomic, strong, readwrite, nullable) NSDate *wakeUpCheckPendingUntil;

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *completedSlotTimestamps;
@property (nonatomic, strong, nullable) NSTimer *foregroundCheckTimer;

@end

@implementation SVAlarmEngine

+ (instancetype)shared {
    static SVAlarmEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SVAlarmEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableAlarms = [NSMutableArray array];
        _currentProblems = @[];
        _userInput = @"";
        _completedSlotTimestamps = [NSMutableDictionary dictionary];
        _notificationStatus = UNAuthorizationStatusNotDetermined;

        [self loadState];
        [self registerNotificationCategories];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf refreshPermissionStatus];
            [weakSelf restoreActiveRingingIfNeeded];
            [weakSelf startForegroundMonitor];
        });
    }
    return self;
}

- (NSArray<SVAlarmItem *> *)alarms {
    return [self.mutableAlarms copy];
}

- (BOOL)isRinging {
    return self.activeAlarm != nil;
}

- (nullable SVMathProblem *)currentProblem {
    if (self.solvedCount >= 0 && self.solvedCount < (NSInteger)self.currentProblems.count) {
        return self.currentProblems[(NSUInteger)self.solvedCount];
    }
    return nil;
}

#pragma mark - Permissions

- (void)requestPermissionsWithCompletion:(nullable void (^)(BOOL))completion {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions opts = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    __weak typeof(self) weakSelf = self;
    [center requestAuthorizationWithOptions:opts completionHandler:^(BOOL granted, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf refreshPermissionStatus];
            [weakSelf rescheduleAll];
            if (completion) {
                completion(granted);
            }
        });
    }];
}

- (void)refreshPermissionStatus {
    __weak typeof(self) weakSelf = self;
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        UNAuthorizationStatus status = settings.authorizationStatus;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.notificationStatus = status;
            [weakSelf notifyStateChanged];
        });
    }];
}

#pragma mark - CRUD

- (void)upsertAlarm:(SVAlarmItem *)alarm {
    NSUInteger idx = [self.mutableAlarms indexOfObjectPassingTest:^BOOL(SVAlarmItem *obj, NSUInteger i, BOOL *stop) {
        return [obj.alarmID isEqualToString:alarm.alarmID];
    }];
    SVAlarmItem *copy = [alarm copy];
    if (idx != NSNotFound) {
        self.mutableAlarms[idx] = copy;
    } else {
        [self.mutableAlarms addObject:copy];
    }
    [self sortAlarms];
    [self saveAlarms];
    [self rescheduleAll];
    [self notifyStateChanged];
}

- (void)toggleAlarmID:(NSString *)alarmID enabled:(BOOL)enabled {
    for (SVAlarmItem *item in self.mutableAlarms) {
        if ([item.alarmID isEqualToString:alarmID]) {
            item.enabled = enabled;
            break;
        }
    }
    [self saveAlarms];
    [self rescheduleAll];
    [self notifyStateChanged];
}

- (void)deleteAlarmID:(NSString *)alarmID {
    NSMutableIndexSet *toRemove = [NSMutableIndexSet indexSet];
    [self.mutableAlarms enumerateObjectsUsingBlock:^(SVAlarmItem *obj, NSUInteger idx, BOOL *stop) {
        if ([obj.alarmID isEqualToString:alarmID]) {
            [toRemove addIndex:idx];
        }
    }];
    [self.mutableAlarms removeObjectsAtIndexes:toRemove];
    [self saveAlarms];
    [self rescheduleAll];
    [self notifyStateChanged];
}

- (nullable SVAlarmItem *)nextScheduledAlarmWithDate:(NSDate * _Nullable * _Nullable)outDate {
    NSDate *now = [NSDate date];
    SVAlarmItem *bestAlarm = nil;
    NSDate *bestDate = nil;

    for (SVAlarmItem *alarm in self.mutableAlarms) {
        if (!alarm.enabled) {
            continue;
        }
        NSDate *candidate = [alarm nextTriggerDateFromDate:now];
        if (!candidate) {
            continue;
        }
        if (!bestDate || [candidate compare:bestDate] == NSOrderedAscending) {
            bestDate = candidate;
            bestAlarm = alarm;
        }
    }
    if (outDate) {
        *outDate = bestDate;
    }
    return bestAlarm;
}

#pragma mark - Ringing & Challenge

- (void)triggerTestAlarm:(SVAlarmItem *)alarm {
    [self startRingingWithAlarm:alarm persistAsActive:YES];
}

- (void)activateAlarmFromSystemTriggerWithID:(nullable NSString *)alarmID {
    if (self.activeAlarm && alarmID && [self.activeAlarm.alarmID isEqualToString:alarmID]) {
        [self ensureSirenAndGuardActiveForAlarm:self.activeAlarm];
        return;
    }
    SVAlarmItem *found = nil;
    if (alarmID.length > 0) {
        for (SVAlarmItem *item in self.mutableAlarms) {
            if ([item.alarmID isEqualToString:alarmID]) {
                found = item;
                break;
            }
        }
    }
    if (!found) {
        for (SVAlarmItem *item in self.mutableAlarms) {
            if (item.enabled) {
                found = item;
                break;
            }
        }
    }
    if (!found) {
        found = self.mutableAlarms.firstObject;
    }
    if (found) {
        [self startRingingWithAlarm:found persistAsActive:YES];
    }
}

- (void)checkIfAnyAlarmShouldBeRingingNow {
    if (self.isRinging) {
        [self ensureSirenAndGuardActiveForAlarm:self.activeAlarm];
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *pendingWakeAlarmID = [defaults stringForKey:SVWakeUpAlarmIDKey];
    NSTimeInterval wakeDeadline = [defaults doubleForKey:SVWakeUpDeadlineKey];
    if (pendingWakeAlarmID.length > 0 && wakeDeadline > 0 && [[NSDate date] timeIntervalSince1970] >= wakeDeadline) {
        [self clearWakeUpCheck];
        [self activateAlarmFromSystemTriggerWithID:pendingWakeAlarmID];
        return;
    }

    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    for (SVAlarmItem *alarm in self.mutableAlarms) {
        if (!alarm.enabled) {
            continue;
        }
        for (NSInteger minutesAgo = 0; minutesAgo <= 15; minutesAgo++) {
            NSDate *checkDate = [calendar dateByAddingUnit:NSCalendarUnitMinute value:-minutesAgo toDate:now options:0];
            if (!checkDate) {
                continue;
            }
            NSInteger h = [calendar component:NSCalendarUnitHour fromDate:checkDate];
            NSInteger m = [calendar component:NSCalendarUnitMinute fromDate:checkDate];
            if (h != alarm.hour || m != alarm.minute) {
                continue;
            }
            if (alarm.repeatDays.count > 0) {
                NSInteger calWeekday = [calendar component:NSCalendarUnitWeekday fromDate:checkDate];
                NSInteger iso = [SVAlarmItem isoWeekdayFromCalendarWeekday:calWeekday];
                if (![alarm.repeatDays containsObject:@(iso)]) {
                    continue;
                }
            }
            NSString *slotKey = [self makeSlotKeyForAlarmID:alarm.alarmID date:checkDate];
            if (self.completedSlotTimestamps[slotKey] == nil) {
                [self startRingingWithAlarm:alarm persistAsActive:YES];
                return;
            }
        }
    }
}

- (void)appendDigit:(NSString *)digit {
    if (!self.isRinging || !self.activeAlarm) {
        return;
    }
    if (self.userInput.length >= 6) {
        return;
    }
    self.userInput = [self.userInput stringByAppendingString:digit];
    self.wrongBannerVisible = NO;

    UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [haptic impactOccurred];

    [[SVAudioSirenService shared] registerTypingActivityWithSmartQuiet:self.activeAlarm.smartQuietWhileTyping];
    [self notifyStateChanged];
}

- (void)deleteLastDigit {
    if (!self.isRinging || !self.activeAlarm) {
        return;
    }
    if (self.userInput.length > 0) {
        self.userInput = [self.userInput substringToIndex:self.userInput.length - 1];
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
        [haptic impactOccurred];
    }
    [[SVAudioSirenService shared] registerTypingActivityWithSmartQuiet:self.activeAlarm.smartQuietWhileTyping];
    [self notifyStateChanged];
}

- (void)submitAnswer {
    SVMathProblem *problem = self.currentProblem;
    if (!self.isRinging || !problem || !self.activeAlarm) {
        return;
    }

    [[SVAudioSirenService shared] registerTypingActivityWithSmartQuiet:self.activeAlarm.smartQuietWhileTyping];

    NSString *trimmed = [self.userInput stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL validDigits = trimmed.length > 0;
    NSInteger typedValue = validDigits ? [trimmed integerValue] : NSIntegerMin;

    if (!validDigits || typedValue != problem.answer) {
        self.wrongBannerVisible = YES;
        self.userInput = @"";
        UINotificationFeedbackGenerator *notif = [[UINotificationFeedbackGenerator alloc] init];
        [notif notificationOccurred:UINotificationFeedbackTypeError];
        [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineWrongAnswerNotification object:nil];
        [self notifyStateChanged];
        return;
    }

    UINotificationFeedbackGenerator *notif = [[UINotificationFeedbackGenerator alloc] init];
    [notif notificationOccurred:UINotificationFeedbackTypeSuccess];
    self.wrongBannerVisible = NO;
    self.userInput = @"";
    self.solvedCount += 1;
    [[NSUserDefaults standardUserDefaults] setInteger:self.solvedCount forKey:SVSolvedCountKey];

    if (self.solvedCount >= (NSInteger)self.currentProblems.count) {
        [self completeMathChallenge];
    } else {
        [self notifyStateChanged];
    }
}

- (void)confirmWakeUpCheck {
    [self clearWakeUpCheck];
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center removePendingNotificationRequestsWithIdentifiers:@[@"wakeup_check_prompt", @"wakeup_check_failsafe"]];
    [center removeDeliveredNotificationsWithIdentifiers:@[@"wakeup_check_prompt", @"wakeup_check_failsafe"]];

    UINotificationFeedbackGenerator *notif = [[UINotificationFeedbackGenerator alloc] init];
    [notif notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self notifyStateChanged];
}

#pragma mark - Anti-Close / Background

- (void)handleMovedToBackgroundWhileRinging {
    if (!self.activeAlarm) {
        return;
    }
    if (self.activeAlarm.lockVolume) {
        [[SVVolumeGuard shared] startGuarding];
    }
    [self scheduleImmediateExitNudgeForAlarm:self.activeAlarm];
}

- (void)handleReturnedToForeground {
    [self refreshPermissionStatus];
    if (self.activeAlarm) {
        [self ensureSirenAndGuardActiveForAlarm:self.activeAlarm];
    } else {
        [self checkIfAnyAlarmShouldBeRingingNow];
    }
}

- (void)handleWillTerminateWhileRinging {
    if (!self.activeAlarm) {
        return;
    }
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    for (NSInteger idx = 0; idx < 8; idx++) {
        UNMutableNotificationContent *content = [self makeAlarmContentForAlarm:self.activeAlarm
                                                                        title:@"SVEGLIA NON SPENTA!"
                                                                         body:@"Hai chiuso l'app prima di risolvere i calcoli. Riapri per spegnere la sirena."];
        NSTimeInterval delay = (NSTimeInterval)(3 + idx * 29);
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:delay repeats:NO];
        NSString *identifier = [NSString stringWithFormat:@"emergency_kill_%ld_%@", (long)idx, [[NSUUID UUID] UUIDString]];
        UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
        [center addNotificationRequest:req withCompletionHandler:nil];
    }
}

#pragma mark - Private Ringing Lifecycle

- (void)startRingingWithAlarm:(SVAlarmItem *)alarm persistAsActive:(BOOL)persistAsActive {
    self.activeAlarm = [alarm copy];
    self.currentProblems = [SVMathGenerator generateBatchWithDifficulty:alarm.difficulty count:alarm.problemCount];
    self.solvedCount = 0;
    self.userInput = @"";
    self.wrongBannerVisible = NO;

    if (persistAsActive) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:alarm.alarmID forKey:SVActiveAlarmIDKey];
        [defaults setInteger:0 forKey:SVSolvedCountKey];
    }

    [self ensureSirenAndGuardActiveForAlarm:self.activeAlarm];
    [self notifyStateChanged];
}

- (void)ensureSirenAndGuardActiveForAlarm:(SVAlarmItem *)alarm {
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    if (![SVAudioSirenService shared].isPlaying) {
        [[SVAudioSirenService shared] startSirenWithSound:alarm.sound fadeIn:alarm.fadeIn];
    }
    if (alarm.lockVolume) {
        [[SVVolumeGuard shared] startGuarding];
    }
}

- (void)completeMathChallenge {
    SVAlarmItem *finished = self.activeAlarm;
    [[SVAudioSirenService shared] stopSiren];
    [[SVVolumeGuard shared] stopGuarding];
    [UIApplication sharedApplication].idleTimerDisabled = NO;

    if (finished) {
        NSString *slotKey = [self makeSlotKeyForAlarmID:finished.alarmID date:[NSDate date]];
        self.completedSlotTimestamps[slotKey] = @([[NSDate date] timeIntervalSince1970]);
        [self pruneOldCompletedSlots];
        [self saveCompletedSlots];

        if (finished.repeatDays.count == 0) {
            for (SVAlarmItem *item in self.mutableAlarms) {
                if ([item.alarmID isEqualToString:finished.alarmID]) {
                    item.enabled = NO;
                    break;
                }
            }
            [self saveAlarms];
        }

        if (finished.wakeUpCheckEnabled) {
            [self scheduleWakeUpCheckForAlarm:finished];
        }
    }

    self.activeAlarm = nil;
    self.currentProblems = @[];
    self.solvedCount = 0;
    self.userInput = @"";
    self.wrongBannerVisible = NO;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:SVActiveAlarmIDKey];
    [defaults removeObjectForKey:SVSolvedCountKey];

    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
    [self rescheduleAll];
    [self notifyStateChanged];
}

- (void)restoreActiveRingingIfNeeded {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedID = [defaults stringForKey:SVActiveAlarmIDKey];
    if (savedID.length == 0) {
        [self checkIfAnyAlarmShouldBeRingingNow];
        return;
    }

    SVAlarmItem *targetAlarm = nil;
    for (SVAlarmItem *item in self.mutableAlarms) {
        if ([item.alarmID isEqualToString:savedID]) {
            targetAlarm = item;
            break;
        }
    }
    if (!targetAlarm) {
        targetAlarm = [[SVAlarmItem alloc] initWithDefaultValues];
        targetAlarm.alarmID = savedID;
        targetAlarm.label = @"Sveglia Attiva";
    }

    NSInteger savedSolved = [defaults integerForKey:SVSolvedCountKey];
    NSInteger remainingCount = MAX(1, targetAlarm.problemCount - savedSolved);

    self.activeAlarm = [targetAlarm copy];
    self.currentProblems = [SVMathGenerator generateBatchWithDifficulty:targetAlarm.difficulty count:remainingCount];
    self.solvedCount = 0;
    self.userInput = @"";
    [self ensureSirenAndGuardActiveForAlarm:self.activeAlarm];
    [self notifyStateChanged];
}

#pragma mark - Hydra Scheduling

- (void)rescheduleAll {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    __weak typeof(self) weakSelf = self;
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        NSMutableArray<NSString *> *toRemove = [NSMutableArray array];
        for (UNNotificationRequest *req in requests) {
            if (![req.identifier isEqualToString:@"wakeup_check_prompt"] &&
                ![req.identifier isEqualToString:@"wakeup_check_failsafe"]) {
                [toRemove addObject:req.identifier];
            }
        }
        [center removePendingNotificationRequestsWithIdentifiers:toRemove];

        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf scheduleHydraNotificationsOnCenter:center];
        });
    }];
}

- (void)scheduleHydraNotificationsOnCenter:(UNUserNotificationCenter *)center {
    NSMutableArray<SVAlarmItem *> *enabledAlarms = [NSMutableArray array];
    for (SVAlarmItem *item in self.mutableAlarms) {
        if (item.enabled) {
            [enabledAlarms addObject:item];
        }
    }
    if (enabledAlarms.count == 0) {
        return;
    }

    NSDate *nearestDate = nil;
    SVAlarmItem *nearestAlarm = [self nextScheduledAlarmWithDate:&nearestDate];
    NSDate *now = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSCalendarUnit dateUnits = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                               NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;

    NSInteger secondaryCount = 0;
    for (SVAlarmItem *alarm in enabledAlarms) {
        if (nearestAlarm && [alarm.alarmID isEqualToString:nearestAlarm.alarmID]) {
            continue;
        }
        NSDate *fireDate = [alarm nextTriggerDateFromDate:now];
        if (!fireDate) {
            continue;
        }
        NSString *body = [NSString stringWithFormat:@"Tocca per risolvere %ld calcoli (%@).",
                          (long)alarm.problemCount, SVMathDifficultyTitle(alarm.difficulty)];
        UNMutableNotificationContent *content = [self makeAlarmContentForAlarm:alarm
                                                                        title:[NSString stringWithFormat:@"⏰ %@", alarm.label]
                                                                         body:body];
        NSDateComponents *comps = [calendar components:dateUnits fromDate:fireDate];
        UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:comps repeats:NO];
        NSString *reqID = [NSString stringWithFormat:@"alarm_secondary_%@", alarm.alarmID];
        UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:reqID content:content trigger:trigger];
        [center addNotificationRequest:req withCompletionHandler:nil];
        secondaryCount++;
    }

    if (!nearestAlarm || !nearestDate) {
        return;
    }

    NSInteger hydraSlots = MAX(1, MIN(48, 56 - secondaryCount));
    for (NSInteger index = 0; index < hydraSlots; index++) {
        NSDate *fireDate = [nearestDate dateByAddingTimeInterval:(NSTimeInterval)(index * 29)];
        NSString *title = (index == 0)
            ? [NSString stringWithFormat:@"⏰ %@ (%@)", nearestAlarm.label, nearestAlarm.formattedTime]
            : [NSString stringWithFormat:@"🔥 SVEGLIA ATTIVA • Tentativo #%ld", (long)(index + 1)];
        NSString *body = [NSString stringWithFormat:@"Risolvi %ld calcoli (%@) per disattivare la sirena.",
                          (long)nearestAlarm.problemCount, SVMathDifficultyTitle(nearestAlarm.difficulty)];

        UNMutableNotificationContent *content = [self makeAlarmContentForAlarm:nearestAlarm title:title body:body];
        NSDateComponents *comps = [calendar components:dateUnits fromDate:fireDate];
        UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:comps repeats:NO];
        NSString *reqID = [NSString stringWithFormat:@"hydra_%@_%ld", nearestAlarm.alarmID, (long)index];
        UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:reqID content:content trigger:trigger];
        [center addNotificationRequest:req withCompletionHandler:nil];
    }
}

- (void)scheduleImmediateExitNudgeForAlarm:(SVAlarmItem *)alarm {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    NSArray<NSNumber *> *delays = @[@2.0, @7.0, @14.0];
    [delays enumerateObjectsUsingBlock:^(NSNumber *obj, NSUInteger idx, BOOL *stop) {
        UNMutableNotificationContent *content = [self makeAlarmContentForAlarm:alarm
                                                                        title:@"⚠️ SVEGLIA IN CORSO"
                                                                         body:@"Torna dentro Sveglia e risolvi i calcoli rimanenti!"];
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:obj.doubleValue repeats:NO];
        NSString *reqID = [NSString stringWithFormat:@"exit_nudge_%lu", (unsigned long)idx];
        UNNotificationRequest *req = [UNNotificationRequest requestWithIdentifier:reqID content:content trigger:trigger];
        [center addNotificationRequest:req withCompletionHandler:nil];
    }];
}

- (void)scheduleWakeUpCheckForAlarm:(SVAlarmItem *)alarm {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    NSTimeInterval promptDelay = 5.0 * 60.0;
    NSTimeInterval failSafeDelay = 6.0 * 60.0;

    UNMutableNotificationContent *promptContent = [[UNMutableNotificationContent alloc] init];
    promptContent.title = @"👀 Controllo Sveglio";
    promptContent.body = @"Conferma entro 1 minuto che non ti sei riaddormentato, oppure la sveglia ripartirà!";
    promptContent.sound = [UNNotificationSound soundNamed:SVAlarmSoundFileName(alarm.sound)];
    promptContent.categoryIdentifier = SVWakeUpCategoryID;
    promptContent.userInfo = @{@"alarmID": alarm.alarmID, @"kind": @"wakeup_prompt"};
#ifdef __IPHONE_15_0
    if (@available(iOS 15.0, *)) {
        promptContent.interruptionLevel = UNNotificationInterruptionLevelTimeSensitive;
    }
#endif

    UNNotificationRequest *promptReq = [UNNotificationRequest requestWithIdentifier:@"wakeup_check_prompt"
                                                                            content:promptContent
                                                                            trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:promptDelay repeats:NO]];

    UNMutableNotificationContent *failsafeContent = [self makeAlarmContentForAlarm:alarm
                                                                             title:@"🚨 CONTROLLO FALLITO • SVEGLIA RIATTIVATA!"
                                                                              body:@"Non hai confermato in tempo. Risolvi nuovi calcoli per spegnere!"];
    UNNotificationRequest *failsafeReq = [UNNotificationRequest requestWithIdentifier:@"wakeup_check_failsafe"
                                                                              content:failsafeContent
                                                                              trigger:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:failSafeDelay repeats:NO]];

    [center addNotificationRequest:promptReq withCompletionHandler:nil];
    [center addNotificationRequest:failsafeReq withCompletionHandler:nil];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:failSafeDelay];
    self.wakeUpCheckPendingUntil = deadline;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:alarm.alarmID forKey:SVWakeUpAlarmIDKey];
    [defaults setDouble:[deadline timeIntervalSince1970] forKey:SVWakeUpDeadlineKey];
}

- (void)clearWakeUpCheck {
    self.wakeUpCheckPendingUntil = nil;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:SVWakeUpAlarmIDKey];
    [defaults removeObjectForKey:SVWakeUpDeadlineKey];
}

- (UNMutableNotificationContent *)makeAlarmContentForAlarm:(SVAlarmItem *)alarm
                                                     title:(NSString *)title
                                                      body:(NSString *)body {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = body;
    content.sound = [UNNotificationSound soundNamed:SVAlarmSoundFileName(alarm.sound)];
    content.categoryIdentifier = SVAlarmCategoryID;
    content.userInfo = @{@"alarmID": alarm.alarmID ?: @""};
#ifdef __IPHONE_15_0
    if (@available(iOS 15.0, *)) {
        content.interruptionLevel = UNNotificationInterruptionLevelTimeSensitive;
    }
#endif
    return content;
}

- (void)registerNotificationCategories {
    UNNotificationAction *solveAction = [UNNotificationAction actionWithIdentifier:SVOpenMathActionID
                                                                             title:@"Risolvi Calcolo"
                                                                           options:UNNotificationActionOptionForeground];
    UNNotificationCategory *alarmCategory = [UNNotificationCategory categoryWithIdentifier:SVAlarmCategoryID
                                                                                   actions:@[solveAction]
                                                                         intentIdentifiers:@[]
                                                                                   options:UNNotificationCategoryOptionCustomDismissAction];

    UNNotificationAction *confirmAction = [UNNotificationAction actionWithIdentifier:SVWakeUpConfirmActionID
                                                                               title:@"Sono Sveglio!"
                                                                             options:UNNotificationActionOptionForeground];
    UNNotificationCategory *wakeUpCategory = [UNNotificationCategory categoryWithIdentifier:SVWakeUpCategoryID
                                                                                    actions:@[confirmAction]
                                                                          intentIdentifiers:@[]
                                                                                    options:UNNotificationCategoryOptionNone];

    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithArray:@[alarmCategory, wakeUpCategory]]];
}

#pragma mark - Foreground Monitor

- (void)startForegroundMonitor {
    [self.foregroundCheckTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.foregroundCheckTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf checkForegroundSecondTick];
    }];
}

- (void)checkForegroundSecondTick {
    if (self.isRinging) {
        return;
    }
    if (self.wakeUpCheckPendingUntil && [[NSDate date] compare:self.wakeUpCheckPendingUntil] != NSOrderedAscending) {
        [self checkIfAnyAlarmShouldBeRingingNow];
        return;
    }

    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger h = [cal component:NSCalendarUnitHour fromDate:now];
    NSInteger m = [cal component:NSCalendarUnitMinute fromDate:now];
    NSInteger s = [cal component:NSCalendarUnitSecond fromDate:now];
    if (s > 2) {
        return;
    }

    NSInteger isoWeekday = [SVAlarmItem isoWeekdayFromCalendarWeekday:[cal component:NSCalendarUnitWeekday fromDate:now]];
    for (SVAlarmItem *alarm in self.mutableAlarms) {
        if (!alarm.enabled || alarm.hour != h || alarm.minute != m) {
            continue;
        }
        if (alarm.repeatDays.count > 0 && ![alarm.repeatDays containsObject:@(isoWeekday)]) {
            continue;
        }
        NSString *key = [self makeSlotKeyForAlarmID:alarm.alarmID date:now];
        if (self.completedSlotTimestamps[key] == nil) {
            [self startRingingWithAlarm:alarm persistAsActive:YES];
            return;
        }
    }
}

#pragma mark - Persistence & Helpers

- (void)loadState {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *savedArray = [defaults arrayForKey:SVAlarmsKey];
    if ([savedArray isKindOfClass:[NSArray class]] && savedArray.count > 0) {
        for (id obj in savedArray) {
            SVAlarmItem *item = [[SVAlarmItem alloc] initWithDictionary:obj];
            if (item) {
                [self.mutableAlarms addObject:item];
            }
        }
    }
    if (self.mutableAlarms.count == 0 && !savedArray) {
        [self.mutableAlarms addObjectsFromArray:[SVAlarmItem defaultSamples]];
        [self saveAlarms];
    }
    [self sortAlarms];

    NSDictionary *savedSlots = [defaults dictionaryForKey:SVCompletedSlotsKey];
    if ([savedSlots isKindOfClass:[NSDictionary class]]) {
        [self.completedSlotTimestamps addEntriesFromDictionary:savedSlots];
        [self pruneOldCompletedSlots];
    }

    NSTimeInterval wakeDeadline = [defaults doubleForKey:SVWakeUpDeadlineKey];
    if (wakeDeadline > [[NSDate date] timeIntervalSince1970]) {
        self.wakeUpCheckPendingUntil = [NSDate dateWithTimeIntervalSince1970:wakeDeadline];
    }
}

- (void)saveAlarms {
    NSMutableArray<NSDictionary *> *arr = [NSMutableArray arrayWithCapacity:self.mutableAlarms.count];
    for (SVAlarmItem *item in self.mutableAlarms) {
        [arr addObject:[item toDictionary]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:SVAlarmsKey];
}

- (void)sortAlarms {
    [self.mutableAlarms sortUsingComparator:^NSComparisonResult(SVAlarmItem *a, SVAlarmItem *b) {
        NSInteger ta = a.hour * 60 + a.minute;
        NSInteger tb = b.hour * 60 + b.minute;
        if (ta < tb) return NSOrderedAscending;
        if (ta > tb) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

- (NSString *)makeSlotKeyForAlarmID:(NSString *)alarmID date:(NSDate *)date {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger y = [cal component:NSCalendarUnitYear fromDate:date];
    NSInteger m = [cal component:NSCalendarUnitMonth fromDate:date];
    NSInteger d = [cal component:NSCalendarUnitDay fromDate:date];
    NSInteger h = [cal component:NSCalendarUnitHour fromDate:date];
    NSInteger min = [cal component:NSCalendarUnitMinute fromDate:date];
    return [NSString stringWithFormat:@"%@_%ld-%ld-%ld_%ld:%ld", alarmID, (long)y, (long)m, (long)d, (long)h, (long)min];
}

- (void)pruneOldCompletedSlots {
    NSTimeInterval cutoff = [[NSDate date] timeIntervalSince1970] - 3600.0;
    NSArray<NSString *> *keys = [self.completedSlotTimestamps allKeys];
    for (NSString *key in keys) {
        if ([self.completedSlotTimestamps[key] doubleValue] < cutoff) {
            [self.completedSlotTimestamps removeObjectForKey:key];
        }
    }
}

- (void)saveCompletedSlots {
    [[NSUserDefaults standardUserDefaults] setObject:[self.completedSlotTimestamps copy] forKey:SVCompletedSlotsKey];
}

- (void)notifyStateChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:SVAlarmEngineDidChangeStateNotification object:nil];
}

@end
