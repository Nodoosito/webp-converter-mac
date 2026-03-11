import SwiftUI

@main
struct WebPConverterMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ConversionViewModel())
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowResizability(.contentSize)
    }
}
