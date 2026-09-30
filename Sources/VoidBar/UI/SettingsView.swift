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
            }
            .formStyle(.grouped)
        }
        .frame(width: 420, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
