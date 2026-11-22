import SwiftUI
import UniformTypeIdentifiers

private enum DokyTheme {
    static let bg = Color(red: 0.035, green: 0.075, blue: 0.13)
    static let panel = Color(red: 0.065, green: 0.17, blue: 0.22)
    static let aqua = Color(red: 0.37, green: 0.88, blue: 0.79)
}

struct BrandHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("DokyMark").resizable().scaledToFit().frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("DOKYOne").font(.title2.bold()).foregroundStyle(.white)
                Text("Iglesia Bíblica Vida Abundante").font(.caption).foregroundStyle(DokyTheme.aqua)
            }
            Spacer(minLength: 0)
        }
    }
}

struct ProgramsView: View {
    @EnvironmentObject private var library: ProgramLibrary
    @State private var openPicker = false
    @State private var removeID: String?
    @State private var confirmPast = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BrandHeader().padding(.bottom, 8)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mis programas").font(.largeTitle.bold()).foregroundStyle(.white)
                        Text("Los cantos del servicio, organizados para tu lectura personal.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.65))
                    }
                    Button { openPicker = true } label: {
                        Label("Abrir archivo de WhatsApp / Archivos", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity).padding(15)
                    }.buttonStyle(.borderedProminent).tint(DokyTheme.aqua).foregroundStyle(DokyTheme.bg)

                    if !library.pastSundays.isEmpty {
                        Button(role: .destructive) { confirmPast = true } label: {
                            Label("Eliminar domingos anteriores (\(library.pastSundays.count))", systemImage: "trash")
                        }.font(.subheadline)
                    }

                    if library.programs.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "music.note.list").font(.system(size: 30)).foregroundStyle(DokyTheme.aqua)
                            Text("Sin programas guardados").font(.headline)
                            Text("Recibe un documento .dokyone e impórtalo aquí.").font(.caption)
                                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
                        }.frame(maxWidth: .infinity).padding(25)
                    } else {
                        ForEach(library.programs) { program in
                            VStack(alignment: .leading, spacing: 13) {
                                Text(program.date).font(.caption.bold()).foregroundStyle(DokyTheme.aqua)
                                Text(program.name).font(.title3.bold())
                                Text("\(program.songs.count) cantos · Revisión \(program.revision)")
                                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                                NavigationLink {
                                    SongsView(program: program)
                                } label: {
                                    Label("Abrir listado de cantos", systemImage: "book")
                                        .frame(maxWidth: .infinity).padding(12)
                                }.buttonStyle(.borderedProminent).tint(DokyTheme.aqua).foregroundStyle(DokyTheme.bg)
                                Button(role: .destructive) { removeID = program.id } label: {
                                    Label("Eliminar este programa", systemImage: "trash")
                                }.font(.subheadline)
                            }
                            .padding(17)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DokyTheme.panel, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }.padding(18)
            }
            .background(DokyTheme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(isPresented: $openPicker, allowedContentTypes: [.dokyonePackage, .zip, .data]) { result in
                switch result {
                case .success(let url): library.importPackage(url)
                case .failure(let err): library.message = "No se abrió el archivo: \(err.localizedDescription)"
                }
            }
            .alert("DOKYOne", isPresented: Binding(get: { library.message != nil }, set: { if !$0 { library.message = nil } })) {
                Button("Aceptar") { library.message = nil }
            } message: { Text(library.message ?? "") }
            .confirmationDialog("Eliminar programa", isPresented: Binding(get: { removeID != nil }, set: { if !$0 { removeID = nil } }), titleVisibility: .visible) {
                Button("Eliminar de este iPhone", role: .destructive) {
                    if let id = removeID, let p = library.programs.first(where: { $0.id == id }) { library.remove(p) }
                    removeID = nil
                }
                Button("Cancelar", role: .cancel) { removeID = nil }
            } message: { Text("Se eliminará únicamente el programa seleccionado de DOKYOne. DOKY en la computadora no cambia.") }
            .confirmationDialog("¿Eliminar todos los domingos anteriores?", isPresented: $confirmPast, titleVisibility: .visible) {
                Button("Eliminar \(library.pastSundays.count) programas", role: .destructive) { library.removePastSundays() }
                Button("Cancelar", role: .cancel) {}
            } message: { Text("Solamente domingos anteriores a hoy. Los programas actuales y futuros se conservan.") }
        }
    }
}

struct SongsView: View {
    let program: ServiceProgram
    @State private var filter = 0
    @State private var sort = 0

    private var shown: [Int] {
        let indices = program.songs.indices.filter { index in
            let hymn = program.songs[index].type.lowercased() == "himno"
            return filter == 0 || (filter == 1 && !hymn) || (filter == 2 && hymn)
        }
        guard sort != 0 else { return indices } // Nunca altera el orden original del culto
        func titleKey(_ index: Int) -> String {
            program.songs[index].title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        if sort == 1 { return indices.sorted { titleKey($0) < titleKey($1) } }
        return indices.sorted { a, b in
            let x = program.songs[a], y = program.songs[b]
            let aHymn = x.type.lowercased() == "himno", bHymn = y.type.lowercased() == "himno"
            if aHymn != bHymn { return aHymn }
            if aHymn, bHymn {
                let xNo = Int(x.number ?? "") ?? Int.max, yNo = Int(y.number ?? "") ?? Int.max
                if xNo != yNo { return xNo < yNo }
            }
            return titleKey(a) < titleKey(b)
        }
    }
    var body: some View {
        List {
            Section("Biblioteca del servicio") {
                Picker("Mostrar", selection: $filter) {
                    Text("Todos").tag(0)
                    Text("Cantos / Coros").tag(1)
                    Text("Himnos").tag(2)
                }
                Picker("Ordenar", selection: $sort) {
                    Text("Orden del servicio").tag(0)
                    Text("Nombre A–Z").tag(1)
                    Text("Número de himno").tag(2)
                }
            }
            Section("Cantos") {
                ForEach(shown, id: \.self) { idx in
                    let hymn = program.songs[idx]
                    NavigationLink {
                        LyricsView(hymn: hymn)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(hymn.kindLabel).font(.caption).foregroundStyle(DokyTheme.aqua)
                            Text(hymn.title).font(.headline)
                        }.padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle(program.name)
        .scrollContentBackground(.hidden)
        .background(DokyTheme.bg)
    }
}

struct LyricsView: View {
    let hymn: Hymn
    @State private var index = 0
    @State private var fontSize: CGFloat = 26
    private var blocks: [HymnBlock] { hymn.blocks }

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hymn.kindLabel).font(.caption.bold()).foregroundStyle(DokyTheme.aqua)
                    Text(hymn.title).font(.title3.bold()).lineLimit(2)
                }
                Spacer(minLength: 2)
                Button("A−") { fontSize = max(16, fontSize - 2) }.disabled(fontSize <= 16)
                    .buttonStyle(.bordered)
                Button("A+") { fontSize = min(42, fontSize + 2) }.disabled(fontSize >= 42)
                    .buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 10) {
                if !blocks.isEmpty {
                    Text(blocks[index].label).font(.subheadline.bold()).foregroundStyle(DokyTheme.aqua)
                    ScrollView {
                        Text(blocks[index].text)
                            .font(.system(size: fontSize, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .padding(.vertical, 40)
                            .id(index)
                    }.id(index)
                }
            }
            .padding(19)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DokyTheme.panel, in: RoundedRectangle(cornerRadius: 22))
            Text("Diapositiva \(min(index+1,blocks.count)) de \(blocks.count)")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 12) {
                Button("← Anterior") { index = max(0,index-1) }.disabled(index == 0)
                Button("Siguiente →") { index = min(blocks.count-1,index+1) }.disabled(index+1 >= blocks.count)
            }.buttonStyle(.borderedProminent).tint(DokyTheme.aqua)
                .foregroundStyle(DokyTheme.bg)
                .frame(maxWidth: .infinity)
        }
        .padding(17)
        .background(DokyTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
