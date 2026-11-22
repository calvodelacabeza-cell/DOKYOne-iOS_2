import Foundation
import Combine
import CryptoKit

@MainActor final class ProgramLibrary: ObservableObject {
    @Published private(set) var programs: [ServiceProgram] = []
    @Published var message: String?

    private let folder: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("DokyONE/programas", isDirectory: true)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch { message = "No se pudo crear la biblioteca: \(error.localizedDescription)" }
        reload()
    }

    private func location(for id: String) -> URL {
        let sha = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(sha + ".dokyone")
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        programs = urls.filter { $0.pathExtension.lowercased() == "dokyone" }.compactMap {
            guard let pack = try? DokyPackageReader.open(url: $0) else { return nil }
            return pack.program
        }.sorted { ($0.date, $0.program_id) > ($1.date, $1.program_id) }
    }

    func importPackage(_ url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let incoming = try DokyPackageReader.open(url: url)
            let destination = location(for: incoming.program.program_id)
            if FileManager.default.fileExists(atPath: destination.path) {
                let old = try DokyPackageReader.open(url: destination)
                if incoming.program.revision < old.program.revision {
                    throw PackageError.invalid("Ya tienes una revisión más reciente del programa")
                }
                if incoming.program.revision == old.program.revision {
                    if incoming.manifest.program_sha256.caseInsensitiveCompare(old.manifest.program_sha256) == .orderedSame {
                        message = "Este programa ya está guardado"; return
                    }
                    throw PackageError.invalid("Misma revisión con letras diferentes. Solicita la versión más reciente")
                }
            }
            try incoming.bytes.write(to: destination, options: .atomic)
            reload()
            message = "Programa importado: \(incoming.program.name) · Revisión \(incoming.program.revision)"
        } catch { message = "No se pudo importar: \(error.localizedDescription)" }
    }

    func remove(_ program: ServiceProgram) {
        do {
            let url = location(for: program.program_id)
            // Evita borrar archivos ajenos o diferentes de los registrados en la biblioteca.
            let old = try DokyPackageReader.open(url: url)
            guard old.program.program_id == program.program_id else { throw PackageError.invalid("Identificador inconsistente") }
            try FileManager.default.removeItem(at: url)
            reload()
        } catch { message = "No se pudo eliminar: \(error.localizedDescription)" }
    }

    func isPastSunday(_ program: ServiceProgram) -> Bool {
        guard let date = Self.parseDate(program.date) else { return false }
        let calendar = Calendar(identifier: .gregorian)
        return calendar.component(.weekday, from: date) == 1 && date < calendar.startOfDay(for: Date())
    }

    var pastSundays: [ServiceProgram] { programs.filter(isPastSunday) }

    func removePastSundays() {
        for p in pastSundays { remove(p) }
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: string)
    }
}
