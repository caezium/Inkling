import SwiftUI

/// Container styling for a single Control-Center-style pill row.
/// Solid-ish translucent fill so pills pop from the glass behind them
/// (matches Apple Control Center / Notification Center pill chips).
struct PillCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
    }
}

struct PillSectionHeader: View {
    let text: String
    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.55))
                .tracking(0.6)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - Toggle pill

struct PillToggle: View {
    let icon: String
    let label: String
    var sublabel: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        PillCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(InklingTheme.secondaryText)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 13, weight: .medium))
                    if let sublabel {
                        Text(sublabel).font(.system(size: 10)).foregroundStyle(InklingTheme.tertiaryText)
                    }
                }
                Spacer()
                Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
        }
    }
}

// MARK: - Slider pill

struct PillSlider: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0.05
    var format: (Double) -> String = { String(format: "%.2f", $0) }
    var disabled: Bool = false

    var body: some View {
        PillCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .frame(width: 22)
                        .foregroundStyle(InklingTheme.secondaryText)
                    Text(label).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(format(value))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(InklingTheme.tertiaryText)
                }
                Slider(value: $value, in: range, step: step)
                    .controlSize(.small)
                    .disabled(disabled)
            }
        }
    }
}

// MARK: - Picker pill (popup)

struct PillPicker<T: Hashable & Identifiable>: View {
    let icon: String
    let label: String
    @Binding var selection: T
    let options: [T]
    let optionLabel: (T) -> String

    var body: some View {
        PillCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(InklingTheme.secondaryText)
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $selection) {
                    ForEach(options) { Text(optionLabel($0)).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 160)
            }
        }
    }
}

// MARK: - Button pill (full-width tappable row)

struct PillButton: View {
    let icon: String
    let label: String
    var trailing: String? = nil
    var role: ButtonRole? = nil
    var action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            PillCard {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .frame(width: 22)
                        .foregroundStyle(role == .destructive ? Color.red : InklingTheme.secondaryText)
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(role == .destructive ? Color.red : InklingTheme.primaryText)
                    Spacer()
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(InklingTheme.tertiaryText)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nav pill (tap to push deeper)

struct PillNav: View {
    let icon: String
    let label: String
    var detail: String? = nil
    var trailing: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            PillCard {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .frame(width: 22)
                        .foregroundStyle(InklingTheme.secondaryText)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label).font(.system(size: 13, weight: .medium))
                        if let detail {
                            Text(detail).font(.system(size: 10)).foregroundStyle(InklingTheme.tertiaryText)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    Spacer()
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(InklingTheme.tertiaryText)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(InklingTheme.tertiaryText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hotkey pill

struct PillHotkey: View {
    let icon: String
    let label: String
    @Binding var hotkey: Hotkey?
    var body: some View {
        PillCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 22)
                    .foregroundStyle(InklingTheme.secondaryText)
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer()
                HotkeyRecorder(hotkey: $hotkey, label: "")
            }
        }
    }
}
