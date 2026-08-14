import SwiftUI

/// The House Standing plaque. The six placeholder item sprites that used to
/// live here were replaced by the v2 asset delivery (assets/sprites-v2 ->
/// Assets.xcassets/Sprites); see LOUNGE_V2_PLAN.md Stage A.

struct HouseStandingPlaque: View {
    let standing: String

    var body: some View {
        // Fixed sizes per tier, not minimumScaleFactor — scale-to-fit does
        // not shrink tracking (same quirk the picker's top bar dodges).
        // Names past one line's worth engrave on TWO lines, split at the
        // space nearest the middle, so the apex standing reads whole:
        // NAME ON / THE DOOR — never "NAME ON THE…". A long SINGLE word
        // has no split point, so it engraves smaller on one line instead —
        // ISLANDER at 11 pt + tracking truncated to "ISLAN…" (device round).
        let splittable = standing.contains(" ")
        let long = standing.count > 9 && splittable
        let squeeze = !splittable && standing.count > 7
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(P.driftwood.color)
            RoundedRectangle(cornerRadius: 3)
                .stroke(P.ink.color.opacity(0.8), lineWidth: 1.5)
                .padding(3)
            HStack {
                Circle().fill(P.torch.color).frame(width: 3.5, height: 3.5)
                Spacer()
                Circle().fill(P.torch.color).frame(width: 3.5, height: 3.5)
            }
            .padding(.horizontal, 7)
            if long {
                let lines = Self.engravedLines(standing)
                VStack(spacing: 0) {
                    Text(lines.0)
                    Text(lines.1)
                }
                .font(.custom("Futura-Bold", fixedSize: 7.5))
                .tracking(0.5)
                .foregroundStyle(P.cream.color)
                .lineLimit(1)
                .padding(.horizontal, 12)
            } else {
                Text(standing)
                    .font(.custom("Futura-Bold", fixedSize: squeeze ? 9 : 11))
                    .tracking(squeeze ? 1.0 : 1.5)
                    .foregroundStyle(P.cream.color)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }
        }
        .accessibilityLabel("House standing: \(standing)")
    }

    /// Split a long standing at the space nearest its middle.
    static func engravedLines(_ name: String) -> (String, String) {
        let mid = name.count / 2
        let spaces = name.indices.filter { name[$0] == " " }
        guard let split = spaces.min(by: {
            abs(name.distance(from: name.startIndex, to: $0) - mid)
                < abs(name.distance(from: name.startIndex, to: $1) - mid)
        }) else { return (name, "") }
        return (
            String(name[..<split]),
            String(name[name.index(after: split)...])
        )
    }
}
