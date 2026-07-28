import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            Section("about.worldtv") {
                Text("about.description")
                Text("about.availability")
            }

            Section("about.attribution") {
                Text("about.iptvOrg")
                if let destination = URL(string: "https://github.com/iptv-org") {
                    Link("about.openIPTVOrg", destination: destination)
                }
            }

            Section("about.legal") {
                Text("about.legalNotice")
            }
        }
        .navigationTitle("settings.about")
    }
}
