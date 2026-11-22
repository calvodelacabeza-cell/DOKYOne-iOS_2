import Foundation
import CryptoKit
import ZIPFoundation

/// Lee exclusivamente el formato oficial v1: manifest.json + program.json.
/// Verifica integridad, versiones, límites y rutas del ZIP; nunca ejecuta contenido.
enum DokyPackageReader {
    static let maxArchive = 20 * 1024 * 1024
    static let maxEntry = 16 * 1024 * 1024

    static func open(url: URL) throws -> VerifiedPackage {
        let bytes = try Data(contentsOf: url)
        guard !bytes.isEmpty && bytes.count <= maxArchive else { throw PackageError.invalid("Archivo demasiado grande o vacío") }
        return try open(bytes: bytes)
    }

    static func open(bytes: Data) throws -> VerifiedPackage {
        guard !bytes.isEmpty && bytes.count <= maxArchive else { throw PackageError.invalid("Tamaño de archivo inválido") }
        // La URL temporal es privada; ZIPFoundation valida los encabezados y CRC de cada entrada.
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".dokyone")
        try bytes.write(to: temp, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temp) }
        guard let archive = Archive(url: temp, accessMode: .read) else {
            throw PackageError.invalid("El archivo no es un paquete DOKYOne")
        }
        var members: [String: Data] = [:]
        var total = 0
        for entry in archive {
            guard entry.path == "manifest.json" || entry.path == "program.json",
                  entry.type == .file, members[entry.path] == nil else {
                throw PackageError.invalid("El paquete contiene archivos no permitidos")
            }
            guard UInt64(entry.uncompressedSize) <= UInt64(maxEntry) else {
                throw PackageError.invalid("Entrada comprimida demasiado grande")
            }
            var raw = Data()
            _ = try archive.extract(entry) { part in
                total += part.count
                guard total <= maxEntry * 2 else { throw PackageError.invalid("Paquete expandido demasiado grande") }
                raw.append(part)
            }
            members[entry.path] = raw
        }
        guard members.count == 2, let m = members["manifest.json"], let p = members["program.json"] else {
            throw PackageError.invalid("Faltan archivos del programa")
        }
        let manifest = try JSONDecoder().decode(DokyManifest.self, from: m)
        let program = try JSONDecoder().decode(ServiceProgram.self, from: p)
        guard manifest.format == "dokyone", program.format == "dokyone",
              manifest.schema_version == 1, program.schema_version == 1,
              manifest.revision > 0, manifest.revision == program.revision,
              manifest.program_id == program.program_id,
              !program.program_id.isEmpty, program.program_id.count < 256,
              manifest.song_count == program.songs.count, (1...2000).contains(program.songs.count)
        else { throw PackageError.invalid("Formato o revisión no compatible") }
        let actual = SHA256.hash(data: p).map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(manifest.program_sha256) == .orderedSame else {
            throw PackageError.invalid("Error de integridad del archivo")
        }
        for song in program.songs {
            guard !song.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (1...1000).contains(song.blocks.count) else { throw PackageError.invalid("Canto incompleto") }
        }
        return VerifiedPackage(manifest: manifest, program: program, bytes: bytes)
    }
}

enum PackageError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let why): return why }
    }
}
