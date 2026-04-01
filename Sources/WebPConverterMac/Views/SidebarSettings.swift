import SwiftUI

struct SidebarSettings: View {
    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Réglages")
                    .font(.headline)

                Spacer()
            }
        }
        .frame(width: 260)
    }
}
