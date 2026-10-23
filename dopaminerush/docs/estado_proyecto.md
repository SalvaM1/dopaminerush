# Dopamine Rush — Estado del proyecto

Qué está hecho, qué falta y en qué orden. Documento vivo.

> Diseño de cada app: `plan_apps.md`

**Última verificación contra el código: 2026-10-09.** Todo lo que sigue se chequeó
leyendo los archivos, no de memoria. Si algo acá no coincide con el código, el
código tiene razón y este documento está viejo: corregilo.

---

## 1. Resumen

**El juego es jugable de punta a punta.** Menú → despertar → sentarse → usar las
apps → colapso → parque → créditos.

El parque incluye un **perrito compañero** al llegar: sigue la caminata y se
puede acariciar con E de forma opcional. Integración: `perrito_parque.md`.

La habitación tiene **ciclo de mañana a noche** sincronizado con el reloj de
la computadora: cielo y luz por la ventana cambian gradualmente. Integración:
`ciclo_dia.md`.

De las **6 apps del catálogo, 5 están implementadas**. Falta **Loopify**, que hoy
abre un placeholder. Lo que más falta no es código: es **audio**.

---

## 2. El catálogo: 6 apps (no 7)

El orden es el orden en que el juego las ofrece, y está decidido.
`game_manager.gd` → `const APPS`.

| # | App | Qué da | Estado |
|---|---|---|---|
| 1 | **TikBrainRot** | 16 por video (jackpot 32) | ✅ con video real |
| 2 | **Family Savings™** | 20 por giro | ✅ |
| 3 | **Preguntados** | 20 × multiplicador de racha | ✅ 12 preguntas cargadas |
| 4 | **Subway Slop** | 7 **por segundo**, decae a 0 | ✅ con video real |
| 5 | **Mercado Libre** | 60 al confirmar | ✅ con el celular 3D |
| 6 | **Loopify** | multiplica las otras ×1.3 | ❌ **falta** |

**LinkedOut no es del catálogo.** Se abre sola, no se ofrece y no se desbloquea.
Vive en `escritorio.gd` con su propia constante y su propia función de apertura,
deliberadamente separada del resto. Da 6 y alivia el drenaje a 0.75 mientras está
abierta. No la vuelvas a meter en `APPS`.

**La etapa final se dispara con las 6 apps desbloqueadas** + 30 s sin novedades
(`ESPERA_ETAPA_FINAL`).

---

## 3. Los números del balance

Viven todos en `game_manager.gd` salvo los de cada app, que están en su `.tscn`.

- `DRENAJE_INICIAL` **3.5** por segundo
- `DRENAJE_POR_APP` **+3.2** por app, y `RAMPA` **0.008** por segundo de juego.
  **Estos dos no se tocan**: rigen hasta la 3ª app y ahí el juego ya está bien.
- Desde la **5ª app** empieza la meseta: `DRENAJE_MESETA` **12.5**,
  `DRENAJE_POR_APP_MESETA` **0.15** y `RAMPA_MESETA` **0.005**.
- El vape se desbloquea con la **3ª app** (`habitacion.gd` → `APPS_PARA_VAPE`)
- **Netflox** se habilita con la **5ª app**, y aparece **15 s después** con su
  propio cartel. T prende la tele (-10% de drenaje) y la mira (**+70**, 4,2 s de
  animación, 30 s de cooldown). Portada provisional; falta elegir la película y
  su audio espacial. Ver `netflox.md`.

### La meseta del televisor

Hasta la **3ª app** el drenaje es exactamente el de siempre:
`3.5 + segundos*0.008 + (apps-1)*3.2`. Esa parte está balanceada y **no se toca**.

Desde la **5ª app** el piso **baja** a la meseta y de ahí en más casi no sube. La
rampa temporal también afloja desde ese instante, anclada al momento del
desbloqueo para que el drenaje no pegue un salto al cambiar de pendiente.

Antes el salto de 3.2 seguía siendo lineal y a las 6 apps el drenaje llegaba a
**19,5/s**, más del doble de lo que todas las apps juntas pueden producir.

A los 5,5 min, con la tele prendida:

| apps | original | ahora | con la TV |
|---|---|---|---|
| 1-4 | — | **sin cambios** | — |
| 5 | 18,94 | 15,14 | 13,63 |
| 6 | 22,14 | 15,29 | 13,76 |

**La meseta no es un derrumbe: la escalada se detiene.** Con la 5ª app el piso
queda apenas por debajo del de la 4ª (12,5 contra 13,1) en vez de caer en picada.
La ayuda real la da el televisor, que produce aparte y encima baja el drenaje
un 10%.

⚠ **No bajar `DRENAJE_MESETA` sin medir.** Con 5,7 el drenaje quedaba en 7,51 y
un canal fresco de Subway Slop (que da **7/s**, no 3,5 — eso es el promedio
mientras se quema) más la tele ya daban 9,05: la barra **subía sola sin tocar
nada**. Hoy faltan 4,58/s, así que hay que trabajar las otras apps.

Al calcular "produce" se cuenta **una sola app activa a la vez**, porque el mouse
es uno solo, más todo lo pasivo (Subway Slop 3,5/s y la TV 2,05/s). Es una
estimación conservadora: alternando apps se produce más. Lo que termina la
partida es `RAMPA_FINAL` (0,8/s en la etapa final), no esta curva.

⚠ La meseta y el televisor arrancan **juntos**, con la 5ª app. Como la
comparación es `apps_desbloqueadas <= APPS_HASTA_LA_MESETA`, ese número (**4**)
es uno menos que el `apps_para_desbloquear` de Netflox (**5**). Si se mueve uno,
mover el otro.

Hasta la 4ª app inclusive —o sea **con Subway Slop ya abierto**— el drenaje es
exactamente el de siempre. Que la barra empiece a bajar más despacio al abrir
Slop era un error: la ayuda tiene que llegar con el televisor, no antes.

**Subway Slop** es la única que da dopamina continua, así que tiene su propia curva:

- `DOPAMINA_POR_SEGUNDO` **7.0** con el canal fresco
- `QUEMA_POR_SEGUNDO` **0.0333** → un canal se agota en **~30 s**
- `RECUPERA_POR_SEGUNDO` **0.011** → y tarda **~91 s** en volver

**TikBrainRot**: la barra dura **8 s** y da **16**. Esos dos números van juntos: si
cambiás la duración hay que cambiar la dopamina en la misma proporción o se
desbalancea el juego entero.

### Las dos palancas de drenaje

Son distintas y conviene no confundirlas:

- `mult_drenaje_externo` — **multiplica** el drenaje. Lo usa LinkedOut (0.75).
- `dopamina_congelada` — **clava la barra**: no pierde *ni gana*.

La segunda existe por un motivo concreto: mirar el celular de Mercado Libre tenía
que frenar la barra, pero si solo se pausara el drenaje, la generación por segundo
de Subway Slop **subiría** la barra gratis y sería spameable. Por eso bloquea las
dos direcciones.

**El vape es la excepción a propósito:** ahí la barra sí sube, y así queda.

---

## 4. Lo que falta

### A) Loopify (la única app que queda)

No da dopamina propia: multiplica la de las otras ×1.3. La canción se termina cada
~40 s y hay que elegir otra. ⚠ **Es la única que toca `app_base.gd`.** Hoy el
slot 5 de `ESCENAS_APPS` es `""` y la carpeta `app_06_` está vacía. Detalle en
`plan_apps.md`.

### B) Audio — la tarea de mayor retorno

Los nodos ya están en las escenas: solo hay que cargarles el archivo. **No hay que
programar nada.**

Lo que **ya está** (11 archivos): `despertador.ogg`, `zumbido.ogg`, `palanca.mp3`,
`pantalla_azul.mp3` y 7 sonidos de UI.

Lo que **falta**:

| Dónde | Archivos | Ruta |
|---|---|---|
| **Family Savings** | `palanca_sube`, `girando`, `rodillo_para`, `casi`, `jackpot`, `moneda`, `luz` | `assets/audio/apps/slots/` |
| **Celular** | notificación / vibración | `assets/audio/ambiente/` |
| **Mercado Libre** | el sonido de compra | `assets/audio/apps/` |
| Parque | `pajaros`, `viento`, `agua` | `assets/audio/ambiente/` |
| Canales de Slop | el audio sale del video; solo si querés pistas aparte | `assets/audio/apps/canales/` |

Los de slots se buscan con `.mp3`, `.ogg` y `.wav`, en ese orden: no importa el
formato. Si un archivo no está, la app avisa por consola y sigue andando.

Ambiente y capas **en loop** (Import → Loop → Reimport), de 30 s o más.
**Anotar cada descarga en `docs/licencias.md` en el momento** — hoy está vacío.

### C) Video — hecho, salvo un archivo

**162 MB en total.** 11 clips de TikBrainRot (largo completo) + 5 canales de Slop
(recortados a 35 s).

Falta **`alfombra.ogv`**: el canal existe en el código pero no tiene video, así que
se queda con su color de fondo.

Scripts: `tools/convertir_videos.bat` (TikToks, sin recorte) y
`tools/convertir_canales.bat` (canales, `-t 35`). Los dos son **incrementales**:
agregás archivos a la carpeta de origen, los corrés y saltean lo ya convertido.

### D) Contenido

- **Preguntados**: 12 preguntas. Se agregan editando `preguntas.json`, sin tocar código.
- **Mercado Libre**: más productos.
- **Loopify**: canciones (cuando exista).

### E) Balanceo

- **Tecla D** en el juego: panel con drenaje, producción y balance en vivo
- Objetivo: **balance** entre **1.05 y 1.40**
- **Un solo número por sesión de prueba**
- Lo que importa es la dopamina **por segundo de atención robada**, no por click

### F) Pendiente visual conocido

`Tropiezo` (la 1ª caída) nunca se re-estiló y ahora choca con el look de sistema
operativo del resto del escritorio.

---

## 5. Limpieza antes de entregar

- Atajos de prueba en `escritorio.gd`: **O** (colapso), **U** (desbloquear todo),
  **P** (frenar drenaje), **D** (panel debug)
- `forzar_2x_desbloqueado` de TikBrainRot en `false`
- `escenas/prueba_nucleo.tscn` y `app_placeholder.tscn`
- La carpeta `tools/` si ya no se usa
- Cualquier `print()` de diagnóstico
- Créditos con **todas** las atribuciones de `docs/licencias.md`
- `Main Scene` = `menu.tscn`, Window Override en 0, modo Fullscreen
- Probar el ejecutable en una máquina sin Godot
- `videos_originales/_nombres_originales.txt` tiene los nombres originales para atribuir

---

## 6. Reglas que no se rompen

1. **Nadie edita una escena que no es suya.** Los `.tscn` se rompen feo al hacer merge.
2. **Los archivos compartidos se tocan lo mínimo**: `game_manager.gd`, `app_base.gd`,
   `ventana_app.gd`, `escritorio.gd`. Las apps heredan de `AppBase` y hablan con
   `GameManager` solo por señales.
3. **Bajar antes de empezar, subir al terminar.**
4. **Ninguna app puede pedir atención continua.** Todas piden en ráfagas y te dejan ir.
5. **Ninguna app puede ser demasiado divertida.** Apenas entretenidas y completamente vacías.
6. **El parque no tiene tareas ni premios.** El perrito acompaña y permite una
   caricia opcional; la recuperación sigue siendo pasiva y el cierre, respirar.
7. **Cerrar Godot antes de copiar assets** desde el explorador de archivos.

---

## 7. Decisiones de diseño ya tomadas

Esto está discutido y resuelto. No hace falta volver a abrirlo, y si se cambia, que
sea a propósito.

**El mouse es el recurso escaso.** Es la razón por la que el código de Mercado
Libre se tipea en un teclado en pantalla con el mouse y no con el teclado real: si
se usara el teclado, el trámite no costaría nada.

**El chiste va en una opción incorrecta, nunca en la pregunta.** Si la pregunta es
graciosa deja de ser trivia y se nota el guiño. Pregunta en serio + distractora
absurda = se juega como Preguntados de verdad y la sátira igual entra.

**La respuesta correcta rota de posición.** La app baraja el orden de las preguntas
pero *no* el de las opciones: si la correcta estuviera siempre en el mismo botón,
aprenderías a apretar ahí y la app dejaría de pedir atención.

**El botón de "comprar créditos" que se escapa del borde es parte de la gracia**, no
un bug de layout. Solo el primero aparece centrado.

**En el casino no se cambia la mecánica.** Todo lo que se agregó es visual y sonoro.
La palanca no tiene peso: es arrastre directo 1:1, con un recorrido mínimo para que
no cuente un tirón fantasma.

**El parque usa la misma barra de dopamina que el escritorio**, arrancando en 0 y
subiendo sola, muy despacio.

**Un día nuevo tiene que sentirse igual que arrancar el juego por primera vez**:
mismo fundido a negro antes de despertar (`SceneLoader.fundir_y_cambiar`).
