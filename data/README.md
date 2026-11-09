# Datos de la web

El equipo y las sesiones de la web salen de estos archivos. Para cambiar algo se edita el JSON (no el HTML) y se pasa el generador, que lo escribe en `index.html`:

    swift run generate

Solo toca lo que hay entre las marcas `<!-- generated:… -->` y `<!-- /generated:… -->` de `index.html`; el resto de la página no se toca. Antes de escribir nada comprueba los datos y, si algo no cuadra, dice qué y dónde (`ambassadors.json #3: falta "bio"`).

| Archivo | Qué pinta |
|---|---|
| `founders.json` | Las tarjetas de founders: las mismas tarjetas de colección que los embajadores, más grandes |
| `ambassadors.json` | La rejilla de embajadores: tarjetas de colección; al pulsar una se gira y enseña la bio y los enlaces |
| `meetups.json` | Las sesiones online: sus carteles y su tarjeta, con «Apúntame a la sesión» y «Suscríbete al calendario»; también `sesiones.ics`, el calendario al que se suscribe la gente |
| `sponsors.json` | Los logos del muro de la sección de patrocinio |

`examples/` guarda copias de datos de ejemplo (por ejemplo, las sesiones de prueba en `examples/meetups.json`): el generador no las lee y no se publican. Para volver a verlas en la web, se copian encima del archivo de verdad y se pasa el generador.

El orden del archivo es el orden en la web, salvo en dos casos: las sesiones se ordenan solas por fecha, y los embajadores se barajan en cada visita para que nadie salga siempre primero (en el HTML se quedan en el orden del JSON).

Los nombres de los archivos y de los campos van en inglés, como el código; los textos (nombres, bios, títulos), en español.

## Personas (`founders.json` y `ambassadors.json`)

```json
{
  "name": "Julio César Fernández Muñoz",
  "role": "Evangelista · Apple Coding Academy",
  "photo": "assets/equipo/julio-cesar-fernandez-munoz.webp",
  "bio": "Apple Technical Partner y evangelista en desarrollo Apple e IA. …",
  "x": "https://x.com/jcfmunoz",
  "linkedin": "https://www.linkedin.com/in/jcfmunoz/",
  "web": "https://acoding.academy",
  "since": 2026
}
```

- `name`, `role`, `photo` y `bio` son obligatorios. `x`, `linkedin` y `web` son opcionales: si falta uno, no sale su icono.
- `since`: el año en que entra (opcional, por defecto 2026). Sale en el pie de su ficha: «Serie fundacional» a la izquierda para 2026, «Serie» para los demás años, y el año a la derecha. A quien entre en 2027 se le pone `"since": 2027`.
- `role`: «Rol · Empresa», corto. En la web salen en dos líneas, sin el punto, y el rol en negrita.
- `bio`: en tercera persona, 2 o 3 frases (ver `DESIGN.md`).
- `quote` (solo embajadores, opcional): una frase corta suya, que sale en la tarjeta debajo del nombre en lugar del rol. Si no la tiene o está vacía, la tarjeta solo enseña el nombre.
- `photo`: WebP de 800 × 1000 (4:5) en `assets/equipo/`, con el nombre en minúsculas y guiones. Cada foto necesita también su cara (`assets/caras/`, mismo nombre), que sale en la ficha al girar la tarjeta: se hace con `swift scripts/caras.swift assets/equipo/nombre.webp`, y el generador avisa si falta.
- Founders y embajadores salen como tarjetas de colección, un poco desordenadas, como dejadas sobre la mesa. Al pulsar una, se gira y enseña la bio y los enlaces.
- En embajadores, si hay 4, 8, 12… personas, el hueco de «Muy pronto» se esconde solo para no ocupar una fila él solo.

## Sesiones (`meetups.json`)

Cada sesión tiene su propio título y de 1 a 3 presentaciones, de 20 minutos como mucho cada una.

```json
{
  "date": "2026-11-18T19:00:00+01:00",
  "title": "Empezar con SwiftUI",
  "notes": "Tres presentaciones cortas para empezar con SwiftUI.",
  "link": "https://discord.gg/…",
  "demo": false,
  "talks": [
    {
      "title": "Tu primera app con SwiftUI",
      "speakers": [{ "name": "Lucía Gómez", "photo": "assets/caras/lucia-gomez.webp" }],
      "description": "Empezamos con un proyecto vacío en Xcode…"
    },
    {
      "title": "SwiftData en una app de verdad",
      "speakers": [
        { "name": "Pol Piella Abadia", "photo": "assets/equipo/pol-piella-abadia.webp" },
        { "name": "Asier G. Morato" }
      ],
      "type": "workshop"
    }
  ]
}
```

- **Sesión:** `date` y `talks` son obligatorios; `title` (el tema) se puede dejar sin poner mientras no esté: en las sesiones sale tapado, como un spoiler, con «Próximamente» escrito a mano; `notes` (para toda la sesión), `link`, `demo` y `openSlot` son opcionales.
- La fecha va con zona horaria: `+01:00` en invierno y `+02:00` en verano (hora de España peninsular). En la web solo se enseña la hora de empezar.
- **Presentación:** `title` es opcional: sin él, el tema sale tapado como un spoiler hasta que lo pongáis. `speakers` es una lista de hasta 3 personas; vacía o sin poner, sale «Ponente por confirmar» con un círculo gris. `description` es opcional. `summary` también: una frase corta (unos 90 caracteres) que sale en el cartel de la sesión, para quien no la abre.
- **Ponente:** `name` es obligatorio y `photo` opcional. Las fotos salen en círculos apilados a la izquierda de la presentación; sin foto, sale un círculo gris con sus iniciales.
- Las fotos de ponentes son caras de `assets/caras/` (cuadradas, 256 × 256), no la foto grande: achicada a un círculo tan pequeño se rompe. Se hacen con `swift scripts/caras.swift assets/equipo/lucia-gomez.webp` a partir de su foto de 800 × 1000, también para quien no es del equipo (su foto grande va igualmente en `assets/equipo/`). Ver «Fotos pequeñas» en `marca/DESIGN.md`.
- `type` solo se pone si es un taller (`"type": "workshop"`); si no, es una presentación.
- «Suscríbete al calendario» abre `webcal://holaswift.com/sesiones.ics`, un calendario con todas las sesiones que el generador escribe a partir de este archivo. A quien se suscribe le llegan los cambios cuando se publican, en cuanto su app de calendario lo vuelve a leer (cada pocas horas). Cada sesión dura 20 minutos por presentación y 15 más de bienvenida y preguntas; en la descripción sale cada presentación con quien la da y su título, o «Próximamente» si aún no tiene.
- `openSlot: true` añade al cartel de la sesión un hueco más, con un círculo gris y «Podrías ser tú», para animar a alguien a dar una presentación. Cuenta como una presentación más en el cartel de la sesión («2 presentaciones») y en la duración del calendario, pero no sale en su descripción.
- Una sesión es la próxima durante todo su día (hora de España), aunque ya haya empezado: su cartel lleva la cuenta atrás, que pasa a «En directo» mientras dura y a «Ya pasó» al terminar. Al día siguiente ya cuenta como pasada.
- Salen en orden de fecha: primero las 3 últimas que ya pasaron, con «Ya pasó», y luego las que vienen. Solo la próxima sale como cartel grande; las demás, como un billete compacto. Las más antiguas se pueden quedar en el JSON: no se enseñan.
- Si el archivo está vacío (`[]`), sale «Estamos preparando las primeras sesiones. Apúntate y te avisamos de cada una.».
- Cuál es la próxima y cuáles ya pasaron se calcula al generar, pero la página lo vuelve a calcular al cargar con la fecha del día: no hace falta regenerar cuando pasa una sesión.

## Patrocinadores (`sponsors.json`)

```json
{
  "name": "Acme",
  "logo": "assets/patrocinadores/acme.svg",
  "web": "https://acme.com"
}
```

- `name` y `logo` son obligatorios; `web` es opcional (sin web, el logo sale sin enlace). El nombre es el texto alternativo del logo.
- La sección es una superficie de aluminio con nuestras pegatinas y el texto en una pegatina blanca grande. Cada patrocinador es una pegatina blanca más a la derecha, en el orden del archivo, y detrás va siempre el hueco «Tu marca aquí» para el siguiente. Sin patrocinadores (`[]`), el hueco sale solo, más grande.
- Caben 5 patrocinadores: con más, `swift run generate` da error. Para más, hay que añadir sitios en `assets/css/holaswift.css` (`.lid-sponsors > :nth-child(…)`) y subir `maxSponsors` en `Sources/Generate/main.swift`.
- Los logos van en `assets/patrocinadores/`, mejor en SVG (si no, PNG o WebP con fondo transparente), recortados sin margen alrededor. El logo se ajusta solo dentro de su celda sea apaisado, cuadrado o vertical.
- Los enlaces llevan `rel="sponsored"`, como pide Google para los enlaces de patrocinio.

## Antes de subir un cambio

1. Editad el JSON.
2. `swift run generate`
3. Para verlo, servidlo en local y abrid http://localhost:8000:

       python3 -m http.server 8000

   Con doble clic (`file://`) se ve el HTML, pero el navegador no deja arrancar Swift desde un archivo local:
   las sesiones no se repintan con la fecha de hoy, sus tarjetas no se abren y los embajadores no se barajan.
4. Subid el JSON y el `index.html` juntos.

La acción `Check` de GitHub pasa `swift run generate --check` en cada push: avisa en rojo si un JSON tiene errores o si se cambió un JSON y no se regeneró `index.html` o `sesiones.ics`.

## La web, hecha con SwiftWasm

La web es un paquete de Swift (`Package.swift`, en la raíz):

| Carpeta | Qué es |
|---|---|
| `Sources/HolaSwift/` | La lógica compartida: los modelos de `data/` (`Person`, `Meetup`, `Talk`, `Speaker`, `Sponsor`, `Moment`), las sesiones (`SessionCards.swift`), sus textos (`MeetupText.swift`) y las ayudas de texto (`Text.swift`). Sin Foundation, para que compile también a WebAssembly. |
| `Sources/Generate/` | El generador: `swift run generate` escribe el equipo, las sesiones y los patrocinadores en `index.html`, y las sesiones en `sesiones.ics`. |
| `Sources/Web/` | Lo que corre en el navegador, compilado a WebAssembly. En `index.html` no queda JavaScript escrito a mano: solo las dos líneas que arrancan Swift. Está repartido en carpetas: |
| `Sources/Web/main.swift` | El arranque: lee los datos de la página, repinta las sesiones con la fecha de hoy, arranca su cuenta atrás y baraja los embajadores. |
| `Sources/Web/Hero/` | El hero: la construcción del logo (`Hero`, con sus piezas `Piece`, `Stroke`, `Phases` y `Span`), la mano, el giro, las lupas de editor (`Box2D`) y el cursor del corazón. `Cached` evita escribir en la página lo que no cambia. |
| `Sources/Web/Sheets/` | Las hojas y sus formularios: `Sheet` (lo común a todas), `Sheets` (la ficha-cromo de embajador, «Avísame» y patrocinio), `SessionCard` (la tarjeta de cada sesión), `MailingList` (EmailOctopus) y `Sponsorship` (el formulario de patrocinio). |
| `Sources/Web/Page/` | El resto de la página: `Page` (la barra, las apariciones al hacer scroll, el manifiesto, los glifos y la carta), `Duo` (la columna del iPhone Duo) y `Box` (medidas de un elemento). |
| `Sources/Web/Support/` | `DOM`: las ayudas para hablar con la página (`find`, `listen`, `closure`…). |

Los carteles de las sesiones salen del mismo código (`HolaSwift`) en el generador y en el navegador, así que siempre son iguales.

Si Swift no arranca (un navegador sin WebAssembly, o la página abierta como archivo), la página se ve igual, con el HTML y el CSS que trae: a los 2,5 s el logo aparece ya construido (a color, con la mano, los glifos y el titular con su formulario) y lo que entra al hacer scroll aparece solo. Lo que no funciona sin Swift son las animaciones, las hojas, los formularios y la carta.

Si cambiáis algo de `Sources/Web/` o `Sources/HolaSwift/`, volved a compilar el WebAssembly (hace falta Docker abierto):

    ./scripts/build-web.sh

Se compila con **Embedded Swift**, la versión reducida de Swift: el `.wasm` pesa unos 340 KB (140 KB comprimido) en vez de casi 4 MB. Deja en `assets/swift/` el `Web.wasm` y el JavaScript que lo arranca, que genera JavaScriptKit (no se toca a mano). La acción de GitHub lo compila también en cada push para comprobar que no hay errores, pero la web publica el que está en el repositorio: subidlo siempre recompilado.

El código (tipos, funciones, propiedades, clases de CSS y comentarios) va en inglés, para que lo pueda leer cualquiera; los textos que ve la gente, en español. Cada tipo (`struct`, `class`, `enum`) va en su propio archivo, con el mismo nombre, y los archivos del navegador se agrupan por parte de la página en carpetas dentro de `Sources/Web/`.

### Embedded Swift: lo que no vale en `Sources/Web` ni en `Sources/HolaSwift`

`HolaSwift` también lo compila el navegador, así que sigue las mismas reglas:

- **Sin `Codable`**: el generador lee el JSON con `JSONDecoder` (las conformancias van en `#if !hasFeature(Embedded)`); la página lo lee campo a campo desde JavaScript.
- **Sin `==` entre `String`**: comparad con `sameText(a, b)`, byte a byte. `==` tiene en cuenta Unicode y arrastra unos 700 KB de tablas.
- **Sin `lowercased()`, `uppercased()` ni recorrer `Character`**: se trabaja con `unicodeScalars` (ver `upper`, `lower` e `initials` en `MeetupText.swift`).
- **Sin key paths** (`\.isWorkshop`): usad closures (`{ $0.isWorkshop }`).
- **Métodos de JavaScript solo sobre objetos**: un texto de JavaScript (por ejemplo, lo que devuelve `toISOString()`) se pasa a `String` con `.string` y se trata en Swift.
- **Cuidado con `Int(Double)`**: con `NaN` detiene Swift. Usad `intValue(_:)`, que devuelve `nil`.
- **No llaméis a un método de JavaScript que puede no existir**: llamar a algo que no es una función detiene Swift. Para `closest` usad `nearest(_:_:)`, y para `focus`, `focusIfPossible(_:)`; los dos lo miran antes.
- **Guardad los `JSClosure`**: un listener tiene que seguir vivo mientras la página lo pueda llamar. Usad `listen(_:_:_:)` o `closure(_:)` (`Support/DOM.swift`), que los guardan.

Si algo de esto se cuela, `./scripts/build-web.sh` no enlaza (falta un símbolo) o la página da `RuntimeError: unreachable` en la consola; las sesiones que trae el HTML se quedan como están.
