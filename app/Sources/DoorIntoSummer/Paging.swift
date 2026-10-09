import SwiftUI

enum PagingAction: Equatable {
    case showEarlierPage
    case showLastPage
    case scrollTo(CGFloat)
}

struct PageWindow {
    private enum Zone {
        case top
        case middle
        case bottom
    }

    private enum Join {
        case requested
        case compensated(CGFloat)
    }

    private var zone: Zone?
    private var join: Join?

    mutating func scrolled(from before: ScrollGeometry, to now: ScrollGeometry, hasEarlierPage: Bool, showsEarlierPages: Bool) -> PagingAction? {
        switch join {
        case .requested:
            let added = now.contentSize.height - before.contentSize.height
            guard added != 0 else { return nil }
            let settled = max(0, now.contentOffset.y + added)
            join = .compensated(settled)
            return .scrollTo(settled)
        case .compensated(let settled):
            guard abs(now.contentOffset.y - settled) < 1 else { return nil }
            join = nil
            zone = nil
        case nil:
            break
        }
        let entered = Self.zone(of: now)
        defer { zone = entered }
        guard entered != zone else { return nil }
        switch entered {
        case .top where hasEarlierPage:
            join = .requested
            return .showEarlierPage
        case .bottom where showsEarlierPages:
            return .showLastPage
        default:
            return nil
        }
    }

    private static func zone(of geometry: ScrollGeometry) -> Zone {
        if geometry.visibleRect.maxY >= geometry.contentSize.height - 1 {
            return .bottom
        }
        if geometry.visibleRect.minY < geometry.visibleRect.height {
            return .top
        }
        return .middle
    }
}
