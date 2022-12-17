//
//  IconImageView.swift
//  AppIconGenerator
//
//  Created by Joseph Baraga on 12/30/18.
//  Copyright © 2018 Joseph Baraga. All rights reserved.
//

import Cocoa

class IconImageView: NSImageView {
    var imageURL: URL?
    
    func setup() {
        registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        sender.numberOfValidItemsForDrop = 1
        let pBoard = sender.draggingPasteboard
        
        if let url = NSURL(from: pBoard) as URL? {
            imageURL = url
            return super.performDragOperation(sender)
        }
        
        return false
    }
}
