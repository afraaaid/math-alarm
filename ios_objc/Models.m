#import "Models.h"
#include <stdlib.h>

static NSInteger SVRandomInRange(NSInteger minVal, NSInteger maxVal) {
    if (maxVal <= minVal) {
        return minVal;
    }
    uint32_t span = (uint32_t)(maxVal - minVal + 1);
    return minVal + (NSInteger)arc4random_uniform(span);
}

NSString *SVMathDifficultyTitle(SVMathDifficulty difficulty) {
    switch (difficulty) {
        case SVMathDifficultyEasy: return @"Facile";
        case SVMathDifficultyMedium: return @"Medio";
        case SVMathDifficultyHard: return @"Difficile";
        case SVMathDifficultyExtreme: return @"Estremo";
    }
}

NSString *SVMathDifficultySubtitle(SVMathDifficulty difficulty) {
    switch (difficulty) {
        case SVMathDifficultyEasy: return @"Addizioni e sottrazioni a 2 cifre";
        case SVMathDifficultyMedium: return @"Moltiplicazioni con somme o sottrazioni";
        case SVMathDifficultyHard: return @"Espressioni combinate a 3 termini";
        case SVMathDifficultyExtreme: return @"Doppie moltiplicazioni e differenze";
    }
}

UIColor *SVMathDifficultyColor(SVMathDifficulty difficulty) {
    switch (difficulty) {
        case SVMathDifficultyEasy:
            return [UIColor colorWithRed:0.20 green:0.84 blue:0.48 alpha:1.0];
        case SVMathDifficultyMedium:
            return [UIColor colorWithRed:1.00 green:0.72 blue:0.18 alpha:1.0];
        case SVMathDifficultyHard:
            return [UIColor colorWithRed:1.00 green:0.42 blue:0.18 alpha:1.0];
        case SVMathDifficultyExtreme:
            return [UIColor colorWithRed:1.00 green:0.22 blue:0.28 alpha:1.0];
    }
}

NSString *SVAlarmSoundBaseName(SVAlarmSound sound) {
    switch (sound) {
        case SVAlarmSoundRadar: return @"alarm_radar";
        case SVAlarmSoundDigital: return @"alarm_digital";
        case SVAlarmSoundExtreme: return @"alarm_extreme";
        case SVAlarmSoundGentle: return @"alarm_gentle";
    }
}

NSString *SVAlarmSoundFileName(SVAlarmSound sound) {
    return [NSString stringWithFormat:@"%@.wav", SVAlarmSoundBaseName(sound)];
}

NSString *SVAlarmSoundDisplayName(SVAlarmSound sound) {
    switch (sound) {
        case SVAlarmSoundRadar: return @"Radar Pro";
        case SVAlarmSoundDigital: return @"Sirena Digitale";
        case SVAlarmSoundExtreme: return @"Allarme Estremo";
        case SVAlarmSoundGentle: return @"Armonia Progressiva";
    }
}

NSString *SVAlarmSoundSubtitle(SVAlarmSound sound) {
    switch (sound) {
        case SVAlarmSoundRadar: return @"Impulsi netti ad alta penetrazione";
        case SVAlarmSoundDigital: return @"Doppio tono sveglia classica ad alto contrasto";
        case SVAlarmSoundExtreme: return @"Sirena modulata anti-sonno pesante";
        case SVAlarmSoundGentle: return @"Accordo crescente nei primi secondi";
    }
}

@implementation SVAlarmItem

- (instancetype)initWithDefaultValues {
    self = [super init];
    if (self) {
        _alarmID = [[NSUUID UUID] UUIDString];
        _hour = 7;
        _minute = 0;
        _label = @"Sveglia";
        _enabled = YES;
        _repeatDays = [NSSet set];
        _difficulty = SVMathDifficultyMedium;
        _problemCount = 3;
        _sound = SVAlarmSoundRadar;
        _lockVolume = YES;
        _smartQuietWhileTyping = YES;
        _fadeIn = NO;
        _wakeUpCheckEnabled = YES;
        _snoozeEnabled = NO;
    }
    return self;
}

- (nullable instancetype)initWithDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    self = [self initWithDefaultValues];
    if (self) {
        NSString *savedID = dict[@"alarmID"];
        if ([savedID isKindOfClass:[NSString class]] && savedID.length > 0) {
            _alarmID = [savedID copy];
        }
        if (dict[@"hour"]) {
            _hour = MAX(0, MIN(23, [dict[@"hour"] integerValue]));
        }
        if (dict[@"minute"]) {
            _minute = MAX(0, MIN(59, [dict[@"minute"] integerValue]));
        }
        NSString *savedLabel = dict[@"label"];
        if ([savedLabel isKindOfClass:[NSString class]] && savedLabel.length > 0) {
            _label = [savedLabel copy];
        }
        if (dict[@"enabled"]) {
            _enabled = [dict[@"enabled"] boolValue];
        }
        NSArray *daysArray = dict[@"repeatDays"];
        if ([daysArray isKindOfClass:[NSArray class]]) {
            NSMutableSet<NSNumber *> *filtered = [NSMutableSet set];
            for (id item in daysArray) {
                NSInteger day = [item integerValue];
                if (day >= 1 && day <= 7) {
                    [filtered addObject:@(day)];
                }
            }
            _repeatDays = [filtered copy];
        }
        if (dict[@"difficulty"]) {
            NSInteger diff = [dict[@"difficulty"] integerValue];
            if (diff >= SVMathDifficultyEasy && diff <= SVMathDifficultyExtreme) {
                _difficulty = (SVMathDifficulty)diff;
            }
        }
        if (dict[@"problemCount"]) {
            _problemCount = MAX(1, MIN(10, [dict[@"problemCount"] integerValue]));
        }
        if (dict[@"sound"]) {
            NSInteger snd = [dict[@"sound"] integerValue];
            if (snd >= SVAlarmSoundRadar && snd <= SVAlarmSoundGentle) {
                _sound = (SVAlarmSound)snd;
            }
        }
        if (dict[@"lockVolume"]) {
            _lockVolume = [dict[@"lockVolume"] boolValue];
        }
        if (dict[@"smartQuietWhileTyping"]) {
            _smartQuietWhileTyping = [dict[@"smartQuietWhileTyping"] boolValue];
        }
        if (dict[@"fadeIn"]) {
            _fadeIn = [dict[@"fadeIn"] boolValue];
        }
        if (dict[@"wakeUpCheckEnabled"]) {
            _wakeUpCheckEnabled = [dict[@"wakeUpCheckEnabled"] boolValue];
        }
        if (dict[@"snoozeEnabled"]) {
            _snoozeEnabled = [dict[@"snoozeEnabled"] boolValue];
        }
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSArray<NSNumber *> *sortedDays = [[self.repeatDays allObjects] sortedArrayUsingSelector:@selector(compare:)];
    return @{
        @"alarmID": self.alarmID ?: [[NSUUID UUID] UUIDString],
        @"hour": @(self.hour),
        @"minute": @(self.minute),
        @"label": self.label ?: @"Sveglia",
        @"enabled": @(self.enabled),
        @"repeatDays": sortedDays ?: @[],
        @"difficulty": @(self.difficulty),
        @"problemCount": @(self.problemCount),
        @"sound": @(self.sound),
        @"lockVolume": @(self.lockVolume),
        @"smartQuietWhileTyping": @(self.smartQuietWhileTyping),
        @"fadeIn": @(self.fadeIn),
        @"wakeUpCheckEnabled": @(self.wakeUpCheckEnabled),
        @"snoozeEnabled": @(self.snoozeEnabled)
    };
}

- (id)copyWithZone:(NSZone *)zone {
    SVAlarmItem *copy = [[SVAlarmItem allocWithZone:zone] initWithDefaultValues];
    copy.alarmID = self.alarmID;
    copy.hour = self.hour;
    copy.minute = self.minute;
    copy.label = self.label;
    copy.enabled = self.enabled;
    copy.repeatDays = self.repeatDays;
    copy.difficulty = self.difficulty;
    copy.problemCount = self.problemCount;
    copy.sound = self.sound;
    copy.lockVolume = self.lockVolume;
    copy.smartQuietWhileTyping = self.smartQuietWhileTyping;
    copy.fadeIn = self.fadeIn;
    copy.wakeUpCheckEnabled = self.wakeUpCheckEnabled;
    copy.snoozeEnabled = self.snoozeEnabled;
    return copy;
}

- (NSString *)formattedTime {
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)self.hour, (long)self.minute];
}

- (NSString *)repeatSummary {
    if (self.repeatDays.count == 0) {
        return @"Una volta";
    }
    if (self.repeatDays.count == 7) {
        return @"Ogni giorno";
    }
    NSSet *weekdays = [NSSet setWithArray:@[@1, @2, @3, @4, @5]];
    if ([self.repeatDays isEqualToSet:weekdays]) {
        return @"Lun - Ven";
    }
    NSSet *weekend = [NSSet setWithArray:@[@6, @7]];
    if ([self.repeatDays isEqualToSet:weekend]) {
        return @"Weekend";
    }
    NSArray<NSString *> *names = @[@"", @"Lun", @"Mar", @"Mer", @"Gio", @"Ven", @"Sab", @"Dom"];
    NSArray<NSNumber *> *sorted = [[self.repeatDays allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    for (NSNumber *num in sorted) {
        NSInteger idx = num.integerValue;
        if (idx >= 1 && idx <= 7) {
            [parts addObject:names[idx]];
        }
    }
    return [parts componentsJoinedByString:@", "];
}

+ (NSInteger)isoWeekdayFromCalendarWeekday:(NSInteger)calendarWeekday {
    return (calendarWeekday == 1) ? 7 : (calendarWeekday - 1);
}

- (nullable NSDate *)nextTriggerDateFromDate:(NSDate *)referenceDate {
    if (!self.enabled) {
        return nil;
    }
    NSCalendar *calendar = [NSCalendar currentCalendar];
    if (self.repeatDays.count == 0) {
        NSDateComponents *comps = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                              fromDate:referenceDate];
        comps.hour = self.hour;
        comps.minute = self.minute;
        comps.second = 0;
        NSDate *todayCandidate = [calendar dateFromComponents:comps];
        if (!todayCandidate) {
            return nil;
        }
        if ([todayCandidate compare:referenceDate] == NSOrderedDescending) {
            return todayCandidate;
        }
        return [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:todayCandidate options:0];
    }

    for (NSInteger dayOffset = 0; dayOffset <= 7; dayOffset++) {
        NSDate *baseDay = [calendar dateByAddingUnit:NSCalendarUnitDay value:dayOffset toDate:referenceDate options:0];
        if (!baseDay) {
            continue;
        }
        NSDateComponents *comps = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                              fromDate:baseDay];
        comps.hour = self.hour;
        comps.minute = self.minute;
        comps.second = 0;
        NSDate *candidate = [calendar dateFromComponents:comps];
        if (!candidate) {
            continue;
        }
        NSInteger calWeekday = [calendar component:NSCalendarUnitWeekday fromDate:candidate];
        NSInteger iso = [SVAlarmItem isoWeekdayFromCalendarWeekday:calWeekday];
        if ([candidate compare:referenceDate] == NSOrderedDescending && [self.repeatDays containsObject:@(iso)]) {
            return candidate;
        }
    }
    return nil;
}

+ (NSArray<SVAlarmItem *> *)defaultSamples {
    SVAlarmItem *work = [[SVAlarmItem alloc] initWithDefaultValues];
    work.hour = 7;
    work.minute = 0;
    work.label = @"Sveglia Lavoro";
    work.enabled = NO;
    work.repeatDays = [NSSet setWithArray:@[@1, @2, @3, @4, @5]];
    work.difficulty = SVMathDifficultyMedium;
    work.problemCount = 3;
    work.sound = SVAlarmSoundRadar;
    work.lockVolume = YES;
    work.smartQuietWhileTyping = YES;
    work.fadeIn = NO;
    work.wakeUpCheckEnabled = YES;

    SVAlarmItem *weekend = [[SVAlarmItem alloc] initWithDefaultValues];
    weekend.hour = 8;
    weekend.minute = 30;
    weekend.label = @"Weekend";
    weekend.enabled = NO;
    weekend.repeatDays = [NSSet setWithArray:@[@6, @7]];
    weekend.difficulty = SVMathDifficultyEasy;
    weekend.problemCount = 2;
    weekend.sound = SVAlarmSoundGentle;
    weekend.lockVolume = YES;
    weekend.smartQuietWhileTyping = YES;
    weekend.fadeIn = YES;
    weekend.wakeUpCheckEnabled = NO;

    return @[work, weekend];
}

@end

@implementation SVMathProblem

- (instancetype)initWithExpression:(NSString *)expression
                            answer:(NSInteger)answer
                        difficulty:(SVMathDifficulty)difficulty {
    self = [super init];
    if (self) {
        _expression = [expression copy];
        _answer = answer;
        _difficulty = difficulty;
    }
    return self;
}

@end

@implementation SVMathGenerator

+ (SVMathProblem *)generateWithDifficulty:(SVMathDifficulty)difficulty {
    switch (difficulty) {
        case SVMathDifficultyEasy: {
            if (arc4random_uniform(2) == 0) {
                NSInteger a = SVRandomInRange(14, 89);
                NSInteger b = SVRandomInRange(12, 79);
                return [[SVMathProblem alloc] initWithExpression:[NSString stringWithFormat:@"%ld + %ld", (long)a, (long)b]
                                                          answer:(a + b)
                                                      difficulty:SVMathDifficultyEasy];
            } else {
                NSInteger b = SVRandomInRange(12, 58);
                NSInteger delta = SVRandomInRange(11, 49);
                NSInteger a = b + delta;
                return [[SVMathProblem alloc] initWithExpression:[NSString stringWithFormat:@"%ld - %ld", (long)a, (long)b]
                                                          answer:(a - b)
                                                      difficulty:SVMathDifficultyEasy];
            }
        }
        case SVMathDifficultyMedium: {
            NSInteger a = SVRandomInRange(7, 17);
            NSInteger b = SVRandomInRange(3, 9);
            NSInteger product = a * b;
            if (arc4random_uniform(2) == 0 && product > 30) {
                NSInteger maxC = MIN(45, product - 8);
                NSInteger c = SVRandomInRange(11, maxC);
                return [[SVMathProblem alloc] initWithExpression:[NSString stringWithFormat:@"(%ld × %ld) - %ld", (long)a, (long)b, (long)c]
                                                          answer:(product - c)
                                                      difficulty:SVMathDifficultyMedium];
            } else {
                NSInteger c = SVRandomInRange(12, 54);
                return [[SVMathProblem alloc] initWithExpression:[NSString stringWithFormat:@"(%ld × %ld) + %ld", (long)a, (long)b, (long)c]
                                                          answer:(product + c)
                                                      difficulty:SVMathDifficultyMedium];
            }
        }
        case SVMathDifficultyHard: {
            NSInteger a = SVRandomInRange(12, 29);
            NSInteger b = SVRandomInRange(4, 9);
            NSInteger c = SVRandomInRange(24, 88);
            NSInteger sum = (a * b) + c;
            NSInteger maxD = MIN(65, sum - 12);
            NSInteger d = SVRandomInRange(14, maxD);
            return [[SVMathProblem alloc] initWithExpression:[NSString stringWithFormat:@"(%ld × %ld) + %ld - %ld", (long)a, (long)b, (long)c, (long)d]
                                                      answer:(sum - d)
                                                  difficulty:SVMathDifficultyHard];
        }
        case SVMathDifficultyExtreme: {
            NSInteger a = SVRandomInRange(19, 39);
            NSInteger b = SVRandomInRange(7, 14);
            NSInteger c = SVRandomInRange(6, 15);
            NSInteger d = SVRandomInRange(4, 9);
            NSInteger diff = (a * b) - (c * d);
            NSInteger e = SVRandomInRange(18, 75);
            if (diff + e <= 0) {
                e = labs(diff) + SVRandomInRange(20, 60);
            }
            return [[SVMathProblem alloc] initWithExpression:[NSString stringWithFormat:@"(%ld × %ld) - (%ld × %ld) + %ld", (long)a, (long)b, (long)c, (long)d, (long)e]
                                                      answer:(diff + e)
                                                  difficulty:SVMathDifficultyExtreme];
        }
    }
}

+ (NSArray<SVMathProblem *> *)generateBatchWithDifficulty:(SVMathDifficulty)difficulty count:(NSInteger)count {
    NSInteger safeCount = MAX(1, count);
    NSMutableArray<SVMathProblem *> *batch = [NSMutableArray arrayWithCapacity:(NSUInteger)safeCount];
    for (NSInteger i = 0; i < safeCount; i++) {
        [batch addObject:[self generateWithDifficulty:difficulty]];
    }
    return [batch copy];
}

@end
