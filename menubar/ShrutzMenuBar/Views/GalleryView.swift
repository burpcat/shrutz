import SwiftUI

struct GalleryView: View {
    @State private var entries: [GalleryEntry] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var installingName: String?

    var body: some View {
        VStack {
            if loading && entries.isEmpty {
                ProgressView("Loading gallery…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                Text(error).foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    HStack {
                        AsyncImage(url: URL(string: entry.thumbnailUrl)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.gray.opacity(0.2)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading) {
                            Text(entry.name).bold()
                            Text(entry.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if entry.installed {
                            Text("Installed").foregroundColor(.secondary)
                        } else if installingName == entry.name {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Install") {
                                Task { await install(entry.name) }
                            }
                        }
                    }
                }
            }
        }
        .task { await load() }
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
}
