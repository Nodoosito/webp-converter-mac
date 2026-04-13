import SwiftUI

struct HeaderView: View {
    let onAddFiles: () -> Void
    let onSettings: () -> Void
    @Binding var appTheme: Int

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color(hex: "#6F98B9"))

                Text("Batch Image converter")
                    .font(.system(size: 44 / 2, weight: .medium))
                    .foregroundStyle(Color(hex: "#476E8D"))
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onAddFiles) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                        Text("Ajouter des fichiers")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#8DB3CE").opacity(0.8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Button {
                        appTheme = appTheme == 1 ? 0 : 1
                    } label: {
                        Image(systemName: "sun.max.fill")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button {
                        appTheme = appTheme == 2 ? 0 : 2
                    } label: {
                        Image(systemName: "moon.fill")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#C8D6E0"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}
