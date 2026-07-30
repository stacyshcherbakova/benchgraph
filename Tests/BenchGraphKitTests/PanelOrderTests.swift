import Testing
import Foundation
@testable import BenchGraphKit

/// Reorder index arithmetic. A drag lands a panel at an absolute position, which
/// is a remove-then-insert — the classic off-by-one when moving rightwards.
@Suite struct PanelOrderTests {

    @Test func movingRightCorrectsForTheRemoval() {
        // A B C D, drag A to position 2 → B C A D
        #expect(PanelOrder.moved(count: 4, from: 0, to: 2) == [1, 2, 0, 3])
    }

    @Test func movingLeftNeedsNoCorrection() {
        // A B C D, drag D to position 1 → A D B C
        #expect(PanelOrder.moved(count: 4, from: 3, to: 1) == [0, 3, 1, 2])
    }

    @Test func movingToItsOwnPositionIsIdentity() {
        for i in 0..<4 {
            #expect(PanelOrder.moved(count: 4, from: i, to: i) == [0, 1, 2, 3])
        }
    }

    @Test func movingToTheEnds() {
        #expect(PanelOrder.moved(count: 4, from: 2, to: 0) == [2, 0, 1, 3])
        #expect(PanelOrder.moved(count: 4, from: 1, to: 3) == [0, 2, 3, 1])
    }

    /// Out-of-range destinations clamp rather than trapping.
    @Test func destinationsClamp() {
        #expect(PanelOrder.moved(count: 3, from: 0, to: 99) == [1, 2, 0])
        #expect(PanelOrder.moved(count: 3, from: 2, to: -5) == [2, 0, 1])
    }

    @Test func degenerateInputsAreSafe() {
        #expect(PanelOrder.moved(count: 0, from: 0, to: 0) == [])
        #expect(PanelOrder.moved(count: 1, from: 0, to: 0) == [0])
        #expect(PanelOrder.moved(count: 3, from: 7, to: 1) == [0, 1, 2])
    }

    /// Exhaustive: every move on every small array must be a permutation that
    /// preserves every element exactly once, and must place the moved element
    /// where the caller asked.
    @Test func everySmallMoveIsAValidPermutation() {
        for count in 1...6 {
            for from in 0..<count {
                for to in 0..<count {
                    let order = PanelOrder.moved(count: count, from: from, to: to)
                    #expect(order.count == count)
                    #expect(Set(order) == Set(0..<count), "lost or duplicated an element")
                    #expect(order.firstIndex(of: from) == PanelOrder.insertionIndex(
                        count: count, from: from, to: to))
                }
            }
        }
    }
}
