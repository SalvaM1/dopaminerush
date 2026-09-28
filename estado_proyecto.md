# Dopamine Rush — Estado del proyecto

Qué está hecho, qué falta y en qué orden. Documento vivo: si algo cambia, se edita.

> Para entender **cómo funciona** el proyecto por dentro: `guia_proyecto.md`
> Para el detalle de cada app: `plan_apps.md`

---

## 1. Resumen en una línea

**El juego es jugable de punta a punta.** Menú → despertar → sentarse → usar las apps → colapso → parque → créditos. Faltan 3 de 7 apps, el balanceo final y el pulido.

---

## 2. Lo que ya está terminado

### Núcleo
- [x] `GameManager` — dopamina, rampa de drenaje, ofertas de apps, luna de miel, tropiezo único, fin del día, etapa final, buff del vape, medición de producción
- [x] `AudioManager` — buses, catálogo, fundidos
- [x] `SceneLoader` — cambios de escena con fundido
- [x] `Juice` — 12 funciones de feedback reutilizables (pop, flash, shake, contar, partículas, pitch)
- [x] `AppBase` — contrato de las apps

### Mundo 3D
- [x] Jugador FPS, raycast, punto de mira que reacciona a lo interactuable
- [x] Dos modos de mirar: de pie (gira el cuerpo) y sentado (gira la cabeza, con tope)
- [x] Objetos que se apagan al cumplir su función: nunca hay dos carteles a la vez
- [x] Secuencia de despertar: negro, despertador, fundido
- [x] Monitor 3D con SubViewport y traducción del mouse a la pantalla
- [x] Sentarse y levantarse sin cortes
- [x] **El vape** — se desbloquea con la 3ª app, congela el drenaje, cartel publicitario
- [x] Zumbido de ambiente que se corta en el colapso
- [x] **El colapso** — SIN SEÑAL en el monitor, apagón con sonido, silencio, levantarse
- [x] Habitación con iluminación de madrugada

### Escritorio
- [x] Barra de dopamina, reloj acelerado, barra de 7 íconos
- [x] Ventanas: abrir, cerrar, arrastrar, traer al frente, posición fija por app
- [x] Cartel de oferta con voz publicitaria
- [x] Tropiezo (1ª caída) y fin del día (2ª caída)

### Parque
- [x] Camino curvo de 85 m, lago hundido, iluminación golden hour
- [x] Poblador con ~1300 plantas, colisiones en los troncos
- [x] Banco, secuencia de sentarse, "tomar aire", créditos

### Apps terminadas (4 de 7)
- [x] **TikBrainRot** — scroll con cooldown de video, 2x al mantener, recompensa variable
- [x] **Family Savings™** — palanca, giro como cooldown, casi-premios, paywall con botón que se escapa
- [x] **Lingofy** — preguntas con reloj, racha con multiplicador, pitch ascendente, juice completo
- [x] **Subway Slop** — 8 canales con frescura propia, cambio al azar, buffering de 3 s, video que se apaga

---

## 3. Lo que falta

### A) Las 3 apps que quedan

| # | App | Qué hace | Toca archivos compartidos |
|---|---|---|---|
| 1 | **Kompralo!** | Ofertas relámpago + código al celular | No |
| 2 | **Loopify** | Multiplica la dopamina de las otras | Sí — `app_base.gd` |
| 3 | **LinkedOut** | Se abre sola a pantalla completa | Sí — `app_base.gd` y `escritorio.gd` |

> **Importante:** Loopify y LinkedOut necesitan tocar `app_base.gd`. Conviene hacer los dos cambios **de una sola vez y por una sola persona**, antes de que nadie más avance, para evitar conflictos.

#### Kompralo! (la de las ofertas)
- Aparece un producto con contador de ~8 segundos. Si se vence, la oferta se pierde.
- Al clickear "comprar", **el contador para**. El apuro era para decidir, no para el trámite.
- Llega un **código de 3 dígitos al celular**, que está sobre el escritorio en el mundo 3D.
- El jugador aprieta una tecla, la cámara gira al celular, lee el código, vuelve y lo tipea.
- **El drenaje NO se congela** durante el trámite (a diferencia del vape): estás perdiendo tiempo en una gestión mientras todo lo demás se cae. Esa frustración es el punto.
- Contador de "$ gastado hoy" que solo sube. No hace nada: es culpa pura.

#### Loopify (la música)
- No da dopamina propia: **multiplica la de las otras** (×1.3) mientras suena.
- La canción se termina cada ~40 segundos y hay que elegir otra de una lista.
- Crea una decisión real: ¿gasto dos segundos en poner música o los uso en producir?
- El multiplicador se aplica en `recompensar()` de `app_base.gd`.

#### LinkedOut (la hostil)
- **No se abre desde el ícono: se abre sola**, a pantalla completa, tapando todo.
- Hay que cerrarla para seguir usando el resto. Cerrarla da una miga de dopamina.
- Escalada: al principio cada ~45 s, en la etapa final cada ~12 s. Ese solo número convierte los últimos dos minutos en un infierno.
- Contenido: publicaciones motivacionales absurdas.
- Detalle opcional: dos botones de cerrar, uno real y uno falso.

---

### B) Pulido de las apps viejas
TikBrainRot y Family Savings siguen con el feedback mínimo. El autoload `Juice` ya existe, así que agregarles pop, flash, sonidos y números flotantes es rápido. Lingofy sirve de referencia de hasta dónde llegar.

---

### C) Audio que falta
Los nodos ya están en las escenas: solo hay que cargarles el archivo.

| Dónde | Archivos | Ruta |
|---|---|---|
| Parque | pajaros, viento, agua | `assets/audio/ambiente/` |
| Habitación | zumbido, despertador, vape | `assets/audio/ambiente/` |
| Subway Slop | 8 canales (slime, cuchillo, subway, mukbang, prensa, asmr, jabon, alfombra) | `assets/audio/apps/canales/` |
| Capas de app | una por app | `assets/audio/apps/` |

Todo lo de ambiente y las capas, **en loop** (Import → Loop → Reimport) y de 30 s o más.
Los efectos cortos, sin loop.
**Anotar cada descarga en `docs/licencias.md` en el momento.**

---

### D) Video en los canales (opcional)
Subway Slop y TikBrainRot pueden llevar video real. Godot usa **Ogg Theora**, hay que convertir con ffmpeg.
- Bajar a 480p o menos: la ventana mide 440 px, decodificar 1080p es trabajo tirado
- Solo se reproduce un canal a la vez, así que el costo es el de un video
- Probar con 2 antes de convertir 8

---

### E) Balanceo (fase final)
No tocar hasta tener las 7 apps.

- **Tecla D** en el juego: panel con drenaje, producción y balance en vivo
- El objetivo es que **balance** ronde **1.05 – 1.40**
- Todos los números viven en `game_manager.gd`
- **Un solo número por sesión de prueba**
- Lo que importa no es la dopamina por click sino **por segundo de atención robada**

---

### F) Limpieza antes de entregar
- Atajos de prueba en `escritorio.gd`: **O** (colapso), **U** (desbloquear todo), **P** (frenar drenaje), **D** (panel debug)
- `forzar_2x_desbloqueado` de TikBrainRot en `false`
- `escenas/prueba_nucleo.tscn` y `app_placeholder.tscn`
- Cualquier `print()` de diagnóstico
- Créditos completos con **todas** las atribuciones de `docs/licencias.md`
- `Main Scene` = `menu.tscn`, Window Override en 0, modo Fullscreen
- Probar el ejecutable en una máquina sin Godot

---

## 4. Reparto sugerido

| Quién | Qué |
|---|---|
| Persona A | **Kompralo!** + el celular 3D en la habitación |
| Persona B | **Loopify** y **LinkedOut** (las dos juntas, por los archivos compartidos) |
| Persona C | Audio: conseguir, recortar, importar y cargar todos los archivos de la sección C |
| Persona D | Pulido de TikBrainRot y Family Savings con `Juice` |
| Persona E | Contenido: preguntas de Lingofy, textos de LinkedOut, productos de Kompralo! |
| Todos | Balanceo y playtest al final |

La sección C (audio) es la que más rinde por menos conocimiento técnico: no hay que programar nada, solo conseguir archivos y arrastrarlos.

---

## 5. Reglas que no se rompen

1. **Nadie edita una escena que no es suya.** Los `.tscn` se rompen feo al hacer merge.
2. **Bajar antes de empezar, subir al terminar.** Con GitHub Desktop: Fetch al abrir, Commit + Push al cerrar.
3. **Ninguna app puede pedir atención continua.** Todas piden en ráfagas y te dejan ir. Si una te ocupa el 100% del tiempo, rompe el juego entero.
4. **Ninguna app puede ser demasiado divertida.** Apenas entretenidas y completamente vacías. Si alguien se queda por gusto, la obra deja de tratar sobre el vacío.
5. **El parque no tiene nada que hacer.** Sin objetivos, sin coleccionables. Ese vacío es el punto.
6. **Cerrar Godot antes de copiar assets** desde el explorador de archivos.
