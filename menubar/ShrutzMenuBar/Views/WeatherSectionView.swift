import SwiftUI

/// The 7 fixed weather categories the bash daemon buckets conditions into
/// (shrutz's WEATHER_CONDITIONS constant) — stable enough to hardcode for
/// iteration/UI purposes. The VALUES each condition maps to always come
/// from live JSON (`WeatherStatus.mappings`), never hardcoded here.
enum WeatherCondition: String, CaseIterable {
    case clear, cloudy, fog, rain, snow, storm, night

    var label: String { rawValue.capitalized }

    var tint: [Color] {
        switch self {
        case .clear: return [Color(hex: 0xE8B84A), Color(hex: 0xF3D98A)]
        case .cloudy: return [Color(hex: 0xB8BCC2), Color(hex: 0xD8DADD)]
        case .fog: return [Color(hex: 0xCFCFC9), Color(hex: 0xE8E8E3)]
        case .rain: return [Color(hex: 0x3E5C6E), Color(hex: 0x27414F)]
        case .snow: return [Color(hex: 0xFFFFFF), Color(hex: 0xD8E2E8)]
        case .storm: return [Color(hex: 0x3A3A42), Color(hex: 0x6B4E8E)]
        case .night: return [Color(hex: 0x2C2F5A), Color(hex: 0x14163A)]
        }
    }
}

struct WeatherSectionView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if let weather = appState.weather, weather.enabled {
            WeatherMappingEditor(weather: weather)
        } else {
            WeatherEnablePrompt()
        }
    }
}

private struct WeatherEnablePrompt: View {
    @EnvironmentObject var appState: AppState
    @State private var locationInput = ""
    @State private var submitting = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Enable weather-based switching?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ShrutzPalette.textPrimary)
                .textScrim()

            // Not shown in the mockup, but functionally required — `weather
            // on` refuses without a location set first.
            TextField("City name or lat,lon", text: $locationInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)

            HStack(spacing: 12) {
                Button("Yes") { Task { await enable() } }
                    .buttonStyle(.borderedProminent)
                    .tint(ShrutzPalette.accent)
                Button("why not, yes!") { Task { await enable() } }
                    .buttonStyle(.bordered)
            }
            .disabled(locationInput.isEmpty || submitting)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func enable() async {
        submitting = true
        defer { submitting = false }
        await appState.enableWeather(location: locationInput)
    }
}

private struct WeatherMappingEditor: View {
    @EnvironmentObject var appState: AppState
    let weather: WeatherStatus

    @State private var selectedCondition: WeatherCondition = .clear

    private var mappedSetName: String? {
        weather.mappings.first(where: { $0.condition == selectedCondition.rawValue })?.set
    }

    var body: some View {
        VStack(spacing: 16) {
            topZone
            bottomZone
        }
        .padding(20)
    }

    private var topZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP ZONE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(ShrutzPalette.textSecondary)

            Menu {
                ForEach(WeatherCondition.allCases, id: \.self) { condition in
                    Button(condition.label) { selectedCondition = condition }
                }
            } label: {
                HStack {
                    Text(selectedCondition.label)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: selectedCondition.tint, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusCard))
    }

    private var bottomZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Associate a wallpaper set")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text("Zone renders neutral grey when unselected")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))

            Menu {
                ForEach(appState.sets) { set in
                    Button(set.name) {
                        Task { await appState.mapWeather(condition: selectedCondition.rawValue, set: set.name) }
                    }
                }
                if mappedSetName != nil {
                    Divider()
                    Button("Unmap") { Task { await appState.unmapWeather(condition: selectedCondition.rawValue) } }
                }
            } label: {
                HStack {
                    Text(mappedSetName ?? "Choose a set")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.down").foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .menuStyle(.borderlessButton)
            .disabled(appState.sets.isEmpty)

            if let mappedSetName {
                filmstrip(for: mappedSetName)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(mappedPalette == nil ? AnyView(ShrutzPalette.pausedGlass) : AnyView(FrostedTintBackground(palette: mappedPalette)))
        .clipShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusCard))
    }

    @State private var mappedPalette: WallpaperPalette?

    private func filmstrip(for setName: String) -> some View {
        let paths = appState.sets.first(where: { $0.name == setName })?.imagePaths.prefix(4) ?? []
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(Array(paths), id: \.self) { path in
                    WeatherFilmstripThumbnail(path: path)
                }
            }
        }
        .task(id: setName) {
            guard let path = appState.sets.first(where: { $0.name == setName })?.imagePaths.first else {
                mappedPalette = nil
                return
            }
            mappedPalette = try? await WallpaperPaletteExtractor.extractPalette(fromImageAt: path)
        }
    }
}

private struct WeatherFilmstripThumbnail: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Shimmer()
            }
        }
        .frame(width: 60, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: ShrutzPalette.cornerRadiusThumbnail))
        .task(id: path) {
            image = await ThumbnailCache.shared.thumbnail(for: path)
        }
    }
}
