import Foundation
import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AlarmEngine.shared.checkIfAnyAlarmShouldBeRingingNow()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AlarmEngine.shared.handleWillTerminateWhileRinging()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let reqID = notification.request.identifier
        let userInfo = notification.request.content.userInfo

        if reqID == "wakeup_check_prompt" {
            return [.banner, .sound, .list]
        }

        if let idStr = userInfo["alarmID"] as? String,
           let alarmID = UUID(uuidString: idStr) {
            AlarmEngine.shared.activateAlarmFromSystemTrigger(alarmID: alarmID)
        } else {
            AlarmEngine.shared.checkIfAnyAlarmShouldBeRingingNow()
        }

        if AudioSirenService.shared.isPlaying {
            return [.banner, .list]
        }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let reqID = response.notification.request.identifier
        let actionID = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        if reqID == "wakeup_check_prompt" {
            if actionID == AlarmEngine.wakeUpConfirmActionID || actionID == UNNotificationDefaultActionIdentifier {
                AlarmEngine.shared.confirmWakeUpCheck()
            }
            return
        }

        if let idStr = userInfo["alarmID"] as? String,
           let alarmID = UUID(uuidString: idStr) {
            AlarmEngine.shared.activateAlarmFromSystemTrigger(alarmID: alarmID)
        } else {
            AlarmEngine.shared.checkIfAnyAlarmShouldBeRingingNow()
        }
    }
}
