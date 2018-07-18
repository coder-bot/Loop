//
//  AppDelegate.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/15/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit
import UserNotifications
import CarbKit
import InsulinKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private(set) lazy var deviceManager = DeviceDataManager()
    
    //Shortcut item saved upon app launch; used at activation.
    var launchedShortcutItem: UIApplicationShortcutItem?
    
    //Enum, from Apple's sample code on quick actions, to identify which shortcut was chosen
    enum ShortcutIdentifier: String {
        case carbs
        case bolus
        
        init?(fullType: String) {
            guard let last = fullType.components(separatedBy: ".").last else { return nil }
            self.init(rawValue: last)
        }
        
        var type: String {
            return Bundle.main.bundleIdentifier! + ".\(self.rawValue)"
        }
    }
    
    //Function to handle Home screen quick action items, based on Apple's sample code in "ApplicationShortcuts: Using UIApplicationShortcutItems"
    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        //Track whether we've handled the shortcut item yet
        var handled = false;
        
        //Verify that we can handle the shortcutItem's type
        guard ShortcutIdentifier(fullType: shortcutItem.type) != nil else {return false}
        guard let shortcutType = shortcutItem.type as String? else {return false}
        
        //The modification of view controllers comes from the tutorial at http://www.brianjcoleman.com/tutorial-3d-touch-quick-actions-in-swift/
        //Save storyboard
        let sb = UIStoryboard(name: "Main", bundle: nil)
        //Declare ViewController for modification in switch
        var vc = UIViewController()
        
        switch shortcutType {
        case ShortcutIdentifier.carbs.type:
            //Handle carb entry shortcut
            vc = sb.instantiateViewController(withIdentifier: "Carb-Scene")
            handled = true
            break
        case ShortcutIdentifier.bolus.type:
            //Handle bolus shortcut
            vc = sb.instantiateViewController(withIdentifier: "Bolus-Scene")
            handled = true
            break
        default:
            break
        }
        
        //Display the selected view controller
        window!.rootViewController?.present(vc, animated: true, completion:nil)
        
        //Return the handled flag
        return handled
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // Override point for customization after application launch.
        var shouldPerformAdditionalDelegateHandling = true
        
        window?.tintColor = UIColor.tintColor

        NotificationManager.authorize(delegate: self)

        let bundle = Bundle(for: type(of: self))
        DiagnosticLogger.shared = DiagnosticLogger(subsystem: bundle.bundleIdentifier!, version: bundle.shortVersionString)
        DiagnosticLogger.shared?.forCategory("AppDelegate").info(#function)

        AnalyticsManager.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        if  let navVC = window?.rootViewController as? UINavigationController,
            let statusVC = navVC.viewControllers.first as? StatusTableViewController {
            statusVC.deviceManager = deviceManager
        }

        //If a quick action shortcut was launched, take the appropriate action
        if let shortcutItem = launchOptions?[UIApplicationLaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            launchedShortcutItem = shortcutItem
            
            // This will block "performActionForShortcutItem:completionHandler" from being called.
            shouldPerformAdditionalDelegateHandling = false
        }
        
        return shouldPerformAdditionalDelegateHandling
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        //We take care of shortcut items selected before reactivation here.
        guard let shortcut = launchedShortcutItem else {return}
        _ = handleShortcutItem(shortcut)
        //Reset for next time
        launchedShortcutItem = nil
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func applicationShouldRequestHealthAuthorization(_ application: UIApplication) {

    }

    // MARK: - 3D Touch

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handledShortcutItem = handleShortcutItem(shortcutItem)
        completionHandler(handledShortcutItem)
    }
}


extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case NotificationManager.Action.retryBolus.rawValue:
            if  let units = response.notification.request.content.userInfo[NotificationManager.UserInfoKey.bolusAmount.rawValue] as? Double,
                let startDate = response.notification.request.content.userInfo[NotificationManager.UserInfoKey.bolusStartDate.rawValue] as? Date,
                startDate.timeIntervalSinceNow >= TimeInterval(minutes: -5)
            {
                AnalyticsManager.shared.didRetryBolus()

                deviceManager.enactBolus(units: units, at: startDate) { (_) in
                    completionHandler()
                }
                return
            }
        default:
            break
        }
        
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .alert])
    }
}
