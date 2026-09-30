import SwiftUI

struct SettingsView: View {
    @ObservedObject var tabManager: TabManager
    @ObservedObject private var appearance = Appearance.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "VoidBar")
                        .font(.system(size: 17, weight: .semibold))
                    Text(localized("Version %@", Bundle.main.shortVersion))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localized("Accent colour"))
                        HStack(spacing: 10) {
                            ForEach(Appearance.AccentPreset.allCases.filter { $0 != .custom }) { preset in
                                swatch(preset)
                            }
                            Divider().frame(height: 22)
                            ColorPicker(
                                "",
                                selection: Binding(
                                    get: { appearance.custom },
                                    set: { appearance.custom = $0; appearance.preset = .custom }
                                ),
                                supportsOpacity: false
                            )
                            .labelsHidden()
                            .help(localized("Custom"))
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: appearance.preset == .custom ? 2 : 0)
                                    .padding(-3)
                                    .allowsHitTesting(false)
                            )
                        }
                        Text(appearance.preset.title)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    Picker(localized("Aurora"), selection: $appearance.aurora) {
                        ForEach(Appearance.AuroraMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if appearance.aurora != .off {
                        HStack {
                            Text(localized("Aurora strength"))
                            Slider(value: $appearance.auroraIntensity, in: 0.3...1.6)
                        }
                    }

                    Toggle(localized("Opening animations"), isOn: $appearance.animations)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                } header: {
                    Text(localized("Appearance"))
                } footer: {
                    Text(localized("The panel itself stays black so it blends into the notch. With System Settings → Accessibility → Reduce motion on, animations stay off."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach($tabManager.configs) { $config in
                        HStack(spacing: 10) {
                            Image(systemName: config.id.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(config.isEnabled ? Color.white : Color.secondary)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(config.isEnabled ? appearance.accentColor.opacity(0.85) : Color.secondary.opacity(0.18))
                                )
                            Text(config.id.title)
                            Spacer()
                            Toggle("", isOn: $config.isEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        .padding(.vertical, 1)
                    }
                    .onMove { indices, newOffset in
                        tabManager.configs.move(fromOffsets: indices, toOffset: newOffset)
                    }
                } header: {
                    Text(localized("Tabs"))
                } footer: {
                    Text(localized("Drag to reorder. Switched-off tabs leave the panel but keep their data."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach($tabManager.widgets) { $widget in
                        let tabOn = tabManager.activeTabs.contains(widget.id.tab)
                        HStack(spacing: 10) {
                            Image(systemName: widget.id.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(widget.isEnabled && tabOn ? Color.white : Color.secondary)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(widget.isEnabled && tabOn ? appearance.accentColor.opacity(0.6) : Color.secondary.opacity(0.18))
                                )
                            VStack(alignment: .leading, spacing: 1) {
                                Text(widget.id.title)
                                if !tabOn {
                                    Text(localized("Its tab is off"))
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: $widget.isEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        .opacity(tabOn ? 1 : 0.55)
                        .padding(.vertical, 1)
                    }
                    .onMove { indices, newOffset in
                        tabManager.widgets.move(fromOffsets: indices, toOffset: newOffset)
                    }
                } header: {
                    Text(localized("Overview"))
                } footer: {
                    Text(localized("Drag to set the order. A widget shows only while its tab is on and it has something to show; Now playing takes the large card."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 440, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func swatch(_ preset: Appearance.AccentPreset) -> some View {
        let rgb = preset.rgb ?? (1, 1, 1)
        let selected = appearance.preset == preset
        return Button {
            appearance.preset = preset
        } label: {
            Circle()
                .fill(Color(.sRGB, red: rgb.0, green: rgb.1, blue: rgb.2))
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5))
                .padding(3)
                .overlay(Circle().strokeBorder(Color.white, lineWidth: selected ? 2 : 0))
        }
        .buttonStyle(.plain)
        .help(preset.title)
    }
}
