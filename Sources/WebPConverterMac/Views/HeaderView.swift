import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack {
            Text("Orlo — Batch Image Converter")

            Spacer()

            HStack(spacing: 12) {
                Button("Ajouter des fichiers") {}

                Button(action: {}) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}
