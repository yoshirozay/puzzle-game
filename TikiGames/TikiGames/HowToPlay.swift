import SwiftUI

/// Reusable "how to play" chrome shared by all games: a flat "?" button and
/// a shop-style panel — wood header, cream body, illustrated rule rows,
/// GOT IT capsule. Content is per-game; the frame never changes.
struct HowToRule: Identifiable {
    let id = UUID()
    /// Either a catalog image or an SF Symbol name for the row's icon.
    var image: Image?
    var symbol: String?
    var text: String
}

struct HowToPlayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("?")
                .font(.custom("Futura-Bold", size: 20, relativeTo: .body))
                .foregroundStyle(P.blossom.color)
                .frame(width: 44, height: 44)
                .background(Circle().fill(P.ink.color.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("How to play")
    }
}

struct HowToPlayPanel: View {
    let title: String
    let rules: [HowToRule]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            P.ink.color.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 0) {
                Text(title)
                    .font(.custom("Futura-Bold", size: 18, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(P.blossom.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(P.woodDark.color)
                VStack(spacing: 18) {
                    ForEach(rules) { rule in
                        HStack(spacing: 14) {
                            Group {
                                if let image = rule.image {
                                    image
                                        .resizable()
                                        .scaledToFit()
                                } else if let symbol = rule.symbol {
                                    Image(systemName: symbol)
                                        .font(.system(size: 26, weight: .bold))
                                        .foregroundStyle(P.woodDark.color)
                                }
                            }
                            .frame(width: 46, height: 46)
                            Text(rule.text)
                                .font(.custom("Futura-Medium", size: 14, relativeTo: .body))
                                .tracking(0.5)
                                .foregroundStyle(P.woodDark.color)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                    Button(action: onDismiss) {
                        Text("GOT IT")
                            .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                            .tracking(2.5)
                            .foregroundStyle(P.ink.color)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 11)
                            .background(Capsule().fill(P.torch.color))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .background(P.cream.color)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(P.ink.color, lineWidth: 2)
            )
            .padding(.horizontal, 30)
        }
    }
}
