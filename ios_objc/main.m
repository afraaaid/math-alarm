#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import "AlarmEngine.h"
#import "Views.h"

@interface SVSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SVSceneDelegate

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.backgroundColor = [UIColor blackColor];
    window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    window.rootViewController = [[SVRootContainerViewController alloc] init];
    self.window = window;
    [window makeKeyAndVisible];

    [[SVAlarmEngine shared] checkIfAnyAlarmShouldBeRingingNow];
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    [[SVAlarmEngine shared] handleReturnedToForeground];
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    if ([[SVAlarmEngine shared] isRinging]) {
        [[SVAlarmEngine shared] handleMovedToBackgroundWhileRinging];
    }
}

@end

@interface SVAppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>
@end

@implementation SVAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    [[SVAlarmEngine shared] checkIfAnyAlarmShouldBeRingingNow];
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                               options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *config = [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                                                 sessionRole:connectingSceneSession.role];
    config.delegateClass = [SVSceneDelegate class];
    return config;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[SVAlarmEngine shared] handleWillTerminateWhileRinging];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSString *reqID = notification.request.identifier;
    NSDictionary *userInfo = notification.request.content.userInfo;

    if ([reqID isEqualToString:@"wakeup_check_prompt"]) {
        if (@available(iOS 14.0, *)) {
            completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList);
        } else {
            completionHandler(UNNotificationPresentationOptionSound);
        }
        return;
    }

    NSString *alarmID = [userInfo[@"alarmID"] isKindOfClass:[NSString class]] ? userInfo[@"alarmID"] : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (alarmID.length > 0) {
            [[SVAlarmEngine shared] activateAlarmFromSystemTriggerWithID:alarmID];
        } else {
            [[SVAlarmEngine shared] checkIfAnyAlarmShouldBeRingingNow];
        }

        BOOL playing = [SVAudioSirenService shared].isPlaying;
        if (@available(iOS 14.0, *)) {
            UNNotificationPresentationOptions opts = UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList;
            if (!playing) {
                opts |= UNNotificationPresentationOptionSound;
            }
            completionHandler(opts);
        } else {
            completionHandler(playing ? UNNotificationPresentationOptionNone : UNNotificationPresentationOptionSound);
        }
    });
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    NSString *reqID = response.notification.request.identifier;
    NSString *actionID = response.actionIdentifier;
    NSDictionary *userInfo = response.notification.request.content.userInfo;

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([reqID isEqualToString:@"wakeup_check_prompt"]) {
            if ([actionID isEqualToString:SVWakeUpConfirmActionID] ||
                [actionID isEqualToString:UNNotificationDefaultActionIdentifier]) {
                [[SVAlarmEngine shared] confirmWakeUpCheck];
            }
            completionHandler();
            return;
        }

        NSString *alarmID = [userInfo[@"alarmID"] isKindOfClass:[NSString class]] ? userInfo[@"alarmID"] : nil;
        if (alarmID.length > 0) {
            [[SVAlarmEngine shared] activateAlarmFromSystemTriggerWithID:alarmID];
        } else {
            [[SVAlarmEngine shared] checkIfAnyAlarmShouldBeRingingNow];
        }
        completionHandler();
    });
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SVAppDelegate class]));
    }
}
