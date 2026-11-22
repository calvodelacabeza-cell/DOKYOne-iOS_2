import SwiftUI
import UniformTypeIdentifiers

@main
struct DokyONEApp: App {
    @StateObject private var library = ProgramLibrary()
    var body: some Scene {
        WindowGroup {
            ProgramsView().environmentObject(library)
                .onOpenURL { url in library.importPackage(url) }
                .preferredColorScheme(.dark)
        }
    }
}

extension UTType {
    static var dokyonePackage: UTType { UTType(importedAs: "com.ibva.dokyone.package") }
}
