# Dopamine Rush — Estado del proyecto

Qué está hecho, qué falta y en qué orden. Documento vivo.

> Arquitectura por dentro: `guia_proyecto.md`
> Diseño de cada app: `plan_apps.md`

---

## 1. Resumen

**El juego es jugable de punta a punta.** Menú → despertar → sentarse → usar las apps → colapso → parque → créditos.

Falta **1 de 7 apps** (Loopify), los archivos de audio, el balanceo final y la limpieza.

---

## 2. Terminado

### Núcleo
- [x] `GameManager` — dopamina, rampa de drenaje, ofertas, luna de miel, tropiezo único, fin del día, etapa final, buff del vape, multiplicador externo, medición de producción
- [x] `AudioManager` — buses, catálogo, fundidos
- [x] `SceneLoader` — cambios de escena con fundido
- [x] `Juice` — 12 funciones de feedback reutilizables
- [x] `AppBase` — contrato de las apps

### Mundo 3D
- [x] Jugador FPS, raycast, punto de mira que reacciona a lo interactuable
- [x] Dos modos de mirar: de pie (gira el cuerpo) y sentado (gira la cabeza, con tope)
- [x] Objetos que se apagan al cumplir su función: nunca hay dos carteles a la vez
- [x] Secuencia de despertar
- [x] Monitor 3D con SubViewport y traducción del mouse
- [x] Sentarse y levantarse sin cortes
- [x] **El vape** — se desbloquea con la 3ª app, congela el drenaje, cartel publicitario
- [x] Zumbido de ambiente que se corta en el colapso
- [x] **El colapso** — SIN SEÑAL en el monitor con la caja que deriva, apagón con sonido grave, silencio, retroceso, levantarse
- [x] Habitación con iluminación de madrugada

### Escritorio
- [x] Barra de dopamina, reloj acelerado, barra de 7 íconos
- [x] Ventanas: abrir, cerrar, arrastrar, traer al frente, posición fija por app
- [x] Cartel de oferta con voz publicitaria
- [x] Tropiezo (1ª caída) y fin del día (2ª caída)
- [x] Temporizador de apertura automática para LinkedOut

### Parque
- [x] Camino curvo de 85 m, lago hundido con forma orgánica, golden hour con niebla volumétrica
- [x] Poblador con ~1300 plantas, colisiones en los troncos, semilla configurable
- [x] Banco, sentarse, "tomar aire", créditos con el addon

### Apps (6 de 7)
- [x] **TikBrainRot** — scroll con cooldown, 2x al mantener, recompensa variable
- [x] **Family Savings™** — palanca, giro como cooldown, casi-premios, paywall con botón que se escapa
- [x] **Subway Slop** — 8 canales con frescura propia, cambio al azar, buffering de 3 s, video que se apaga
- [x] **Preguntados** — preguntas con reloj, racha con multiplicador, pitch ascendente, juice completo
- [x] **LinkedOut** — se abre sola con escalada, capturas reales + página agresiva, alivio de drenaje

---

## 3. Lo que falta

### A) Las 2 apps que quedan

**Mercado Libre** — ofertas relámpago con contador. Al comprar, llega un **código de 3 dígitos al celular 3D** que está en el escritorio: la cámara gira, se lee, se vuelve y se tipea. El drenaje NO se congela durante el trámite. No toca archivos compartidos.

**Loopify** — no da dopamina propia, multiplica la de las otras ×1.3. La canción se termina cada ~40 s y hay que elegir otra. ⚠ **Es la única que toca `app_base.gd`.**

Detalle completo de las dos en `plan_apps.md`.

---

### B) Pulido de las apps viejas
TikBrainRot y Family Savings siguen con el feedback mínimo. El autoload `Juice` ya existe y Preguntados sirve de referencia de hasta dónde llegar.

---

### C) Audio que falta
Los nodos ya están en las escenas: solo hay que cargarles el archivo.

| Dónde | Archivos | Ruta |
|---|---|---|
| Parque | `pajaros.ogg`, `viento.ogg`, `agua.ogg` | `assets/audio/ambiente/` |
| Habitación | `zumbido.ogg`, despertador, vape | `assets/audio/ambiente/` |
| Subway Slop | 8 canales: `slime`, `cuchillo`, `subway`, `mukbang`, `prensa`, `asmr`, `jabon`, `alfombra` | `assets/audio/apps/canales/` |
| Capas de app | una por app | `assets/audio/apps/` |
| **Celular** | `celular.ogg` o `.wav` — notificación / vibración | `assets/audio/ambiente/` |
| **Mercado Libre** | `mercadolibre.wav` — el sonido de compra | `assets/audio/apps/` |

Ambiente y capas **en loop** (Import → Loop → Reimport), de 30 s o más. Efectos cortos sin loop.
**Anotar cada descarga en `docs/licencias.md` en el momento.**

Es la tarea de mayor retorno y menor requisito técnico: no hay que programar nada.

---

### D) Video en las apps (opcional)
TikBrainRot (~30 clips) y Subway Slop (8 canales de 2-3 min en loop).
- Godot usa **Ogg Theora**, hay que convertir con ffmpeg
- Bajar a 480p o menos: las ventanas miden 400-440 px
- Solo se reproduce uno a la vez por app, así que el costo es acotado
- Probar con 2 antes de convertir todo

---

### E) Balanceo
**No tocar hasta tener las 7 apps.**

- **Tecla D** en el juego: panel con drenaje, producción y balance en vivo
- Objetivo: **balance** entre **1.05 y 1.40**
- Todos los números viven en `game_manager.gd`
- **Un solo número por sesión de prueba**
- Lo que importa es la dopamina **por segundo de atención robada**, no por click

---

### F) Limpieza antes de entregar
- Atajos de prueba en `escritorio.gd`: **O** (colapso), **U** (desbloquear todo), **P** (frenar drenaje), **D** (panel debug)
- `forzar_2x_desbloqueado` de TikBrainRot en `false`
- `escenas/prueba_nucleo.tscn` y `app_placeholder.tscn`
- La carpeta `tools/` si ya no se usa
- Cualquier `print()` de diagnóstico
- Créditos completos con **todas** las atribuciones de `docs/licencias.md`
- `Main Scene` = `menu.tscn`, Window Override en 0, modo Fullscreen
- Probar el ejecutable en una máquina sin Godot

---

## 4. Reparto sugerido

| Quién | Qué |
|---|---|
| A | **Mercado Libre** + el celular 3D en la habitación |
| B | **Loopify** (toca `app_base.gd`) |
| C | Audio: conseguir, recortar, importar y cargar todo lo de la sección C |
| D | Pulido de TikBrainRot y Family Savings con `Juice` |
| E | Contenido: preguntas de Preguntados, productos de Mercado Libre, canciones de Loopify |
| Todos | Balanceo y playtest al final |

---

## 5. Reglas que no se rompen

1. **Nadie edita una escena que no es suya.** Los `.tscn` se rompen feo al hacer merge.
2. **Bajar antes de empezar, subir al terminar.** GitHub Desktop: Fetch al abrir, Commit + Push al cerrar.
3. **Ninguna app puede pedir atención continua.** Todas piden en ráfagas y te dejan ir.
4. **Ninguna app puede ser demasiado divertida.** Apenas entretenidas y completamente vacías.
5. **El parque no tiene nada que hacer.** Ese vacío es el punto.
6. **Cerrar Godot antes de copiar assets** desde el explorador de archivos.
