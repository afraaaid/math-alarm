#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import "Models.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const SVAlarmEngineDidChangeStateNotification;
FOUNDATION_EXPORT NSNotificationName const SVAlarmEngineWrongAnswerNotification;

FOUNDATION_EXPORT NSString *const SVAlarmCategoryID;
FOUNDATION_EXPORT NSString *const SVOpenMathActionID;
FOUNDATION_EXPORT NSString *const SVWakeUpCategoryID;
FOUNDATION_EXPORT NSString *const SVWakeUpConfirmActionID;

@interface SVAudioSirenService : NSObject

+ (instancetype)shared;

@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) NSInteger previewingSoundRaw; // -1 se nessuno
@property (nonatomic, assign, readonly) BOOL isQuietWindowActive;
@property (nonatomic, assign, readonly) NSTimeInterval quietRemainingSeconds;
@property (nonatomic, assign, readonly) NSTimeInterval quietWindowDuration;

- (void)startSirenWithSound:(SVAlarmSound)sound fadeIn:(BOOL)fadeIn;
- (void)stopSiren;
- (void)registerTypingActivityWithSmartQuiet:(BOOL)smartQuietEnabled;
- (void)togglePreviewForSound:(SVAlarmSound)sound;
- (void)stopPreview;

@end

@interface SVVolumeGuard : NSObject

+ (instancetype)shared;

- (void)startGuarding;
- (void)stopGuarding;
- (void)forceMaxSystemVolume;

@end

@interface SVAlarmEngine : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, readonly) NSArray<SVAlarmItem *> *alarms;
@property (nonatomic, strong, readonly, nullable) SVAlarmItem *activeAlarm;
@property (nonatomic, copy, readonly) NSArray<SVMathProblem *> *currentProblems;
@property (nonatomic, assign, readonly) NSInteger solvedCount;
@property (nonatomic, copy) NSString *userInput;
@property (nonatomic, assign, readonly) BOOL wrongBannerVisible;
@property (nonatomic, assign, readonly) UNAuthorizationStatus notificationStatus;
@property (nonatomic, strong, readonly, nullable) NSDate *wakeUpCheckPendingUntil;

- (BOOL)isRinging;
- (nullable SVMathProblem *)currentProblem;

- (void)requestPermissionsWithCompletion:(nullable void (^)(BOOL granted))completion;
- (void)refreshPermissionStatus;

- (void)upsertAlarm:(SVAlarmItem *)alarm;
- (void)toggleAlarmID:(NSString *)alarmID enabled:(BOOL)enabled;
- (void)deleteAlarmID:(NSString *)alarmID;

- (nullable SVAlarmItem *)nextScheduledAlarmWithDate:(NSDate * _Nullable * _Nullable)outDate;

- (void)triggerTestAlarm:(SVAlarmItem *)alarm;
- (void)activateAlarmFromSystemTriggerWithID:(nullable NSString *)alarmID;
- (void)checkIfAnyAlarmShouldBeRingingNow;

- (void)appendDigit:(NSString *)digit;
- (void)deleteLastDigit;
- (void)submitAnswer;
- (void)confirmWakeUpCheck;

- (void)handleMovedToBackgroundWhileRinging;
- (void)handleReturnedToForeground;
- (void)handleWillTerminateWhileRinging;

- (void)rescheduleAll;

@end

NS_ASSUME_NONNULL_END
