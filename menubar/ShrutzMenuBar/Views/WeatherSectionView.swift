import SwiftUI

struct WeatherSectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var locationInput = ""

    var body: some View {
        Form {
            if let weather = appState.weather {
                Toggle("Weather auto-switching", isOn: Binding(
                    get: { weather.enabled },
                    set: { newValue in Task { await appState.setWeatherEnabled(newValue) } }
                ))

                LabeledContent("Location", value: weather.location.isEmpty ? "not set" : weather.location)

                if weather.condition.isEmpty {
                    LabeledContent("Condition", value: "none yet")
                } else if let temp = weather.temperatureF {
                    LabeledContent("Condition", value: "\(weather.condition), \(Int(temp))°F")
                } else {
                    LabeledContent("Condition", value: weather.condition)
                }

                LabeledContent("Last checked", value: weather.lastChecked.isEmpty ? "never" : weather.lastChecked)
            } else {
                Text("Weather status unavailable")
            }

            HStack {
                TextField("City name or lat,lon", text: $locationInput)
                Button("Set Location") {
                    Task {
                        await appState.setWeatherLocation(locationInput)
                        locationInput = ""
                    }
                }
                .disabled(locationInput.isEmpty)
            }

            Text("Map conditions to your own sets from the terminal: shrutz weather map <condition> <set>")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
