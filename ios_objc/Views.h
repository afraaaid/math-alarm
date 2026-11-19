#import <UIKit/UIKit.h>
#import "AlarmEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface SVRootContainerViewController : UIViewController
@end

@interface SVAlarmListViewController : UIViewController
@end

@interface SVAlarmEditorViewController : UIViewController
- (instancetype)initWithAlarm:(nullable SVAlarmItem *)alarm
                       onSave:(void (^)(SVAlarmItem *savedAlarm))onSave
                     onDelete:(nullable void (^)(NSString *alarmID))onDelete;
@end

@interface SVMathLockViewController : UIViewController
@end

@interface SVPracticeSettingsViewController : UIViewController
@end

NS_ASSUME_NONNULL_END
