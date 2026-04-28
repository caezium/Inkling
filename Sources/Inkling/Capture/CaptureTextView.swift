import AppKit
import SwiftUI
import Carbon.HIToolbox

/// Multi-line text input that surfaces submit / dismiss / switch / open intents up to SwiftUI.
struct CaptureTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onIntent: (CaptureIntent) -> Void
    var onPasteImage: ((NSImage) -> String?)?
    var onPasteFileURL: ((URL) -> String?)?
    var placeholder: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.borderType = .noBorder
        scroll.autohidesScrollers = true

        let tv = InterceptingTextView(frame: .zero)
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        tv.textContainerInset = NSSize(width: 0, height: 4)
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.textColor = NSColor.labelColor
        tv.insertionPointColor = NSColor.labelColor
        tv.placeholderText = placeholder
        tv.intentHandler = { intent in
            DispatchQueue.main.async { onIntent(intent) }
        }
        tv.imageHandler = onPasteImage
        tv.fileURLHandler = onPasteFileURL
        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? InterceptingTextView else { return }
        if tv.string != text { tv.string = text }
        tv.placeholderText = placeholder
        tv.imageHandler = onPasteImage
        tv.fileURLHandler = onPasteFileURL
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CaptureTextEditor
        init(_ parent: CaptureTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

enum CaptureIntent {
    case submitAppend
    case submitPrepend
    case submitAppendAndOpen
    case openFile
    case openSettings
    case dismiss
    case switchFile
    case insertNewline
    case dictate
    case completeSlash
}

private final class InterceptingTextView: NSTextView {
    var intentHandler: ((CaptureIntent) -> Void)?
    var imageHandler: ((NSImage) -> String?)?
    var fileURLHandler: ((URL) -> String?)?
    var placeholderText: String = "" {
        didSet { needsDisplay = true }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        // Defer to the next runloop so the panel has finished becoming key.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        let availableTypes = pb.types?.map(\.rawValue).joined(separator: ", ") ?? "(none)"
        NSLog("Inkling.paste: types=[\(availableTypes)] imageHandler=\(imageHandler != nil) fileHandler=\(fileURLHandler != nil)")

        // 1. File URLs first — copy a file in Finder, paste here, get an attachment link.
        if let handler = fileURLHandler {
            if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
               !urls.isEmpty {
                let links = urls.compactMap(handler)
                if !links.isEmpty {
                    insertText(links.joined(separator: " "), replacementRange: selectedRange())
                    NSLog("Inkling.paste: handled \(links.count) file URL(s)")
                    return
                }
            }
            // Fallback: some pasteboards expose only public.file-url as a string.
            if let s = pb.string(forType: NSPasteboard.PasteboardType("public.file-url")),
               let url = URL(string: s), url.isFileURL,
               let link = handler(url) {
                insertText(link, replacementRange: selectedRange())
                NSLog("Inkling.paste: handled file URL via public.file-url string")
                return
            }
        }

        // 2. Inline image data — screenshots, drag-from-browser, copied from Preview, etc.
        if let handler = imageHandler {
            if let image = NSImage(pasteboard: pb), let markdown = handler(image) {
                insertText(markdown, replacementRange: selectedRange())
                NSLog("Inkling.paste: handled image via NSImage(pasteboard:)")
                return
            }
            let imageTypes: [NSPasteboard.PasteboardType] = [
                .tiff,
                .png,
                NSPasteboard.PasteboardType("public.png"),
                NSPasteboard.PasteboardType("public.jpeg"),
                NSPasteboard.PasteboardType("public.heic"),
                NSPasteboard.PasteboardType("com.compuserve.gif"),
                NSPasteboard.PasteboardType("public.tiff")
            ]
            for type in imageTypes {
                if let data = pb.data(forType: type),
                   let img = NSImage(data: data),
                   let markdown = handler(img) {
                    insertText(markdown, replacementRange: selectedRange())
                    NSLog("Inkling.paste: handled image via type=\(type.rawValue)")
                    return
                }
            }
        }

        NSLog("Inkling.paste: nothing extractable, deferring to super (text paste)")
        super.paste(sender)
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = mods.contains(.command)
        let shift = mods.contains(.shift)
        let option = mods.contains(.option)
        let plain = mods.subtracting([.numericPad, .function]).isEmpty

        switch event.keyCode {
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            if cmd && shift {
                intentHandler?(.submitAppendAndOpen); return
            }
            if cmd && option {
                intentHandler?(.submitPrepend); return
            }
            if cmd {
                intentHandler?(.submitAppend); return
            }
            if shift || option {
                // Shift+Return / Option+Return inserts a literal newline.
                intentHandler?(.insertNewline)
                super.keyDown(with: event)
                return
            }
            intentHandler?(.submitAppend); return
        case UInt16(kVK_Escape):
            intentHandler?(.dismiss); return
        case UInt16(kVK_ANSI_W) where cmd && !shift && !option:
            intentHandler?(.dismiss); return
        case UInt16(kVK_Tab) where plain:
            // Tab in slash-mode completes the highlighted slash command;
            // otherwise it opens the file switcher.
            if string.hasPrefix("/") {
                intentHandler?(.completeSlash)
            } else {
                intentHandler?(.switchFile)
            }
            return
        case UInt16(kVK_ANSI_O) where cmd && !shift && !option:
            intentHandler?(.openFile); return
        case UInt16(kVK_ANSI_Backslash) where cmd && !shift && !option:
            intentHandler?(.dictate); return
        case UInt16(kVK_ANSI_V) where cmd && !shift && !option:
            // Force-route ⌘V through our paste override so we always get a
            // chance to peek at the pasteboard for images / file URLs.
            paste(self)
            return
        case UInt16(kVK_ANSI_Comma) where cmd && !shift && !option:
            // Don't auto-repeat — holding ⌘+, would otherwise toggle the
            // settings panel rapidly. Only fire on the initial keystroke.
            if event.isARepeat { return }
            NSLog("Inkling.capture: ⌘+, intercepted in capture text view")
            intentHandler?(.openSettings); return
        default:
            break
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderText.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 22),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let inset = textContainerInset
        let origin = NSPoint(x: inset.width + 5, y: inset.height)
        (placeholderText as NSString).draw(at: origin, withAttributes: attrs)
    }
}
