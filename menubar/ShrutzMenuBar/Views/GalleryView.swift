import SwiftUI
import AppKit

struct GalleryView: View {
    @AppStorage("hasAcceptedGalleryDisclaimer") private var hasAccepted = false

    var body: some View {
        if hasAccepted {
            GalleryListView()
        } else {
            GalleryDisclaimerView(onContinue: { hasAccepted = true })
        }
    }
}

private struct GalleryDisclaimerView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Creators Publish")
                .font(.shrutzSerif(22, weight: .semibold))
                .foregroundColor(ShrutzPalette.navy)
            Text("bros and not bros — I'm not the owner nor the plug for these, y'all. Download and use at your own discretion, but I crafted them with love. — gang_")
                .font(.shrutzSerif(15, italic: true))
                .foregroundColor(ShrutzPalette.navy.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Styled to match the Sets tab exactly — same fonts, same lazy/bounded
/// thumbnail pattern (here backed by RemoteThumbnailCache instead of the
/// local ThumbnailCache).
private struct GalleryListView: View {
    @State private var entries: [GalleryEntry] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var installingName: String?
    @State private var unloadError: [String: String] = [:]

    var body: some View {
        Group {
            if loading && entries.isEmpty {
                ProgressView("Loading gallery…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text(error).foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            entryRow(entry)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .task { await load() }
    }

    private func entryRow(_ entry: GalleryEntry) -> some View {
        HStack(spacing: 12) {
            GalleryThumbnail(urlString: entry.thumbnailUrl)
                .frame(width: 72, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.shrutzSerif(16, weight: .medium))
                    .foregroundColor(ShrutzPalette.navy)
                Text("by \(entry.author)")
                    .font(.shrutzSans(11))
                    .foregroundColor(.secondary)
                Text(entry.description)
                    .font(.shrutzSans(12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let message = unloadError[entry.name] {
                    Text(message)
                        .font(.shrutzSans(11))
                        .foregroundColor(.red)
                }
            }

            Spacer()

            actionControl(entry)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(ShrutzPalette.controlBackground))
    }

    @ViewBuilder
    private func actionControl(_ entry: GalleryEntry) -> some View {
        if installingName == entry.name {
            ProgressView().controlSize(.small)
        } else if entry.installed {
            Button("Unload") { Task { await unload(entry) } }
        } else {
            Button("Install") { Task { await install(entry.name) } }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            entries = try await ShrutzCLI.runJSON(["gallery", "list", "--json"], as: [GalleryEntry].self)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load the gallery — check your network connection"
        }
    }

    private func install(_ name: String) async {
        installingName = name
        defer { installingName = nil }
        _ = try? await ShrutzCLI.run(["gallery", "install", name])
        await load()
    }

    private func unload(_ entry: GalleryEntry) async {
        guard let result = try? await ShrutzCLI.run(["set", "delete", entry.name, "-y"]) else { return }
        if result.exitCode != 0 {
            unloadError[entry.name] = result.stderr.contains("is in use")
                ? "Can't unload — this is your active wallpaper set. Switch to a different set first."
                : "Couldn't unload '\(entry.name)'."
        } else {
            unloadError[entry.name] = nil
            await load()
        }
    }
}

private struct GalleryThumbnail: View {
    let urlString: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ShrutzPalette.controlBackground
            }
        }
        .task(id: urlString) {
            image = await RemoteThumbnailCache.shared.thumbnail(for: urlString)
        }
    }
}
