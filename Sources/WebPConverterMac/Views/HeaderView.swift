import SwiftUI

struct HeaderView: View {
    let onAddFiles: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Text("Orlo — Batch Image Converter")

            Spacer()

            HStack(spacing: 12) {
                Button("Ajouter des fichiers", action: onAddFiles)

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}
