import SwiftUI

struct SettingsView: View {
    @ObservedObject var tabManager: TabManager
    
    var body: some View {
        VStack(spacing: 0) {
            Text("VoidBar Preferences")
                .font(.headline)
                .padding()
            
            Text("Drag and drop to reorder tabs. Use the toggle to show or hide a tab in the notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            List {
                ForEach($tabManager.configs) { $config in
                    HStack {
                        Image(systemName: config.id.symbol)
                            .frame(width: 24, alignment: .center)
                            .foregroundStyle(.secondary)
                        
                        Text(config.id.title)
                        
                        Spacer()
                        
                        Toggle("", isOn: $config.isEnabled)
                            .toggleStyle(.switch)
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    tabManager.configs.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 400, height: 500)
    }
}
