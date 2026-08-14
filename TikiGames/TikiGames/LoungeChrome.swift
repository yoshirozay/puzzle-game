import SwiftUI

/// Lounge screen-fixed chrome — wallet + SHOP top-trailing. Extracted from
/// LoungeView so chrome edits don't fight room / coach / shop work.
struct LoungeChrome: View {
    let coachOnShop: Bool
    let canAffordNewItem: Bool
    var onOpenShop: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    PointsChip(points: store.points)
                    shopButton
                }
            }
            .padding(.trailing, 20)
            .padding(.top, 66)
            Spacer()
        }
    }

    private var shopButton: some View {
        Button(action: onOpenShop) {
            Text("SHOP")
                .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.ink.color)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(P.torch.color))
                .overlay(alignment: .topTrailing) {
                    if canAffordNewItem {
                        Circle()
                            .fill(P.coral.color)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(P.ink.color, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .overlay {
            if coachOnShop {
                ZStack {
                    CoachPulse(skin: .lounge, diameter: 74)
                    CoachArrow(skin: .lounge, direction: .right, size: 26)
                        .offset(x: -46, y: 0)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
