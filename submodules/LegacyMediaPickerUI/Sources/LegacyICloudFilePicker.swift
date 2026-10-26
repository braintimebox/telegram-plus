import Foundation
import UIKit
import UniformTypeIdentifiers
import TelegramCore
import Display
import TelegramPresentationData
import LegacyUI

private class DocumentPickerViewController: UIDocumentPickerViewController {
    var forceDarkTheme = false
    var didDisappear: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *), self.forceDarkTheme {
            self.overrideUserInterfaceStyle = .dark
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.didDisappear?()
    }
}

private final class LegacyICloudFileController: LegacyController, UIDocumentPickerDelegate {
    let completion: ([URL]) -> Void
    private var didComplete = false
    
    var hasCompletedSelection: Bool {
        return self.didComplete
    }
    
    init(presentation: LegacyControllerPresentation, theme: PresentationTheme?, completion: @escaping ([URL]) -> Void) {
        self.completion = completion
        
        super.init(presentation: presentation, theme: theme)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func complete(_ urls: [URL]) {
        if self.didComplete {
            return
        }
        self.didComplete = true
        self.completion(urls)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Logger.shared.log("FilePicker", "delegate: cancelled")
        self.complete([])
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Logger.shared.log("FilePicker", "delegate: didPickDocumentsAt count=\(urls.count)")
        self.complete(urls)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        Logger.shared.log("FilePicker", "delegate: didPickDocumentAt \(url.lastPathComponent)")
        self.complete([url])
    }
}

public enum LegacyICloudFilePickerMode {
    case `default`
    case `import`
    case `export`
    
    var documentPickerMode: UIDocumentPickerMode {
        switch self {
        case .default:
            return .open
        case .import:
            return .import
        case .export:
            return .exportToService
        }
    }
}

public func legacyICloudFilePicker(theme: PresentationTheme, mode: LegacyICloudFilePickerMode = .default, hasMultiselection: Bool = false, url: URL? = nil, documentTypes: [String] = ["public.item"], forceDarkTheme: Bool = false, dismissed: @escaping () -> Void = {}, completion: @escaping ([URL]) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    let legacyController = LegacyICloudFileController(presentation: .modal(animateIn: true), theme: theme, completion: { urls in
        dismissImpl?()
        completion(urls)
    })
    legacyController.statusBar.statusBarStyle = .Black
    
    let controller: DocumentPickerViewController
    if case .export = mode, let url {
        if #available(iOS 14.0, *) {
            controller = DocumentPickerViewController(forExporting: [url], asCopy: true)
        } else {
            controller = DocumentPickerViewController(url: url, in: mode.documentPickerMode)
        }
    } else if #available(iOS 14.0, *) {
        var contentTypes: [UTType] = []
        for documentType in documentTypes {
            if let contentType = UTType(documentType) {
                contentTypes.append(contentType)
            }
        }
        if contentTypes.isEmpty {
            contentTypes = [UTType.item]
        }
        var asCopy = false
        if case .import = mode {
            asCopy = true
        }
        controller = DocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: asCopy)
    } else {
        controller = DocumentPickerViewController(documentTypes: documentTypes, in: mode.documentPickerMode)
    }
    controller.forceDarkTheme = forceDarkTheme || theme.overallDarkAppearance
    Logger.shared.log("FilePicker", "build: mode=\(mode) types=\(documentTypes) multi=\(hasMultiselection) os=\(UIDevice.current.systemVersion)")
    controller.didDisappear = { [weak legacyController] in
        // Telegram Plus: the picker's view disappears before the delegate callback is
        // delivered on recent iOS versions. Dismissing the host at that moment tore the
        // delegate down, so the picked file was never handed over ("Open" did nothing).
        if let legacyController = legacyController, !legacyController.hasCompletedSelection {
            Logger.shared.log("FilePicker", "viewDidDisappear without selection -> dismissing host")
            dismissImpl?()
        }
    }
    controller.delegate = legacyController
    if #available(iOSApplicationExtension 11.0, iOS 11.0, *), hasMultiselection {
        controller.allowsMultipleSelection = true
    }
    
    var presentationRetries = 0
    legacyController.presentationCompleted = { [weak legacyController] in
        if let legacyController = legacyController {
            if let window = legacyController.view.window {
                Logger.shared.log("FilePicker", "present: window ok, key=\(window.isKeyWindow), root=\(String(describing: type(of: window.rootViewController)))")
                controller.popoverPresentationController?.sourceView = window
                controller.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                window.rootViewController?.present(controller, animated: true)
                legacyController.presentationCompleted = nil
            } else if presentationRetries < 5 {
                presentationRetries += 1
                Logger.shared.log("FilePicker", "present: window is nil, retry \(presentationRetries)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    legacyController.presentationCompleted?(legacyController)
                }
            } else {
                Logger.shared.log("FilePicker", "present: window is nil, giving up")
            }
        }
    }
    
    dismissImpl = { [weak legacyController] in
        if let legacyController = legacyController {
            legacyController.dismiss()
        }
        dismissed()
    }
    legacyController.bind(controller: UIViewController())
    return legacyController
}
