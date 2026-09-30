import SwiftUI

struct SettingsView: View {
    @ObservedObject var tabManager: TabManager

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
                    ForEach($tabManager.configs) { $config in
                        HStack(spacing: 10) {
                            Image(systemName: config.id.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(config.isEnabled ? Color.white : Color.secondary)
                                .frame(width: 26, height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(config.isEnabled ? Theme.accentDeep : Color.secondary.opacity(0.18))
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
                                        .fill(widget.isEnabled && tabOn ? Theme.accent.opacity(0.75) : Color.secondary.opacity(0.18))
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
        .frame(width: 420, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
