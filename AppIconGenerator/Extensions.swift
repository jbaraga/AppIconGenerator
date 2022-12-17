//
//  Extensions.swift
//  AppIconGenerator
//
//  Created by Joseph Baraga on 12/30/18.
//  Copyright © 2018 Joseph Baraga. All rights reserved.
//

import Foundation


extension NSSize {
    static func / (lhs: NSSize, rhs: CGFloat) -> NSSize {
        return NSSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
}
