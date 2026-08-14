import SwiftUI

// MARK: - Points chip

struct PointsChip: View {
    let points: Int
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: 0.910, green: 0.702, blue: 0.235))
                .frame(width: 10, height: 10)
            Text("\(points)")
                .font(.custom("Futura-Bold", size: 16, relativeTo: .body))
                .foregroundStyle(Color(red: 0.910, green: 0.702, blue: 0.235))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(P.ink.color.opacity(0.55)))
    }
}

