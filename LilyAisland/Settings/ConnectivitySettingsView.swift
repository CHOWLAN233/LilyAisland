import SwiftUI

struct ConnectivitySettingsView: View {
    @AppStorage("connectivity_enabled") private var isConnectivityEnabled = true
    @AppStorage("connectivity_show_device_name") private var showDeviceName = true

    private var loc: LocalizationManager { LocalizationManager.shared }

    var body: some View {
        Form {
            HStack {
                Image(systemName: "headphones")
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(loc.loc(.connectivity_title))
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom, 10)

            Section {
                Toggle(loc.loc(.connectivity_enable_alerts), isOn: $isConnectivityEnabled)
                    .toggleStyle(.switch)

                Toggle(loc.loc(.connectivity_show_device_name), isOn: $showDeviceName)
                    .toggleStyle(.switch)
                    .disabled(!isConnectivityEnabled)
            }
        }
        .padding(30)
        .formStyle(.grouped)
    }
}
