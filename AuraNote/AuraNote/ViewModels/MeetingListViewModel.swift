import SwiftUI

/// 会议列表 ViewModel
@MainActor
@Observable
final class MeetingListViewModel {

    var meetings: [Meeting] = []
    var isLoading = false

    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func loadMeetings() {
        isLoading = true
        meetings = databaseManager.fetchAllMeetings()
        isLoading = false
    }
}
