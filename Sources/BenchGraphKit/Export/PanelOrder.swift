import Foundation

/// Index arithmetic for reordering staged multi-panel figures.
///
/// Lives in the engine (not the UI) so the off-by-one that a remove-then-insert
/// reorder invites is unit-testable, the same reason `EditGrid` sits here.
public enum PanelOrder {

    /// The array index to insert at, after removing the element at `from`, so
    /// that the element lands at visual position `to`.
    ///
    /// Dropping a card onto another means "put the dragged panel where that one
    /// is", i.e. the destination is a *final position*. Removing first shortens
    /// the array by one, which exactly cancels the rightward shift — so the
    /// insertion index is the destination itself, with no correction. (Applying
    /// the off-by-one correction that an insert-*before-element* API would need
    /// lands the panel one place short; `PanelOrderTests` pins this.)
    public static func insertionIndex(count: Int, from: Int, to: Int) -> Int {
        guard count > 0, from >= 0, from < count else { return from }
        return Swift.max(0, Swift.min(count - 1, to))
    }

    /// The order `indices` takes after moving the element at `from` to visual
    /// position `to`. Used to verify the arithmetic independently of any array
    /// of panels.
    public static func moved(count: Int, from: Int, to: Int) -> [Int] {
        guard count > 0, from >= 0, from < count else { return Array(0..<Swift.max(0, count)) }
        var order = Array(0..<count)
        let insertAt = insertionIndex(count: count, from: from, to: to)
        let moving = order.remove(at: from)
        order.insert(moving, at: insertAt)
        return order
    }
}
