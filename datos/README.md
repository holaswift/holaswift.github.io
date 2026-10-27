# Datos de la web

El equipo y las quedadas de la web salen de estos archivos. Para cambiar algo se edita el JSON (no el HTML) y se pasa el generador, que lo escribe en `index.html`:

    swift scripts/generar.swift

Solo toca lo que hay entre las marcas `<!-- generado:… -->` y `<!-- /generado:… -->` de `index.html`; el resto de la página no se toca. Antes de escribir nada comprueba los datos y, si algo no cuadra, dice qué y dónde (`embajadores.json #3: falta "bio"`).

| Archivo | Qué pinta |
|---|---|
| `founders.json` | Las fichas grandes de founders, con la bio a la vista |
| `embajadores.json` | La rejilla de embajadores; la bio sale al pulsar el + |
| `quedadas.json` | Las tarjetas de quedadas online y su hoja con «Añadir a Calendario» |
| `patrocinadores.json` | Los logos del muro de la sección de patrocinio |

`ejemplos/` guarda copias de datos de ejemplo (por ejemplo, las quedadas de prueba en `ejemplos/quedadas.json`): el generador no las lee y no se publican. Para volver a verlas en la web, se copian encima del archivo de verdad y se pasa el generador.

El orden del archivo es el orden en la web, salvo en dos casos: las quedadas se ordenan solas por fecha, y los embajadores se barajan en cada visita para que nadie salga siempre primero (en el HTML se quedan en el orden del JSON).

## Personas (`founders.json` y `embajadores.json`)

```json
{
  "nombre": "Julio César Fernández Muñoz",
  "rol": "Evangelista · Apple Coding Academy",
  "foto": "assets/equipo/julio-cesar-fernandez-munoz.webp",
  "bio": "Apple Technical Partner y evangelista en desarrollo Apple e IA. …",
  "x": "https://x.com/jcfmunoz",
  "linkedin": "https://www.linkedin.com/in/jcfmunoz/",
  "web": "https://acoding.academy"
}
```

- `nombre`, `rol`, `foto` y `bio` son obligatorios. `x`, `linkedin` y `web` son opcionales: si falta uno, no sale su icono.
- `rol`: «Rol · Empresa», corto, que quepa en dos líneas de la tarjeta.
- `bio`: en tercera persona, 2 o 3 frases (ver `DESIGN.md`).
- `foto`: WebP de 800 × 1000 (4:5) en `assets/equipo/`, con el nombre en minúsculas y guiones.
- En embajadores, si hay 4, 8, 12… personas, el hueco de «Muy pronto» se esconde solo para no ocupar una fila él solo.

## Quedadas (`quedadas.json`)

Cada quedada tiene su propio título y de 1 a 3 charlas, de 20 minutos como mucho cada una.

```json
{
  "fecha": "2026-11-18T19:00:00+01:00",
  "titulo": "Empezar con SwiftUI",
  "notas": "Tres charlas cortas para empezar con SwiftUI.",
  "enlace": "https://discord.gg/…",
  "demo": false,
  "charlas": [
    {
      "titulo": "Tu primera app con SwiftUI",
      "ponentes": [{ "nombre": "Lucía Gómez", "foto": "assets/ponentes/lucia-gomez.webp" }],
      "descripcion": "Empezamos con un proyecto vacío en Xcode…"
    },
    {
      "titulo": "SwiftData en una app de verdad",
      "ponentes": [
        { "nombre": "Pol Piella Abadia", "foto": "assets/equipo/pol-piella-abadia.webp" },
        { "nombre": "Asier G. Morato" }
      ],
      "tipo": "Taller"
    }
  ]
}
```

- **Quedada:** `fecha`, `titulo` y `charlas` son obligatorios; `notas` (para toda la quedada), `enlace` y `demo` son opcionales.
- La fecha va con zona horaria: `+01:00` en invierno y `+02:00` en verano (hora de Madrid). En la web solo se enseña la hora de empezar.
- **Charla:** `titulo` es obligatorio. `ponentes` es una lista de hasta 3 personas; vacía o sin poner, sale «Ponente por confirmar» con un círculo gris. `descripcion` es opcional.
- **Ponente:** `nombre` es obligatorio y `foto` opcional. Las fotos salen en círculos apilados a la izquierda de la charla; sin foto, sale un círculo gris con sus iniciales.
- Las fotos de ponentes van en `assets/ponentes/`: cuadradas, en WebP, de 200 × 200 y con el nombre en minúsculas y guiones (`lucia-gomez.webp`). Para quien ya está en el equipo se puede usar su foto de `assets/equipo/`.
- `tipo` solo se pone si es un taller (`"tipo": "Taller"`); si no, es una charla.
- La pastilla de la tarjeta lo resume sola: «Charla», «3 charlas», «Taller» o «2 charlas y 1 taller».
- En «Añadir a Calendario» la quedada dura 20 minutos por charla y 15 más de bienvenida y preguntas.
- `demo: true` pinta la etiqueta «Ejemplo» en la tarjeta.
- Una quedada es «El próximo» durante todo su día (hora de Madrid), aunque ya haya empezado, y pasa a «Ya pasó» al día siguiente.
- Salen en orden de fecha: primero las 3 últimas que ya pasaron (con borde oscuro) y luego las que vienen. Las más antiguas se pueden quedar en el JSON: no se enseñan.
- Si el archivo está vacío (`[]`), sale la tarjeta de «Las primeras quedadas, muy pronto».
- «El próximo» y «Ya pasó» se calculan al generar, pero la página los vuelve a calcular al cargar con la fecha del día: no hace falta regenerar cuando pasa una quedada.

## Patrocinadores (`patrocinadores.json`)

```json
{
  "nombre": "Acme",
  "logo": "assets/patrocinadores/acme.svg",
  "web": "https://acme.com"
}
```

- `nombre` y `logo` son obligatorios; `web` es opcional (sin web, el logo sale sin enlace). El nombre es el texto alternativo del logo.
- El orden del archivo es el orden en el muro. Detrás de los logos va siempre «Tu marca aquí» y después huecos vacíos hasta completar filas de 3, con 6 celdas como mínimo. Con el archivo vacío (`[]`), el muro sale como antes: «Tu marca aquí» y 5 huecos.
- Los logos van en `assets/patrocinadores/`, mejor en SVG (si no, PNG o WebP con fondo transparente), recortados sin margen alrededor. El logo se ajusta solo dentro de su celda sea apaisado, cuadrado o vertical.
- Los enlaces llevan `rel="sponsored"`, como pide Google para los enlaces de patrocinio.

## Antes de subir un cambio

1. Edita el JSON.
2. `swift scripts/generar.swift`
3. Abre `index.html` con doble clic para verlo.
4. Sube el JSON y el `index.html` juntos.

La acción `Comprobar datos` de GitHub pasa `swift scripts/generar.swift --comprobar` en cada push: avisa en rojo si un JSON tiene errores o si se cambió un JSON y no se regeneró `index.html`.
