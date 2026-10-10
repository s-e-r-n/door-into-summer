import Foundation

enum PagingAction: Equatable {
    case showEarlierPage
    case showLastPage
}

struct PageWindow {
    private enum Zone {
        case top
        case middle
        case bottom
    }

    private var zone: Zone?

    mutating func scrolled(visible: CGRect, extent: CGRect, hasEarlierPage: Bool, showsEarlierPages: Bool) -> PagingAction? {
        let entered = Self.zone(visible: visible, extent: extent)
        defer { zone = entered }
        guard entered != zone else { return nil }
        switch entered {
        case .top where hasEarlierPage:
            return .showEarlierPage
        case .bottom where showsEarlierPages:
            return .showLastPage
        default:
            return nil
        }
    }

    private static func zone(visible: CGRect, extent: CGRect) -> Zone {
        if visible.maxY >= extent.maxY - 1 {
            return .bottom
        }
        if visible.minY < extent.minY + visible.height {
            return .top
        }
        return .middle
    }
}
