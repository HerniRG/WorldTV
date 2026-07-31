import Foundation
import Observation

@Observable
@MainActor
final class ChannelDetailViewModel: LoadableViewModel<ChannelDetailContent> {
    private let channelID: String
    private let loadDetail: LoadChannelDetailUseCase

    init(channelID: String, loadDetail: LoadChannelDetailUseCase) {
        self.channelID = channelID
        self.loadDetail = loadDetail
        super.init(load: { [channelID, loadDetail] _ in
            try await loadDetail.execute(channelID: channelID)
        })
    }
}
