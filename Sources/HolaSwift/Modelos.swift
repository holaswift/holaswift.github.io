// Los datos de datos/*.json. El generador los lee con JSONDecoder; la página, que es Embedded Swift (sin Codable),
// los monta campo a campo desde el objeto de JavaScript con los init de aquí.

public struct Persona {
    public let nombre, rol, foto, bio: String
    public let x, linkedin, web: String?
}

public struct Quedada {
    public let fecha, titulo: String
    public let notas, enlace: String?
    public let demo: Bool?
    public let charlas: [Charla]

    public init(fecha: String, titulo: String, notas: String?, enlace: String?, demo: Bool?, charlas: [Charla]) {
        self.fecha = fecha; self.titulo = titulo; self.notas = notas; self.enlace = enlace; self.demo = demo; self.charlas = charlas
    }
}

public struct Charla {
    public let titulo: String
    public let ponentes: [Ponente]?
    public let tipo, descripcion: String?
    public var esTaller: Bool { tipo.map { mismoTexto($0, "Taller") } ?? false }

    public init(titulo: String, ponentes: [Ponente]?, tipo: String?, descripcion: String?) {
        self.titulo = titulo; self.ponentes = ponentes; self.tipo = tipo; self.descripcion = descripcion
    }
}

public struct Ponente {
    public let nombre: String
    public let foto: String?

    public init(nombre: String, foto: String?) { self.nombre = nombre; self.foto = foto }
}

public struct Patrocinador {
    public let nombre, logo: String
    public let web: String?
}

// Codable no existe en Embedded Swift: solo lo usa el generador.
#if !hasFeature(Embedded)
extension Persona: Decodable {}
extension Quedada: Decodable {}
extension Charla: Decodable {}
extension Ponente: Decodable {}
extension Patrocinador: Decodable {}
#endif

/// Un instante con sus partes ya en hora de Madrid. Lo calcula quien tenga reloj: el generador con Foundation
/// y la página con Intl. Así la lógica de aquí no necesita Foundation y vale igual en los dos sitios.
public struct Momento {
    public let ms: Double
    public let anio, mes, dia, hora, minuto: Int       // en Madrid

    public init(ms: Double, anio: Int, mes: Int, dia: Int, hora: Int, minuto: Int) {
        self.ms = ms; self.anio = anio; self.mes = mes; self.dia = dia; self.hora = hora; self.minuto = minuto
    }

    public var diaNumero: Int { anio * 10_000 + mes * 100 + dia }
    public var horaMinuto: String { dosCifras(hora) + ":" + dosCifras(minuto) }
}

func dosCifras(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }

/// Compara dos textos byte a byte (UTF-8). `==` entre String tiene en cuenta la normalización de Unicode y, en Embedded
/// Swift, arrastra sus tablas (unos 700 KB); para comparar con palabras fijas como "Taller" no hace falta.
public func mismoTexto(_ a: String, _ b: String) -> Bool { a.utf8.elementsEqual(b.utf8) }
