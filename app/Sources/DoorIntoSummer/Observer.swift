import Observation

@MainActor
final class Observer<Value> {
    private let snapshot: @MainActor () -> Value
    private let apply: @MainActor (Value) -> Void
    private let invalidate: @MainActor () -> Void
    private var armed = false

    init(read: @escaping @MainActor () -> Value, apply: @escaping @MainActor (Value) -> Void, invalidate: @escaping @MainActor () -> Void) {
        self.snapshot = read
        self.apply = apply
        self.invalidate = invalidate
    }

    func read() {
        guard !armed else { return }
        armed = true
        let value = withObservationTracking { snapshot() } onChange: { [self] in MainActor.assumeIsolated { changed() } }
        apply(value)
    }

    private func changed() {
        armed = false
        invalidate()
    }
}
