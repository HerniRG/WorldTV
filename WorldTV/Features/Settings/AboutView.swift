import SwiftUI

struct AboutView: View {
    var body: some View {
        Form {
            #if os(tvOS)
            TVScreenHeader("settings.about", systemImage: "info.circle")
                .listRowBackground(Color.clear)
            #endif

            Section("about.worldtv") {
                Text("about.description")
                Text("about.availability")
            }

            Section("about.attribution") {
                Text("about.iptvOrg")
                if let destination = AboutDestination.iptvOrg.url {
                    Link("about.openIPTVOrg", destination: destination)
                }
                if let destination = AboutDestination.sourceCode.url {
                    Link("about.sourceCode", destination: destination)
                }
                if let destination = AboutDestination.support.url {
                    Link("about.support", destination: destination)
                }
            }

            Section("about.legal") {
                Text("about.legalNotice")
                if let destination = AboutDestination.privacy.url {
                    Link("about.privacy", destination: destination)
                }
                if let destination = AboutDestination.disclaimer.url {
                    Link("about.disclaimer", destination: destination)
                }
                if let destination = AboutDestination.channelRemoval.url {
                    Link("about.channelRemoval", destination: destination)
                }
            }
        }
        .platformNavigationTitle("settings.about")
    }
}

enum AboutDestination: String, CaseIterable {
    case iptvOrg = "https://github.com/iptv-org"
    case sourceCode = "https://github.com/HerniRG/WorldTV"
    case support = "https://github.com/HerniRG/WorldTV/blob/main/SUPPORT.md"
    case privacy = "https://github.com/HerniRG/WorldTV/blob/main/PRIVACY.md"
    case disclaimer = "https://github.com/HerniRG/WorldTV/blob/main/DISCLAIMER.md"
    case channelRemoval =
        "https://github.com/HerniRG/WorldTV/issues/new?template=channel-removal.yml"

    var url: URL? {
        URL(string: rawValue)
    }
}
