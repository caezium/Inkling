import SwiftUI
import AppKit

struct MenuFileDetailView: View {
    @Binding var file: TrackedFile
    var onDelete: () -> Void
    var onPickFile: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var headings: [MarkdownReader.Heading] {
        MarkdownReader.headings(at: file.resolvedURL)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                PillSectionHeader(text: "File")
                PillButton(icon: "doc.text", label: "Choose file…",
                           trailing: file.path.split(separator: "/").last.map(String.init),
                           action: onPickFile)
                aliasRow
                PillSectionHeader(text: "Capture")
                PillHotkey(icon: "command", label: "Hotkey", hotkey: $file.hotkey)
                modeRow

                if !headings.isEmpty {
                    PillSectionHeader(text: "Section target")
                    sectionPickerRow
                }

                PillSectionHeader(text: "Format")
                templateRow
                PillToggle(icon: "clock", label: "Prefix with timestamp",
                           isOn: $file.includeTimestamp)

                PillButton(icon: "trash", label: "Remove file",
                           role: .destructive, action: onDelete)
            }
            .padding(10)
        }
        .navigationTitle(file.displayName)
        .navigationBarBackButtonHidden(false)
    }

    private var aliasRow: some View {
        PillCard {
            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(InklingTheme.secondaryText)
                Text("Alias").font(.system(size: 13, weight: .medium))
                Spacer()
                TextField("", text: $file.alias)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13))
                    .frame(maxWidth: 180)
            }
        }
    }

    private var modeRow: some View {
        PillCard {
            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(InklingTheme.secondaryText)
                Text("Mode").font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $file.mode) {
                    ForEach(TrackedFile.Mode.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 140)
                .onChange(of: file.mode) { _, new in
                    if file.template.isEmpty || isDefaultTemplate(file.template) {
                        file.template = new.defaultTemplate
                    }
                }
            }
        }
    }

    private var sectionPickerRow: some View {
        PillCard {
            HStack(spacing: 12) {
                Image(systemName: "number")
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(InklingTheme.secondaryText)
                Text("Append under").font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: Binding(
                    get: { file.targetSection ?? "" },
                    set: { file.targetSection = $0.isEmpty ? nil : $0 }
                )) {
                    Text("End of file").tag("")
                    Divider()
                    ForEach(headings) { h in Text(h.indentedLabel).tag(h.title) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 180)
            }
        }
    }

    private var templateRow: some View {
        PillCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: "curlybraces")
                        .font(.system(size: 14))
                        .frame(width: 22)
                        .foregroundStyle(InklingTheme.secondaryText)
                    Text("Template").font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                TextField("- [ ] {{text}}", text: $file.template)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                Text("Vars: {{text}} {{date}} {{time}} {{datetime}} {{week}} {{alias}}")
                    .font(.system(size: 9)).foregroundStyle(InklingTheme.tertiaryText)
            }
        }
    }

    private func isDefaultTemplate(_ t: String) -> Bool {
        TrackedFile.Mode.allCases.contains { $0.defaultTemplate == t }
    }
}
