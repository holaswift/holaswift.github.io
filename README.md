<p align="center">
  <a href="https://holaswift.com"><img src="assets/img/logo-3d.webp" alt="¡hola Swift!" width="520"></a>
</p>

<p align="center"><b>La comunidad de Swift en español.</b><br>
<a href="https://holaswift.com">holaswift.com</a> · <a href="https://x.com/hola_swift">@hola_swift</a></p>

---

Durante mucho tiempo, quien programa en Swift en español ha aprendido solo: documentación en inglés, vídeos en inglés y pocas
caras conocidas. hola Swift existe para cambiar eso. Ya no estáis solos.

Este repositorio es la web: **holaswift.com**.

## Qué hacemos

- **Quedadas online cada mes.** El tercer miércoles de cada mes, a las 19:00 (hora de España), en Discord. Hasta tres charlas
  cortas por quedada, en directo y en español. Empezamos el 20 de enero de 2027.
- **Un encuentro en persona.** Lo estamos preparando. Os lo contaremos en la web primero.
- **Una comunidad para quedarse.** De España y Latinoamérica, empecéis ahora o llevéis años.

Lo organizan Jon Ander Orcera y Alejandro Mohamad, con un grupo de embajadores. La marca y la web las ha diseñado
[Chubby Studio](https://chubby.studio).

## ¿Queréis participar?

- **Apuntaos** en [holaswift.com](https://holaswift.com) y os avisamos de cada quedada.
- **¿Tenéis una charla en la cabeza?** Escribidnos a comunidad@holaswift.com. Veinte minutos bastan.
- **¿Sois una empresa?** Hablemos de patrocinio en patrocinio@holaswift.com.
- **¿Escribís sobre tecnología?** El kit de prensa está en [holaswift.com/prensa](https://holaswift.com/prensa/).
- **¿Vais a dar una charla?** La plantilla y la skill de Claude para hacer las diapositivas están en
  [holaswift.com/presentaciones](https://holaswift.com/presentaciones/).

## Hecha con Swift

La web no lleva JavaScript escrito a mano. La parte que se mueve está escrita en Swift y corre en el navegador como
WebAssembly, con Embedded Swift: el `.wasm` pesa unos 340 KB (140 KB comprimido). El mismo código Swift genera el HTML de las quedadas y lo
repinta en el navegador con la fecha de quien la visita, así que las dos versiones siempre coinciden.

Si os apetece curiosear, empezad por `Sources/HolaSwift/Quedadas.swift`.

## Cambiar la web

**El equipo, las quedadas y los patrocinadores** salen de los JSON de [`datos/`](datos). No hace falta tocar el HTML:

1. Editad el JSON. Por ejemplo, el título de una charla en `datos/quedadas.json`.
2. Pasad el generador: `swift run generar`.
3. Miradlo en local con `python3 -m http.server 8000` y abrid http://localhost:8000.
4. Subid el JSON y el `index.html` juntos.

Todos los campos y sus reglas están en [`datos/README.md`](datos/README.md).

**Si cambiáis algo de `Sources/Web/` o `Sources/HolaSwift/`**, volved a compilar el WebAssembly con `./scripts/compilar-web.sh`
(con Docker abierto) y subid también `assets/swift/`. La web publica el `.wasm` que hay en el repositorio.

## Para quien mantiene esto

| Qué | Dónde |
|---|---|
| La página principal | `index.html`. Lo que hay entre `<!-- generado:… -->` y `<!-- /generado:… -->` lo escribe el generador: no lo editéis a mano |
| Textos legales | `aviso-legal.html`, `privacidad.html` y `cookies.html`. Los datos que faltan salen con borde punteado |
| El código Swift | `Sources/HolaSwift/` (compartido), `Sources/Generar/` (el generador) y `Sources/Web/` (el navegador). Las reglas de Embedded Swift están en `datos/README.md` |
| Las reglas de diseño | `DESIGN.md`, en el repositorio privado `marca` |

- **Publicación:** GitHub Pages desde la rama `main`, con el dominio `holaswift.com` (`CNAME`). Las URL van sin `.html`:
  `/privacidad` sirve `privacidad.html`.
- **Comprobación:** la Action `Comprobar` pasa `swift run generar --comprobar` en cada push y avisa si un JSON tiene
  errores o si `index.html` no está al día.
- **Lista de correo:** EmailOctopus. Los tres formularios para apuntarse (el del principio, «Avísame» y el de cada
  quedada) mandan el email a su formulario desde `Sources/Web/ListaDeCorreo.swift`, sin cargar su script. EmailOctopus
  manda el correo de confirmación. Si se rehace el formulario en EmailOctopus, cambia su id: copiadlo en ese archivo y
  recompilad el WebAssembly.
- **Estadísticas:** Cloudflare Web Analytics, sin cookies. El código va al final de cada página de la web (también en
  las de `prensa` y `presentaciones`); si añadís una página nueva, copiadlo también y no lo pongáis en `herramientas`.
- **Otras páginas, en otros repositorios:** `holaswift.com/prensa/`, `/presentaciones/` y `/herramientas/` son el Pages de
  [`prensa`](https://github.com/holaswift/prensa), [`presentaciones`](https://github.com/holaswift/presentaciones) y
  [`herramientas`](https://github.com/holaswift/herramientas). GitHub los sirve bajo este dominio. No creéis aquí
  `prensa.html`, `presentaciones.html` ni una carpeta `herramientas/`: chocarían con ellos. Esas páginas piden las fuentes,
  los glifos y el favicon a esta web (`/assets/…`): si los movéis o los renombráis, se rompen allí también.
- **Herramientas del equipo:** su bloqueo para buscadores y bots de IA está en el `robots.txt` de aquí: no lo quitéis, y no añadáis esas páginas a `sitemap.xml`.

hola Swift es una comunidad independiente, sin relación oficial con Apple Inc. Swift y Apple son marcas de Apple Inc.
