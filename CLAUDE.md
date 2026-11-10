# Kurcar

Juego de cartas coleccionables de coches (tipo Top Trumps) en español. El dueño es Pedro: no es programador, explícale las cosas claras y sin jerga, y ve paso a paso.

## Origen
La app nació como un artifact de claude.ai (un solo `index.html` + carpeta `photos/`). Se ha traído a Claude Code para hacerla crecer.

## Estructura actual
- `index.html` — toda la app (HTML + CSS + JS en un único archivo, ~450 KB).
- `photos/` — fotos reales de coches (Wikimedia Commons), una por modelo.

## IMPORTANTE: funciones que solo existían dentro de claude.ai
El artifact usaba el "runtime" de claude.ai, que FUERA de claude.ai no existe. Hay que sustituirlo:

| Lo que usaba | Para qué | Dónde (aprox.) | Sustituto propuesto |
|---|---|---|---|
| `user.id()` | Identificar al jugador | línea ~1666 | Login real (Supabase Auth o Firebase Auth) |
| `db.collection("data/users/...")` | Guardar colección de cada jugador | — | ✅ HECHO: ahora pasa por el objeto `Almacen` (ver abajo). Hoy guarda en el navegador |
| `db.collection("matriculas")` | Registro de matrículas ya fotografiadas | línea ~1840 | Misma base de datos |
| `db.collection("intercambios")` | Cambios de cartas repetidas entre jugadores | línea ~3554 | Misma base de datos |
| `sample.json(...)` | IA: reverso de carta, tasación por foto, motor de juego, tapar matrícula | líneas ~1627, 1685, 1854, 3664 | API de Claude llamada desde un servidor (nunca poner la API key en el navegador) |

## Guardado de la colección (`Almacen`)
Todo el guardado de cartas y progreso pasa por `const Almacen=...` en `index.html` (buscar "Almacen"). Tiene 4 funciones: `cargar()`, `guardarCarta(c)`, `borrarCarta(id)`, `guardarMeta(m)`.
- Hoy: `AlmacenNavegador` → IndexedDB (cabe mucho, también fotos); si falla, localStorage. La primera vez copia lo que hubiera en localStorage (`cdc-cards`, `cdc-meta`) y no lo borra.
- Para Supabase: escribir `AlmacenSupabase` con esas mismas 4 funciones y cambiar solo la línea `const Almacen=`. Una tabla `cartas` (id, user_id, datos jsonb) y otra `meta` (user_id, datos jsonb) bastan.
- `db` y `uid` siguen en `null`: matrículas e intercambios online quedan apagados hasta tener login.

Mientras no se sustituyan, esas partes no funcionarán al abrir la app en local.

## Ideas y deseos de Pedro (hoja de ruta)
- Fotos reales de Wikimedia Commons añadidas a diario, priorizando los coches más vistos en calles españolas.
- Diseño estilo garaje/taller; cada carta con estilo según la época del coche.
- Circuitos con trazados reales.
- Modo carreras: circuito, resistencia, rally, off-road; km, experiencia de piloto, clima, paradas en boxes, cartas de piezas/mantenimiento y más adelante modificaciones.
  - ⏸️ De momento OCULTO por deseo de Pedro (10-11-2026). Interruptor `const MODO_CARRERAS=false` en `index.html`: oculta la pestaña, las horas de taller, las piezas en sobres, los km y el estado de las cartas. El código sigue ahí; poner `true` para recuperarlo.
- Intercambiar solo cartas repetidas con otras personas.
- Convertirla en app móvil descargable (iPhone/Android).

## Forma de trabajar
- Cambios pequeños, uno cada vez, y comprobar en el navegador antes de seguir.
- Hacer commit en git después de cada cambio que funcione, con mensajes en español.
- Antes de cambios grandes (partir el index.html en archivos, montar backend), proponer el plan y esperar el OK de Pedro.
