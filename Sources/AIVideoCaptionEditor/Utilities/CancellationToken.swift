import Foundation

final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var isFlagged = false

    func cancel() {
        lock.lock()
        isFlagged = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        let value = isFlagged
        lock.unlock()
        return value
    }
}
