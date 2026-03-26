import SwiftUI
import AppKit

struct MenuBarMenuView: View {
    @ObservedObject var appState: AppState
    let onPreferences: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(appState.isImporting ? .orange : .green)
                    .frame(width: 7, height: 7)
                Text(appState.isImporting ? "Importing…" : "Monitoring for SD cards")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Last import
            VStack(alignment: .leading, spacing: 2) {
                Text("LAST IMPORT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                if let folder = appState.lastImportFolderPath {
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: folder))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.accentColor)
                            Text(URL(fileURLWithPath: folder).lastPathComponent)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("No imports yet")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
            }
            .padding(.bottom, 6)

            Divider()

            // Actions
            VStack(spacing: 0) {
                MenuBarActionButton(
                    label: "Open Destination Folder",
                    icon: "folder.badge.plus"
                ) {
                    let dest = AppSettings.shared.destinationPath
                    let url = URL(fileURLWithPath: dest)
                    if !FileManager.default.fileExists(atPath: dest) {
                        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                    }
                    NSWorkspace.shared.open(url)
                }

                MenuBarActionButton(
                    label: "Preferences…",
                    icon: "gearshape",
                    shortcut: "⌘,"
                ) {
                    onPreferences()
                }

                Divider().padding(.horizontal, 14).padding(.vertical, 4)

                MenuBarActionButton(
                    label: "Quit SD Import",
                    icon: "power",
                    isDestructive: true
                ) {
                    onQuit()
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 260)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct MenuBarActionButton: View {
    let label: String
    let icon: String
    var shortcut: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 13))
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(isDestructive ? .red : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isHovered ? Color.accentColor.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
