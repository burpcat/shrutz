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
            VStack(spacing: 14) {
                Text("Disclaimer")
                    .font(.shrutzSerif(18, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                Text("bros and not bros — I'm not the owner nor the plug for these. Download and use at your discretion, but I crafted them with love.\n— gang")
                    .font(.shrutzSerif(14, italic: true))
                    .foregroundColor(.black.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
                Button("I understand") { onContinue() }
                    .buttonStyle(.borderedProminent)
                    .tint(ShrutzPalette.accent)
            }
            .padding(28)
            .glassCard()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Same serif/small-caps/lazy-thumbnail language as the Sets tab, laid out
/// as a 3-column grid (mockup 08).
private struct GalleryListView: View {
    @State private var entries: [GalleryEntry] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var installingName: String?
    @State private var unloadError: [String: String] = [:]

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        Group {
            if loading && entries.isEmpty {
                ProgressView("Loading gallery…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if errorMessage != nil {
                errorCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(entries) { entry in
                            entryCard(entry)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .task { await load() }
    }

    private var errorCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 26))
                .foregroundColor(ShrutzPalette.textSecondary)
            Text("Couldn't load the gallery — check your connection")
                .font(.system(size: 13))
                .foregroundColor(ShrutzPalette.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
            Button("Try again") { Task { await load() } }
                .buttonStyle(.borderedProminent)
                .tint(ShrutzPalette.accent)
        }
        .padding(28)
        .glassCard()
    }

    private func entryCard(_ entry: GalleryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                GalleryThumbnail(urlString: entry.thumbnailUrl)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(ShrutzPalette.thumbnailAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusThumbnail, style: .continuous))

                if entry.installed {
                    Button {
                        Task { await unload(entry) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ShrutzPalette.accent)
                            .background(Circle().fill(.white))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }

            Text(entry.name)
                .font(.shrutzSerif(16, weight: .medium))
                .foregroundColor(ShrutzPalette.textPrimary)
            Text(entry.author)
                .font(.shrutzSmallCaps(10))
                .tracking(1)
                .foregroundColor(ShrutzPalette.textSecondary)
            Text(entry.description)
                .font(.system(size: 11))
                .foregroundColor(ShrutzPalette.textSecondary)
                .lineLimit(1)
            Text("\(entry.images) images")
                .font(.system(size: 10))
                .foregroundColor(ShrutzPalette.textSecondary)

            if let message = unloadError[entry.name] {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
            }

            actionControl(entry)
        }
        .padding(10)
        .glassCard()
    }

    @ViewBuilder
    private func actionControl(_ entry: GalleryEntry) -> some View {
        if installingName == entry.name {
            ProgressView().controlSize(.small)
        } else if entry.installed {
            Text("Installed")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ShrutzPalette.textSecondary)
        } else {
            Button("Download") { Task { await install(entry.name) } }
                .buttonStyle(.borderedProminent)
                .tint(ShrutzPalette.accent)
                .controlSize(.small)
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
                Shimmer()
            }
        }
        .task(id: urlString) {
            image = await RemoteThumbnailCache.shared.thumbnail(for: urlString)
        }
    }
}
