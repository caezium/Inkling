import Foundation

enum TemplateEngine {
    static func render(template: String, text: String, file: TrackedFile, timestampFormat: String) -> String {
        let now = Date()
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let dtFmt = DateFormatter()
        dtFmt.dateFormat = timestampFormat
        let weekFmt = DateFormatter()
        weekFmt.dateFormat = "yyyy-'W'ww"

        var result = template.isEmpty ? "{{text}}" : template
        let replacements: [String: String] = [
            "{{text}}": text,
            "{{date}}": dateFmt.string(from: now),
            "{{time}}": timeFmt.string(from: now),
            "{{datetime}}": dtFmt.string(from: now),
            "{{week}}": weekFmt.string(from: now),
            "{{alias}}": file.displayName
        ]
        for (k, v) in replacements { result = result.replacingOccurrences(of: k, with: v) }

        if file.includeTimestamp, !result.contains(dtFmt.string(from: now)) {
            result = "[\(dtFmt.string(from: now))] " + result
        }
        return result
    }
}
