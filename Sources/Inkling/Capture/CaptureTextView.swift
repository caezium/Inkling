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

        // 1. File URLs (e.g. file copied from Finder) — treat them like a drop.
        if let handler = fileURLHandler,
           let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let links = urls.compactMap(handler)
            if !links.isEmpty {
                insertText(links.joined(separator: " "), replacementRange: selectedRange())
                return
            }
        }

        // 2. Inline image data (TIFF/PNG/JPEG, screenshots, drag-from-browser, etc.).
        if let handler = imageHandler {
            // NSImage(pasteboard:) handles the common types but sometimes returns nil
            // when only a single binary blob (e.g. .png) is on the board, so fall back manually.
            if let image = NSImage(pasteboard: pb), let markdown = handler(image) {
                insertText(markdown, replacementRange: selectedRange())
                return
            }
            let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png, NSPasteboard.PasteboardType("public.jpeg"), NSPasteboard.PasteboardType("public.png")]
            for type in imageTypes {
                if let data = pb.data(forType: type),
                   let img = NSImage(data: data),
                   let markdown = handler(img) {
                    insertText(markdown, replacementRange: selectedRange())
                    return
                }
            }
        }

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
