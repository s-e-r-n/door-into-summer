import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class ReviewPage {
    enum Availability {
        case connecting
        case unanswered
        case shown
    }

    static let reviewServerAddress = URL(string: "http://127.0.0.1:8765/")!

    private(set) var availability = Availability.connecting
    let page = WebPage()
    private let address: URL
    private let retryDelay = Duration.seconds(1)

    init(address: URL = reviewServerAddress) {
        self.address = address
    }

    func open() async {
        while !Task.isCancelled {
            if await loaded() {
                availability = .shown
                return
            }
            availability = .unanswered
            try? await Task.sleep(for: retryDelay)
        }
    }

    private func loaded() async -> Bool {
        do {
            for try await _ in page.load(address) {}
            return true
        } catch {
            return false
        }
    }
}
