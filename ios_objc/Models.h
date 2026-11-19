#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SVMathDifficulty) {
    SVMathDifficultyEasy = 0,
    SVMathDifficultyMedium = 1,
    SVMathDifficultyHard = 2,
    SVMathDifficultyExtreme = 3
};

typedef NS_ENUM(NSInteger, SVAlarmSound) {
    SVAlarmSoundRadar = 0,
    SVAlarmSoundDigital = 1,
    SVAlarmSoundExtreme = 2,
    SVAlarmSoundGentle = 3
};

FOUNDATION_EXPORT NSString *SVMathDifficultyTitle(SVMathDifficulty difficulty);
FOUNDATION_EXPORT NSString *SVMathDifficultySubtitle(SVMathDifficulty difficulty);
FOUNDATION_EXPORT UIColor *SVMathDifficultyColor(SVMathDifficulty difficulty);

FOUNDATION_EXPORT NSString *SVAlarmSoundBaseName(SVAlarmSound sound);
FOUNDATION_EXPORT NSString *SVAlarmSoundFileName(SVAlarmSound sound);
FOUNDATION_EXPORT NSString *SVAlarmSoundDisplayName(SVAlarmSound sound);
FOUNDATION_EXPORT NSString *SVAlarmSoundSubtitle(SVAlarmSound sound);

@interface SVAlarmItem : NSObject <NSCopying>

@property (nonatomic, copy) NSString *alarmID;
@property (nonatomic, assign) NSInteger hour;
@property (nonatomic, assign) NSInteger minute;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
/// 1 = Lunedì ... 7 = Domenica
@property (nonatomic, copy) NSSet<NSNumber *> *repeatDays;
@property (nonatomic, assign) SVMathDifficulty difficulty;
@property (nonatomic, assign) NSInteger problemCount;
@property (nonatomic, assign) SVAlarmSound sound;
@property (nonatomic, assign) BOOL lockVolume;
@property (nonatomic, assign) BOOL smartQuietWhileTyping;
@property (nonatomic, assign) BOOL fadeIn;
@property (nonatomic, assign) BOOL wakeUpCheckEnabled;
@property (nonatomic, assign) BOOL snoozeEnabled;

- (instancetype)initWithDefaultValues;
- (nullable instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

- (NSString *)formattedTime;
- (NSString *)repeatSummary;
- (nullable NSDate *)nextTriggerDateFromDate:(NSDate *)referenceDate;

+ (NSInteger)isoWeekdayFromCalendarWeekday:(NSInteger)calendarWeekday;
+ (NSArray<SVAlarmItem *> *)defaultSamples;

@end

@interface SVMathProblem : NSObject

@property (nonatomic, copy, readonly) NSString *expression;
@property (nonatomic, assign, readonly) NSInteger answer;
@property (nonatomic, assign, readonly) SVMathDifficulty difficulty;

- (instancetype)initWithExpression:(NSString *)expression
                            answer:(NSInteger)answer
                        difficulty:(SVMathDifficulty)difficulty;

@end

@interface SVMathGenerator : NSObject

+ (SVMathProblem *)generateWithDifficulty:(SVMathDifficulty)difficulty;
+ (NSArray<SVMathProblem *> *)generateBatchWithDifficulty:(SVMathDifficulty)difficulty count:(NSInteger)count;

@end

NS_ASSUME_NONNULL_END
