//
//  AppDelegate.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/14 (19/02/21 swift).
//  Copyright (c) 2014 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import BackgroundTasks
import NextcloudKit
import LocalAuthentication
import Firebase
import WidgetKit
import Queuer
import EasyTipView
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var tipView: EasyTipView?
    var backgroundSessionCompletionHandler: (() -> Void)?
    var activeLogin: NCLogin?
    var activeLoginWeb: NCLoginProvider?
    var taskAutoUploadDate: Date = Date()
    var isUiTestingEnabled: Bool {
        return ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }
    var notificationSettings: UNNotificationSettings?

    var loginFlowV2Token = ""
    var loginFlowV2Endpoint = ""
    var loginFlowV2Login = ""

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if isUiTestingEnabled {
            NCAccount().deleteAllAccounts()
        }
        let utilityFileSystem = NCUtilityFileSystem()
        let utility = NCUtility()
        var levelLog = 0

        NCSettingsBundleHelper.checkAndExecuteSettings(delay: 0)

        let versionNextcloudiOS = String(format: NCBrandOptions.shared.textCopyrightNextcloudiOS, utility.getVersionApp())

        UserDefaults.standard.register(defaults: ["UserAgent": userAgent])
        if !NCKeychain().disableCrashservice, !NCBrandOptions.shared.disable_crash_service {
            FirebaseApp.configure()
        }

        utilityFileSystem.createDirectoryStandard()
        utilityFileSystem.emptyTemporaryDirectory()
        utilityFileSystem.clearCacheDirectory("com.limit-point.LivePhoto")

        NextcloudKit.shared.setup(delegate: NCNetworking.shared)
        NextcloudKit.shared.nkCommonInstance.pathLog = utilityFileSystem.directoryGroup

        /// Activated singleton for receive the NSNotification
        _ = NCActionCenter.shared
        _ = NCNetworking.shared

        if NCBrandOptions.shared.disable_log {
            utilityFileSystem.removeFile(atPath: NextcloudKit.shared.nkCommonInstance.filenamePathLog)
            utilityFileSystem.removeFile(atPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/" + NextcloudKit.shared.nkCommonInstance.filenameLog)
        } else {
            levelLog = NCKeychain().logLevel
            NextcloudKit.shared.nkCommonInstance.levelLog = levelLog
            NextcloudKit.shared.nkCommonInstance.copyLogToDocumentDirectory = true
            NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Start session with level \(levelLog) " + versionNextcloudiOS)
        }

        // Push Notification & display notification
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            self.notificationSettings = settings
        }
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

        if !utility.isSimulatorOrTestFlight() {
            let review = NCStoreReview()
            review.incrementAppRuns()
            review.showStoreReview()
        }

        // Background task register
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NCGlobal.shared.refreshTask, using: nil) { task in
            self.handleAppRefresh(task)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NCGlobal.shared.processingTask, using: nil) { task in
            self.handleProcessingTask(task)
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        if self.notificationSettings?.authorizationStatus != .denied && UIApplication.shared.backgroundRefreshStatus == .available {
            let content = UNMutableNotificationContent()
            content.title = NCBrandOptions.shared.brand
            content.body = NSLocalizedString("_keep_running_", comment: "")
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.add(req)
        }

        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] bye bye")
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: - Background Task

    /*
    @discussion Schedule a refresh task request to ask that the system launch your app briefly so that you can download data and keep your app's contents up-to-date. The system will fulfill this request intelligently based on system conditions and app usage.
     */
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: NCGlobal.shared.refreshTask)

        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Refresh after 60 seconds.
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Refresh task failed to submit request: \(error)")
        }
    }

    /*
     @discussion Schedule a processing task request to ask that the system launch your app when conditions are favorable for battery life to handle deferrable, longer-running processing, such as syncing, database maintenance, or similar tasks. The system will attempt to fulfill this request to the best of its ability within the next two days as long as the user has used your app within the past week.
     */
    func scheduleAppProcessing() {
        let request = BGProcessingTaskRequest(identifier: NCGlobal.shared.processingTask)

        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // Refresh after 5 minutes.
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            NextcloudKit.shared.nkCommonInstance.writeLog("[ERROR] Background Processing task failed to submit request: \(error)")
        }
    }

    func handleAppRefresh(_ task: BGTask) {
        scheduleAppRefresh()

        handleAppRefreshProcessingTask(taskText: "AppRefresh") {
            task.setTaskCompleted(success: true)
        }
    }

    func handleProcessingTask(_ task: BGTask) {
        scheduleAppProcessing()

        handleAppRefreshProcessingTask(taskText: "ProcessingTask") {
            task.setTaskCompleted(success: true)
        }
    }

    func handleAppRefreshProcessingTask(taskText: String, completion: @escaping () -> Void = {}) {
        Task {
            var itemsAutoUpload = 0
            guard let account = NCManageDatabase.shared.getActiveTableAccount()?.account else {
                return
            }

            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] \(taskText) start handle")

            // Test every > 1 min
            if Date() > self.taskAutoUploadDate.addingTimeInterval(60) {
                self.taskAutoUploadDate = Date()
                itemsAutoUpload = await NCAutoUpload.shared.initAutoUpload(account: account)
                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] \(taskText) auto upload with \(itemsAutoUpload) uploads")
            } else {
                NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] \(taskText) disabled auto upload")
            }

            let results = await NCNetworkingProcess.shared.start(scene: nil)
            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] \(taskText) networking process with download: \(results.counterDownloading) upload: \(results.counterUploading)")

            if taskText == "ProcessingTask",
               itemsAutoUpload == 0,
               results.counterDownloading == 0,
               results.counterUploading == 0,
               let directories = NCManageDatabase.shared.getTablesDirectory(predicate: NSPredicate(format: "account == %@ AND offline == true", account), sorted: "offlineDate", ascending: true) {
                for directory: tableDirectory in directories {
                    // test only 3 time for day (every 8 h.)
                    if let offlineDate = directory.offlineDate, offlineDate.addingTimeInterval(28800) > Date() {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] \(taskText) skip synchronization for \(directory.serverUrl) in date \(offlineDate)")
                        continue
                    }
                    let results = await NCNetworking.shared.synchronization(account: account, serverUrl: directory.serverUrl, add: false)
                    NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] \(taskText) end synchronization for \(directory.serverUrl), errorCode: \(results.errorCode), item: \(results.items)")
                }
            }

            let counter = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "account == %@ AND (session == %@ || session == %@) AND status != %d", account, NextcloudKit.shared.nkCommonInstance.identifierSessionDownloadBackground, NextcloudKit.shared.nkCommonInstance.identifierSessionUploadBackground, NCGlobal.shared.metadataStatusNormal))?.count ?? 0
            UIApplication.shared.applicationIconBadgeNumber = counter

            NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] \(taskText) completion handle")
            completion()
        }
    }

    // MARK: - Background Networking Session

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        NextcloudKit.shared.nkCommonInstance.writeLog("[DEBUG] Start handle Events For Background URLSession: \(identifier)")
        WidgetCenter.shared.reloadAllTimelines()
        backgroundSessionCompletionHandler = completionHandler
    }

    // MARK: - Push Notifications

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let pref = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup),
           let data = pref.object(forKey: "NOTIFICATION_DATA") as? [String: AnyObject] {
            nextcloudPushNotificationAction(data: data)
            pref.set(nil, forKey: "NOTIFICATION_DATA")
        }

        completionHandler()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NCNetworking.shared.checkPushNotificationServerProxyCertificateUntrusted(viewController: UIApplication.shared.firstWindow?.rootViewController) { error in
            if error == .success {
                NCPushNotification.shared.registerForRemoteNotificationsWithDeviceToken(deviceToken)
            }
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NCPushNotification.shared.applicationdidReceiveRemoteNotification(userInfo: userInfo) { result in
            completionHandler(result)
        }
    }

    func nextcloudPushNotificationAction(data: [String: AnyObject]) {
        guard let data = NCApplicationHandle().nextcloudPushNotificationAction(data: data) else { return }
        var findAccount: String?

        if let accountPush = data["account"] as? String {
            for tableAccount in NCManageDatabase.shared.getAllTableAccount() {
                if tableAccount.account == accountPush {
                    for controller in SceneManager.shared.getControllers() {
                        if controller.account == accountPush {
                            NCAccount().changeAccount(tableAccount.account, userProfile: nil, controller: controller) {
                                findAccount = tableAccount.account
                            }
                        }
                    }
                }
            }
            if let account = findAccount, let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
                viewController.session = NCSession.shared.getSession(account: account)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let navigationController = UINavigationController(rootViewController: viewController)
                    navigationController.modalPresentationStyle = .fullScreen
                    UIApplication.shared.firstWindow?.rootViewController?.present(navigationController, animated: true)
                }
            } else {
                let message = NSLocalizedString("_the_account_", comment: "") + " " + accountPush + " " + NSLocalizedString("_does_not_exist_", comment: "")
                let alertController = UIAlertController(title: NSLocalizedString("_info_", comment: ""), message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default, handler: { _ in }))
                UIApplication.shared.firstWindow?.rootViewController?.present(alertController, animated: true, completion: { })
            }
        }
    }

    // MARK: - Login

    func openLogin(selector: Int, openLoginWeb: Bool, windowForRootViewController: UIWindow? = nil) {
        let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount()

        func showLoginViewController(_ viewController: UIViewController?) {
            guard let viewController else { return }
            let navigationController = NCLoginNavigationController(rootViewController: viewController)

            navigationController.modalPresentationStyle = .fullScreen
            navigationController.navigationBar.barStyle = .black
            navigationController.navigationBar.tintColor = NCBrandColor.shared.customerText
            navigationController.navigationBar.barTintColor = NCBrandColor.shared.customer
            navigationController.navigationBar.isTranslucent = false

            if let window = windowForRootViewController {
                window.rootViewController = navigationController
                window.makeKeyAndVisible()
            } else {
                UIApplication.shared.allSceneSessionDestructionExceptFirst()
                UIApplication.shared.firstWindow?.rootViewController?.present(navigationController, animated: true)
            }
        }

        // Nextcloud standard login
        if selector == NCGlobal.shared.introSignup {
            if activeLogin?.view.window == nil {
                activeLogin = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin
                if selector == NCGlobal.shared.introSignup {
                    activeLogin?.urlBase = NCBrandOptions.shared.linkloginPreferredProviders
                    let web = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginProvider") as? NCLoginProvider
                    web?.urlBase = NCBrandOptions.shared.linkloginPreferredProviders
                    showLoginViewController(web)
                } else {
                    activeLogin?.urlBase = activeTableAccount?.urlBase ?? ""
                    showLoginViewController(activeLogin)
                }
            }

        } else if NCBrandOptions.shared.disable_request_login_url {
            if activeLogin?.view.window == nil {
                activeLogin = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin
                activeLogin?.urlBase = NCBrandOptions.shared.loginBaseUrl
                showLoginViewController(activeLogin)
            }
        } else if openLoginWeb {
            // Used also for reinsert the account (change passwd)
            if activeLogin?.view.window == nil {
                activeLogin = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin
                activeLogin?.urlBase = activeTableAccount?.urlBase ?? ""
                activeLogin?.disableUrlField = true
                activeLogin?.disableCloseButton = true
                showLoginViewController(activeLogin)
            }
        } else {
            if activeLogin?.view.window == nil {
                activeLogin?.disableCloseButton = true

                activeLogin = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin
                showLoginViewController(activeLogin)
            }
        }
    }

    // MARK: - Error Networking

    /*
    func startTimerErrorNetworking(scene: UIScene) {
        timerErrorNetworkingDisabled = false
        timerErrorNetworking = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(checkErrorNetworking(_:)), userInfo: nil, repeats: true)
    }

    @objc private func checkErrorNetworking(_ notification: NSNotification) {
        guard !self.timerErrorNetworkingDisabled else { return }

        for tableAccount in NCManageDatabase.shared.getAllTableAccount() {
            let password = NCKeychain().getPassword(account: tableAccount.account)
            if password.isEmpty {
                for controller in SceneManager.shared.getControllers() {
                    if controller.account == tableAccount.account {
                        openLogin(selector: NCGlobal.shared.introLogin, openLoginWeb: true)
                    }
                }
            }
        }
    }
    */

    func trustCertificateError(host: String) {
        guard let activeTableAccount = NCManageDatabase.shared.getActiveTableAccount(),
              let currentHost = URL(string: activeTableAccount.urlBase)?.host,
              let pushNotificationServerProxyHost = URL(string: NCBrandOptions.shared.pushNotificationServerProxy)?.host,
              host != pushNotificationServerProxyHost,
              host == currentHost
        else { return }
        let certificateHostSavedPath = NCUtilityFileSystem().directoryCertificates + "/" + host + ".der"
        var title = NSLocalizedString("_ssl_certificate_changed_", comment: "")

        if !FileManager.default.fileExists(atPath: certificateHostSavedPath) {
            title = NSLocalizedString("_connect_server_anyway_", comment: "")
        }

        let alertController = UIAlertController(title: title, message: NSLocalizedString("_server_is_trusted_", comment: ""), preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_yes_", comment: ""), style: .default, handler: { _ in
            NCNetworking.shared.writeCertificate(host: host)
        }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_no_", comment: ""), style: .default, handler: { _ in }))

        alertController.addAction(UIAlertAction(title: NSLocalizedString("_certificate_details_", comment: ""), style: .default, handler: { _ in
            if let navigationController = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil).instantiateInitialViewController() as? UINavigationController,
               let viewController = navigationController.topViewController as? NCViewCertificateDetails {
                viewController.delegate = self
                viewController.host = host
                UIApplication.shared.firstWindow?.rootViewController?.present(navigationController, animated: true)
            }
        }))

        UIApplication.shared.firstWindow?.rootViewController?.present(alertController, animated: true)
    }

    // MARK: - Reset Application

    func resetApplication() {
        let utilityFileSystem = NCUtilityFileSystem()

        NCNetworking.shared.cancelAllTask()

        URLCache.shared.memoryCapacity = 0
        URLCache.shared.diskCapacity = 0

        utilityFileSystem.removeGroupDirectoryProviderStorage()
        utilityFileSystem.removeGroupApplicationSupport()
        utilityFileSystem.removeDocumentsDirectory()
        utilityFileSystem.removeTemporaryDirectory()

        NCKeychain().removeAll()
        exit(0)
    }

    // MARK: - Universal Links

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        let applicationHandle = NCApplicationHandle()
        return applicationHandle.applicationOpenUserActivity(userActivity)
    }
}

// MARK: - Extension

extension AppDelegate: NCViewCertificateDetailsDelegate {
    func viewCertificateDetailsDismiss(host: String) {
        trustCertificateError(host: host)
    }
}

extension AppDelegate: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        guard let metadatas = metadatas, !metadatas.isEmpty else { return }
        NCNetworkingProcess.shared.createProcessUploads(metadatas: metadatas)
    }
}
