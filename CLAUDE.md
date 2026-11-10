# Kurcar

Juego de cartas coleccionables de coches (tipo Top Trumps) en español. El dueño es Pedro: no es programador, explícale las cosas claras y sin jerga, y ve paso a paso.

## Origen
La app nació como un artifact de claude.ai (un solo `index.html` + carpeta `photos/`). Se ha traído a Claude Code para hacerla crecer.

## Estructura actual
- `index.html` — toda la app (HTML + CSS + JS en un único archivo, ~450 KB).
- `photos/` — fotos reales de coches (Wikimedia Commons), una por modelo.

## Publicación
- Repositorio público: https://github.com/kurcar/kurcar (cuenta de GitHub `kurcar`).
- Web (GitHub Pages, rama `main`, raíz): https://kurcar.github.io/kurcar/ — se actualiza sola 1-2 min después de cada `git push`.
- Los commits se firman con el email privado de GitHub (`...@users.noreply.github.com`), nunca con el Gmail de Pedro: todo lo que se sube es público.
- La herramienta `gh` está en `~/.local/bin/gh` (el Homebrew del Mac está roto; no usarlo).

## IMPORTANTE: funciones que solo existían dentro de claude.ai
El artifact usaba el "runtime" de claude.ai, que FUERA de claude.ai no existe. Hay que sustituirlo:

| Lo que usaba | Para qué | Dónde (aprox.) | Sustituto propuesto |
|---|---|---|---|
| `user.id()` | Identificar al jugador | — | ✅ HECHO: login con email y contraseña de Supabase (botón "Entrar" en la cabecera) |
| `db.collection("data/users/...")` | Guardar colección de cada jugador | — | ✅ HECHO: `Almacen` = navegador sin cuenta, Supabase con cuenta (ver abajo) |
| `db.collection("matriculas")` | Registro de matrículas ya fotografiadas | buscar `registry()` | Supabase (pendiente) |
| `db.collection("intercambios")` | Cambios de cartas repetidas entre jugadores | — | ✅ HECHO: mercadillo con Supabase (ver abajo) |
| `sample.json(...)` | IA: reverso de carta, tasación por foto, motor de juego, tapar matrícula | líneas ~1627, 1685, 1854, 3664 | API de Claude llamada desde un servidor (nunca poner la API key en el navegador) |

## Guardado de la colección (`Almacen`) y Supabase
Todo el guardado de cartas y progreso pasa por la variable `Almacen` en `index.html` (buscar "Almacen"). Cada almacén tiene 4 funciones: `cargar()`, `guardarCarta(c)`, `borrarCarta(id)`, `guardarMeta(m)`.
- **Sin cuenta**: `AlmacenNavegador` → IndexedDB (si falla, localStorage). La primera vez copió lo que hubiera en localStorage (`cdc-cards`, `cdc-meta`).
- **Con cuenta**: `AlmacenSupabase` → tablas `cartas` (user_id, id, datos jsonb) y `progreso` (user_id, datos jsonb). Esquema y reglas de seguridad (RLS) en `supabase/esquema.sql`.
- **Al entrar**: `cargarDeLaNube()` sube a la cuenta las cartas que hubiera en el navegador y las quita de él (solo las ya subidas). Los sobres diarios ya reclamados en la nube no se duplican (`juntarMeta`).
- **Al entrar/salir** la página se recarga; `initStore()` mira si hay sesión y elige el almacén.
- Si la nube falla al cargar, se juega en el navegador (botón "Sin conexión") y se sube la próxima vez.
- Proyecto Supabase: `lmmrcdyxepmllcaefira` (nombre "kurcar"). En el código solo van la URL y la clave **publicable** (`sb_publishable_...`), que son públicas a propósito. NUNCA la clave secret/service_role ni la contraseña de la base de datos.
- Ajustes hechos en Supabase: "Confirm email" APAGADO (el email gratis de Supabase no llega a gente de fuera del equipo); Site URL = https://kurcar.github.io/kurcar/.
- Librería: `@supabase/supabase-js@2.118.0` desde jsDelivr. Si no carga, el botón de cuenta se oculta y se juega sin cuenta.
- `uid` = id del jugador en Supabase cuando ha entrado. `db` (de claude.ai) sigue en `null`: el registro de matrículas está pendiente.

## Mercadillo de cromos (intercambios)
- SQL en `supabase/intercambios.sql` (se puede re-ejecutar sin error). Tablas `perfiles` (apodo único, visible para jugadores con cuenta) y `ofertas`.
- Las operaciones las hace la base de datos (funciones `security definer`): `kurcar_publicar`, `kurcar_aceptar`, `kurcar_retirar`. La interna `kurcar_nueva_carta` no la puede llamar nadie desde fuera.
- Al aceptar, Supabase mueve las dos cartas de una vez: el autor recibe la suya aunque no esté conectado. Al abrir Kurcar, `mkAvisos()` le enseña "¡X ha aceptado tu oferta!".
- Solo se cambian repetidas de sobre (`tradables()` en el cliente; el servidor comprueba que sea tuya, de sobre y no cazada). Máximo 5 ofertas abiertas.
- Las cartas que llegan por cambio llevan `cambio:true` y un id nuevo (`x...`).
- Se necesita cuenta y apodo. El email nunca se muestra; solo el apodo.
- Probado con las cuentas `prueba-kurcar@example.com` / `prueba2-kurcar@example.com` (contraseña de prueba en los scripts del scratchpad, no en el repo).
- Límite conocido: el juego confía en el cliente para los sobres; un tramposo puede inflar SU colección, pero no tocar la de otros.
- Pruebas: en este Mac, Chrome headless sirve, pero para esperar a la nube usar tiempo real (la página envía el informe por POST a un servidor local), no `--virtual-time-budget`.

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
