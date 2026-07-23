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
        case .clear: return [Color(hex: 0x4A90D9), Color(hex: 0xE8C468)]
        case .cloudy: return [Color(hex: 0xB8BCC2), Color(hex: 0xD8DADD)]
        case .fog: return [Color(hex: 0xCFCFC9), Color(hex: 0xE8E8E3)]
        case .rain: return [Color(hex: 0x3E5C76), Color(hex: 0x1F3A52)]
        case .snow: return [Color(hex: 0xFFFFFF), Color(hex: 0xC9DCEA)]
        case .storm: return [Color(hex: 0x3A3A42), Color(hex: 0x6B4E8E)]
        case .night: return [Color(hex: 0x2C2F5A), Color(hex: 0x0F1330)]
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
            Text("Enable auto-switching?")
                .font(.shrutzSerif(22, weight: .semibold))
                .foregroundColor(ShrutzPalette.navy)
            Text("Set a location once, then map weather conditions to your own wallpaper sets — the daemon switches automatically as the weather changes.")
                .font(.shrutzSans(13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            TextField("City name or lat,lon", text: $locationInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)

            HStack(spacing: 12) {
                Button("Yes") { Task { await enable() } }
                    .buttonStyle(.borderedProminent)
                Button("Why not, yes!") { Task { await enable() } }
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
        VStack(spacing: 0) {
            conditionSelector
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(LinearGradient(colors: selectedCondition.tint, startPoint: .topLeading, endPoint: .bottomTrailing))

            setPicker
                .frame(maxWidth: .infinity)
                .frame(minHeight: 180)
        }
    }

    private var conditionSelector: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
            ForEach(WeatherCondition.allCases, id: \.self) { condition in
                Button {
                    selectedCondition = condition
                } label: {
                    VStack(spacing: 4) {
                        Text(condition.label)
                            .font(.shrutzSans(12, weight: condition == selectedCondition ? .semibold : .regular))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.white.opacity(condition == selectedCondition ? 0.35 : 0.12))
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    private var setPicker: some View {
        Group {
            if let mappedSetName {
                MappedSetTintedView(setName: mappedSetName, condition: selectedCondition) {
                    Task { await appState.unmapWeather(condition: selectedCondition.rawValue) }
                }
            } else {
                unmappedPicker
            }
        }
    }

    private var unmappedPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Map \(selectedCondition.label.lowercased()) to a set")
                .font(.shrutzSerif(15, weight: .medium))
                .foregroundColor(ShrutzPalette.navy)
            if appState.sets.isEmpty {
                Text("No sets yet.").foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.sets) { set in
                            Button(set.name) {
                                Task { await appState.mapWeather(condition: selectedCondition.rawValue, set: set.name) }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ShrutzPalette.controlBackground)
    }
}

/// Once a condition is mapped to a set, extract that set's palette (reusing
/// the same native extractor and blob-wash renderer as the live tinting
/// engine) and compose a considered multi-colour tint rather than a flat
/// color — deliberately reused for visual/implementation consistency.
private struct MappedSetTintedView: View {
    let setName: String
    let condition: WeatherCondition
    let onUnmap: () -> Void

    @EnvironmentObject var appState: AppState
    @State private var palette: WallpaperPalette?

    private var representativeImagePath: String? {
        appState.sets.first(where: { $0.name == setName })?.imagePaths.first
    }

    var body: some View {
        ZStack {
            FrostedTintBackground(palette: palette)
            VStack(spacing: 8) {
                Text(setName)
                    .font(.shrutzSerif(18, weight: .medium))
                    .foregroundColor(ShrutzPalette.navy)
                Button("Unmap", action: onUnmap)
            }
        }
        .task(id: representativeImagePath) {
            guard let path = representativeImagePath else { palette = nil; return }
            palette = try? await WallpaperPaletteExtractor.extractPalette(fromImageAt: path)
        }
    }
}
