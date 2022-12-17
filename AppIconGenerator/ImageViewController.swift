//
//  ImageViewController.swift
//  AppIconGenerator
//
//  Created by Joseph Baraga on 12/30/18.
//  Copyright © 2018 Joseph Baraga. All rights reserved.
//

import Cocoa
import UniformTypeIdentifiers

class ImageViewController: NSViewController, NSMenuItemValidation {
    
    private enum OperatingSystem {
        case iOS
        case macOS
        
        static let imageSizesIOS: [ImageSize] = [
            ImageSize(dimension: 20, multiplier: 1),
            ImageSize(dimension: 20, multiplier: 2),
            ImageSize(dimension: 20, multiplier: 3),
            ImageSize(dimension: 29, multiplier: 1),
            ImageSize(dimension: 29, multiplier: 2),
            ImageSize(dimension: 29, multiplier: 3),
            ImageSize(dimension: 40, multiplier: 1),
            ImageSize(dimension: 40, multiplier: 2),
            ImageSize(dimension: 40, multiplier: 3),
            ImageSize(dimension: 60, multiplier: 2),
            ImageSize(dimension: 60, multiplier: 3),
            ImageSize(dimension: 76, multiplier: 1),
            ImageSize(dimension: 76, multiplier: 2),
            ImageSize(dimension: 83.5, multiplier: 2),
            ImageSize(dimension: 1024, multiplier: 1)
        ]
        
        static let imageSizesMacOs: [ImageSize] = [
            ImageSize(dimension: 16, multiplier: 1),
            ImageSize(dimension: 16, multiplier: 2),
            ImageSize(dimension: 32, multiplier: 1),
            ImageSize(dimension: 32, multiplier: 2),
            ImageSize(dimension: 128, multiplier: 1),
            ImageSize(dimension: 128, multiplier: 2),
            ImageSize(dimension: 256, multiplier: 1),
            ImageSize(dimension: 256, multiplier: 2),
            ImageSize(dimension: 512, multiplier: 1),
            ImageSize(dimension: 512, multiplier: 2)
        ]

        var imageSizes: [ImageSize] {
            switch self {
            case .iOS : return OperatingSystem.imageSizesIOS
            case .macOS: return OperatingSystem.imageSizesMacOs
            }
        }
    }
    
    private enum SaveError: Error {
        case imageData
        case filewrite(String)
        
        var description: String {
            switch self {
            case .imageData: return "Error generating resized image."
            case .filewrite(let details): return "Error saving file: " + details
            }
        }
    }
    
    @IBOutlet weak var messageLabel: NSTextField!
    
    @IBOutlet weak var imageView: IconImageView! {
        didSet {
            imageView.setup()
        }
    }
    
    var image: NSImage? {
        didSet {
            imageView.image = image
            messageLabel.isHidden = image != nil
        }
    }
    
    var imageURL: URL? {
        didSet {
            if let url = imageURL {
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            }
        }
    }
    
    struct ImageSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var multiplier: Int = 1
        
        //Pixels
        var size: NSSize {
            return NSSize(width: width * CGFloat(multiplier), height: height * CGFloat(multiplier))
        }
        
        var fileSuffix: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            guard let widthString = formatter.string(from: NSNumber(value: Float(width))), let heightString = formatter.string(from: NSNumber(value: Float(height))) else {
                return "_\(width)x\(height)@\(multiplier)x"
            }
            return "_\(widthString)x\(heightString)@\(multiplier)x"
        }
        
        init(dimension: CGFloat, multiplier: Int) {
            width = dimension
            height = dimension
            self.multiplier = multiplier
        }
    }
    
    
    @IBAction func openImage(_ sender: NSMenuItem) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.image]
        
        Task {
            let response = await panel.begin()
            switch response {
            case .OK:
                guard let url = panel.url else { return }
                await MainActor.run {
                    self.image = NSImage(contentsOf: url)
                    self.imageURL = url
                }
            default:
                break
            }
        }
    }
    
    //For dragging, copy-paste actions
    @IBAction func imageViewAction(_ sender: IconImageView) {
        image = sender.image
        imageURL = sender.imageURL
    }
    
    func openFile(_ filename: String) {
        let url = URL(fileURLWithPath: filename)
        image = NSImage(contentsOf: url)
        imageURL = url
    }
    
    @IBAction func saveImageSet(_ sender: NSMenuItem) {
        //Allows selection of directory only
        let panel = NSOpenPanel()
        panel.canCreateDirectories = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Save"

        //Save panel does not work, cannot save file to selected directory "file already exists" error
//        guard let imageURL = imageURL else { return }
//        let baseName = imageURL.deletingPathExtension().lastPathComponent
//
//        let panel = NSSavePanel()
//        panel.canCreateDirectories = true
//        panel.nameFieldStringValue = baseName
//        panel.prompt = "Save"
        
        let os = sender.title.contains("iOS") ? OperatingSystem.iOS : .macOS
        Task {
            let result = await panel.begin()
            switch result {
            case .OK:
                guard let url = panel.url else { return }
                await MainActor.run {
                    do {
                        try saveImageSet(to: url, os: os)
                    } catch {
                        let alert = NSAlert()
                        alert.messageText = "Error Saving Image Set"
                        alert.informativeText = error.localizedDescription
                        let _ = alert.runModal()
                    }
                }
            default:
                break
            }
        }
    }
    
    private func saveImageSet(to directoryURL: URL, os: OperatingSystem) throws {
        guard let imageURL = imageURL else { return }
        let baseName = imageURL.deletingPathExtension().lastPathComponent
        
        try os.imageSizes.forEach {
            guard let image = self.image else { return }
            let resizedImage = resize(image, toSize: $0)
            guard let data = resizedImage.tiffRepresentation, let imageRep = NSBitmapImageRep(data: data), let imageData = imageRep.representation(using: .png, properties: [:]) else { throw SaveError.imageData }
            let filename = baseName + $0.fileSuffix
            var url = directoryURL
            url.appendPathComponent(filename)
            url.appendPathExtension("png")
            
            do {
                try imageData.write(to: url)
            } catch {
                NSLog(error.localizedDescription)
                throw SaveError.filewrite(error.localizedDescription)
            }
        }
    }
    
    private func resize(_ image: NSImage, toSize imageSize: ImageSize) -> NSImage {
        let scale = view.layer?.contentsScale ?? 1.0  //convert points to pixels
        let newSize = imageSize.size / scale
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        return resizedImage
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else { return false }
        switch action {
        case #selector(openImage(_:)):
            return true
        case #selector(saveImageSet(_:)):
            return image != nil
        default:
            return true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: OpenRecent.NotificationName, object: nil, queue: .main) { notification in
            if let filename = notification.userInfo?[OpenRecent.Key] as? String {
                self.openFile(filename)
            }
        }
    }
}


/*
class ImageViewController: NSViewController, NSMenuItemValidation {
    
    private enum OperatingSystem {
        case iOS
        case macOS
        
        static let imageSizesIOS: [ImageSize] = [
            ImageSize(dimension: 20, multiplier: 1),
            ImageSize(dimension: 20, multiplier: 2),
            ImageSize(dimension: 20, multiplier: 3),
            ImageSize(dimension: 29, multiplier: 1),
            ImageSize(dimension: 29, multiplier: 2),
            ImageSize(dimension: 29, multiplier: 3),
            ImageSize(dimension: 40, multiplier: 1),
            ImageSize(dimension: 40, multiplier: 2),
            ImageSize(dimension: 40, multiplier: 3),
            ImageSize(dimension: 60, multiplier: 2),
            ImageSize(dimension: 60, multiplier: 3),
            ImageSize(dimension: 76, multiplier: 1),
            ImageSize(dimension: 76, multiplier: 2),
            ImageSize(dimension: 83.5, multiplier: 2),
            ImageSize(dimension: 1024, multiplier: 1)
        ]
        
        static let imageSizesMacOs: [ImageSize] = [
            ImageSize(dimension: 16, multiplier: 1),
            ImageSize(dimension: 16, multiplier: 2),
            ImageSize(dimension: 32, multiplier: 1),
            ImageSize(dimension: 32, multiplier: 2),
            ImageSize(dimension: 128, multiplier: 1),
            ImageSize(dimension: 128, multiplier: 2),
            ImageSize(dimension: 256, multiplier: 1),
            ImageSize(dimension: 256, multiplier: 2),
            ImageSize(dimension: 512, multiplier: 1),
            ImageSize(dimension: 512, multiplier: 2)
        ]

        var imageSizes: [ImageSize] {
            switch self {
            case .iOS : return OperatingSystem.imageSizesIOS
            case .macOS: return OperatingSystem.imageSizesMacOs
            }
        }
    }
    
    @IBOutlet weak var messageLabel: NSTextField!
    
    @IBOutlet weak var imageView: IconImageView! {
        didSet {
            imageView.setup()
        }
    }
    
    var image: NSImage? {
        didSet {
            imageView.image = image
            messageLabel.isHidden = image != nil
        }
    }
    
    var imageURL: URL? {
        didSet {
            if let url = imageURL {
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            }
        }
    }
    
    struct ImageSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var multiplier: Int = 1
        
        //Pixels
        var size: NSSize {
            return NSSize(width: width * CGFloat(multiplier), height: height * CGFloat(multiplier))
        }
        
        var fileSuffix: String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            guard let widthString = formatter.string(from: NSNumber(value: Float(width))), let heightString = formatter.string(from: NSNumber(value: Float(height))) else {
                return "_\(width)x\(height)@\(multiplier)x"
            }
            return "_\(widthString)x\(heightString)@\(multiplier)x"
        }
        
        init(dimension: CGFloat, multiplier: Int) {
            width = dimension
            height = dimension
            self.multiplier = multiplier
        }
    }
    
    
    @IBAction func openImage(_ sender: NSMenuItem) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedFileTypes = [String(kUTTypeImage)]
        
        openPanel.begin { result in
            if result == NSApplication.ModalResponse.OK {
                if let url = openPanel.url {
                    self.imageURL = url
                    self.image = NSImage(contentsOf: url)
                }
            }
        }
    }
    
    //For dragging, copy-paste actions
    @IBAction func imageViewAction(_ sender: IconImageView) {
        image = sender.image
        imageURL = sender.imageURL
    }
    
    func openFile(_ filename: String) {
        let url = URL(fileURLWithPath: filename)
        image = NSImage(contentsOf: url)
        imageURL = url
    }
    
    @IBAction func saveImageSet(_ sender: NSMenuItem) {
        let openPanel = NSOpenPanel()
        openPanel.canCreateDirectories = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Save"
        
        let os = sender.title.contains("iOS") ? OperatingSystem.iOS : .macOS
        
        openPanel.begin { result in
            if result == NSApplication.ModalResponse.OK {
                if let url = openPanel.url {
                    self.saveImageSet(to: url, os: os)
                }
            }
        }
    }
    
    private func saveImageSet(to directoryURL: URL, os: OperatingSystem) {
        guard let imageURL = imageURL else { return }
        let baseName = imageURL.deletingPathExtension().lastPathComponent
        let imageSizes = os.imageSizes
        for imageSize in imageSizes {
            if let resizedImage = resizeImage(to: imageSize) {
                if let data = resizedImage.tiffRepresentation, let imageRep = NSBitmapImageRep(data: data), let imageData = imageRep.representation(using: .png, properties: [:]) {
                    let filename = baseName + imageSize.fileSuffix
                    let fileURL = directoryURL.appendingPathComponent(filename).appendingPathExtension("png")
                    
                    do {
                        try imageData.write(to: fileURL)
                    } catch {
                        NSLog(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    func resizeImage(to imageSize: ImageSize) -> NSImage? {
        guard let image = image else { return nil }
        let scale = view.layer?.contentsScale ?? 1.0  //convert points to pixels
        let newSize = imageSize.size / scale
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        return resizedImage
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else { return false }
        switch action {
        case #selector(openImage(_:)):
            return true
        case #selector(saveImageSet(_:)):
            return image != nil
        default:
            return true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: OpenRecent.NotificationName, object: nil, queue: OperationQueue.main) { [unowned self] notification in
            if let filename = notification.userInfo?[OpenRecent.Key] as? String {
                self.openFile(filename)
            }
        }
    }
    
}
 */



