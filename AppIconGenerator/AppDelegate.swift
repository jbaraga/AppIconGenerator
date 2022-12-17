//
//  AppDelegate.swift
//  AppIconGenerator
//
//  Created by Joseph Baraga on 12/30/18.
//  Copyright © 2018 Joseph Baraga. All rights reserved.
//

import Cocoa

struct OpenRecent {
    static let NotificationName = Notification.Name("Open Recent")
    static let Key = "Open Recent Key"
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let center = NotificationCenter.default
        let notification = Foundation.Notification(name: OpenRecent.NotificationName, object: nil, userInfo: [OpenRecent.Key: filename])
        center.post(notification)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}

