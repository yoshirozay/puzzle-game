import SwiftUI

// MARK: - Geometry

/// PICKER_SPEC §1/§9: card width is a fraction of screen width; vertical
/// bands are fixed and the media window absorbs all height difference.
/// All values in safe-area container coordinates.
struct Metrics {
    let w: CGFloat
    let containerH: CGFloat
    let safeBottom: CGFloat
    let plateH: CGFloat
    let footerH: CGFloat

    var cardW: CGFloat { (w * 0.78).rounded() }
    var spacing: CGFloat { 14 }
    var margin: CGFloat { (w - cardW) / 2 }
    var railTop: CGFloat { 63 }
    var boardTop: CGFloat { 99 }
    var boardBottom: CGFloat { containerH - (safeBottom > 0 ? 73 : 57) }
    var boardH: CGFloat { boardBottom - boardTop }
    var cardH: CGFloat { boardH + 26 }
    var windowW: CGFloat { cardW - 28 }
    /// Fixed bands never compress; the window absorbs all difference.
    var windowH: CGFloat { boardH - (plateH + 4 + 6) - footerH }
    var stripCenterY: CGFloat { boardBottom + 33 }
}

// MARK: - Scroll preferences

// Optional-valued so sibling views contributing the default can never
// clobber the one real source (last-wins reduce with a non-optional
// default silently zeroes these out).
struct RailMinXKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        if let next = nextValue() { value = next }
    }
}

struct WindowFramesKey: PreferenceKey {
    static let defaultValue: [TikiGame: CGRect] = [:]
    static func reduce(value: inout [TikiGame: CGRect], nextValue: () -> [TikiGame: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct FullRectKey: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        if let next = nextValue() { value = next }
    }
}

