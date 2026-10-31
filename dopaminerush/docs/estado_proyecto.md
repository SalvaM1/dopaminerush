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

**Las 6 apps del catálogo están implementadas.** Lo que más falta no es código:
es **audio**.

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
| 6 | **Loopify** | ×1.3 a las otras mientras el tema no aburre | ✅ con 5 temas reales |

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
  animación, 30 s de cooldown). Incluye un fragmento de autos de 3 minutos y
  su audio espacial, con reinicio conjunto. Ver `netflox.md`.

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

## 3b. Tutoriales y el reloj

### El reloj solo corre sentado en la PC

`escritorio.gd` avanza la hora únicamente con `GameManager.activo` (la sesión de
la PC en marcha). Antes corría desde que cargaba la habitación, y un minuto
explorando la pieza eran doce horas de juego: se hacía de noche antes de sentarse.
Ahora explorar es gratis también en tiempo.

### Los tutoriales

Cada uno sale **una sola vez por partida**, y todos frenan el juego hasta la **E**:

| Cuándo | Qué |
|---|---|
| Al terminar de arrancar la compu | Cartel con flecha a la barra: *"Baja sola, todo el tiempo. Usá las apps para que vuelva a subir."* (la sesión recién empieza al apretar E) |
| La primera vez que se abre **cada app** | Un pensamiento del personaje justificándose (ver abajo) |
| La primera vez que **LinkedOut** salta sola | *"Uf... qué miedo estos virus que te abren pestañas raras."* |

Los pensamientos de primera vez, en `pensamientos.json` con la clave
`primera_vez_<id de la app>`:

| App | Pensamiento |
|---|---|
| TikBrainRot | *Un ratito de tiktoks no le hace mal a nadie...* |
| Family Savings™ | *Una sola tirada y la cierro. Es plata de mentira...* |
| Preguntados | *Esto por lo menos es educativo.* |
| Subway Slop | *Lo dejo de fondo y sigo con lo mío.* |
| Mercado Libre | *Solo miro. No voy a comprar nada.* |
| Loopify | *Con música me concentro mejor.* |

Una app sin clave no dice nada. Si dos piensan casi juntas (por ejemplo, salta
LinkedOut justo al abrir una app), la segunda espera su turno en vez de perderse.

Los anuncios del vape y de Netflox ya cumplen ese papel para sus mecánicas.

### La notificación de "app instalada"

La oferta de una app nueva ya no es el cartel rojo del medio: es una
**notificación del sistema** que entra por la derecha, arriba de la bandeja,
como en Windows. Dice *"Se terminó de instalar"*, el nombre de la app y su texto
de oferta, con un ícono de color con la inicial. Vive en
`escenas/02_computadora/CartelOferta.tscn` + `cartel_oferta.gd`.

- **No se puede cerrar ni se va sola.** Es una oferta pendiente: si se fuera, el
  GameManager esperaría una respuesta que nunca llega y no ofrecería más apps.
- **Suena una sola vez**, al aparecer: una por app, unas seis en la partida.
- **Se dibuja arriba de todo** (`z_index` 40). La oferta sale cuando la barra
  está baja, así que muchas veces coincide con un tropiezo; antes la pantalla del
  tropiezo la tapaba.
- **El botón abre la app**, no solo la desbloquea. Antes "Jugar ahora" no jugaba.
  Al abrirse, la app dice su pensamiento de primera vez.
- **El sonido** se busca en `assets/audio/ui/notificacion.ogg` (o `.wav`, `.mp3`).
  Mientras no exista usa `popup.wav` de respaldo. Anotarlo en `licencias.md`.

- **Una vez por partida:** `GameManager.tutoriales_vistos`. `reiniciar()` no la
  borra, así que un día nuevo no los repite. La borra el **menú**, para que en una
  muestra la próxima persona que juegue en la misma compu los vuelva a ver.
- **El texto del pensamiento** está en `pensamientos.json` (clave
  `primer_tiktok`): se edita sin tocar código. El del cartel está en
  `_tutorial_barra()` de `escritorio.gd`.
- **El diálogo puede pausar:** `dialogo.mostrar(texto, jugador, pausar)`. Con
  `pausar = true` pone el árbol en pausa y la saca solo al cerrarse; el nodo del
  diálogo procesa siempre para poder seguir andando.
- **El diálogo devuelve el estado previo del jugador**, no `true`. Antes, un
  pensamiento estando sentado te dejaba caminar con la silla puesta.
- **Tests:** `tools/tests/tutorial_test.gd` (49 comprobaciones). Para simular la E
  hay que usar `Input.parse_input_event()`: `Input.action_press()` no la ve una
  corrutina que espera frames.

## 4. Lo que falta

### A) Loopify: hecha

### Loopify, la última app

Un mini-reproductor (560×320, arriba al centro). Vive en
`escenas/03_apps/app_06_musica/`. Test: `tools/tests/loopify_test.gd`.

- **No da dopamina propia.** Mientras suena un tema **fresco**, todo lo que dan
  las otras apps del catálogo rinde **×1.3** (`GameManager.mult_dopamina_musica`).
  La TV, el vape y LinkedOut no se multiplican.
- **A los 10 s el tema aburre** (`duracion_fresca`): se escucha más apagado
  (−9 dB), se va el ×1.3 y el botón de "Siguiente" late. El tema sigue sonando,
  pero ya no sirve.
- **"Siguiente"** pone otro tema al azar, nunca el mismo dos veces seguidas, y
  vuelve el ×1.3. Es la sátira del que no termina ningún tema.
- **Vive poco y es a propósito:** la etapa final arranca 30 s después de
  desbloquearla. Es la banda sonora del colapso, y en el colapso el juego corta
  todo el audio de golpe: de la música al silencio, y de ahí al parque.

**Los temas:** cualquier `.mp3`, `.ogg` o `.wav` en `assets/audio/loopify/`. Lo
que muestra la app sale del **nombre del archivo**: `Artista - Tema.ogg`. Si hay
una imagen con el **mismo nombre** (`.png`, `.jpg`, `.webp`), es la tapa del
disco, y su color tiñe la app; si no, sale un cuadrado de color con iniciales.

Hoy hay 5 temas reales (ver `licencias.md`), recortados a **sus primeros 30 s** y con el volumen igualado: así arrancan en la parte que se reconoce
y pesan 2,6 MB en total. Un recorte de menos de un minuto se reproduce desde el
principio; un tema entero arranca en un punto al azar de la mitad. El volumen se
ajusta con `volumen_temas` en el Inspector (bus Música).

**Mientras suena, NO baja nada:** aburrido, el tema suena apagado (filtro del
bus Loopify), no más bajo.

### La mezcla del final

En los últimos ~30 s suena todo junto (TikToks, Subway, casino, Preguntados, la
tele, la música) y tiene que ser **agobiante, pero con la música entendible**.
No se logra bajando lo demás (con 10 dB de *ducking* solo se escuchaba la
música): se logra dándole a cada fuente **su lugar**. Test: `mezcla_test.gd`.

- **Estéreo, según dónde está la ventana:** TikTok a la izquierda (-0,35), Subway
  centro-izquierda (-0,15), casino y Preguntados a la derecha (+0,35), la música
  al centro. La tele ya suena desde la derecha porque es 3D.
- **Frecuencias:** la música se queda con los graves y tiene un hueco en los
  medios, donde hablan los videos. TikTok suena sin graves, como el parlante de
  un celular. La tele, opaca y de fondo.
- **Volúmenes:** música -16,8 · TikTok -19 · Subway -20,3 · tele -23,8 (LUFS
  estimados). La música arriba, pero a menos de 5 dB del resto.
- **Un compresor en el Master** pega todo en una masa densa y no deja que sature.
  Con umbral alto: en la pieza o el parque ni se entera.
- **Los videos están igualados:** el audio de todos los TikToks (-16 LUFS) y
  canales de Subway (-17) se normalizó; antes variaban hasta 17 dB. Los `.bat` de
  conversión ya igualan solos los videos nuevos.
- **Buses nuevos:** `Slop` (el video de Subway, antes iba por Apps) y `Tele` (la
  TV, antes iba por Ambiente). **Ambiente no se tocó**: ahí siguen los pasos, el
  zumbido y el parque, que no tienen que sonar opacos. Apps tampoco cambió de
  volumen (la palanca suena igual).
- ⚠ El corrector de tono del 2x de TikTok tiene que seguir siendo el **efecto 0**
  del bus Video: `app_scroll.gd` lo prende por índice.
- `AudioManager.agachar()` sigue existiendo con `AGACHE_DB = 0`. Si en algún
  momento la música no se entiende, subirlo a 2 o 3 como mucho.

**Para agregar uno:** recortar los primeros 30 s, igualarlo a -14 LUFS y
convertirlo a .ogg (como los que están), y dejar la tapa con el mismo nombre.

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

**Ya están** (ver `licencias.md`): la **notificación** de app instalada, el
**paso** de la pieza y la **caminata en ripio** del parque.

**Los pasos suenan de dos formas** (`jugador.gd`, test: `tools/tests/pasos_test.gd`):

- **Pieza — pasos sueltos.** Un sonido por tranco, por distancia recorrida (casi 3
  por segundo a 5 m/s). Toma todos los sonidos de `assets/audio/pasos/pieza/` y
  nunca repite la misma variante dos veces seguidas: hoy hay una sola, así que
  agregar 3 o 4 más la haría sonar más natural. Cada paso varía un poco el tono.
- **Parque — caminata continua.** La grabación de ripio suena **en loop mientras
  se camina**, se apaga en 0,25 s al parar y queda **pausada**: al volver a caminar
  sigue desde donde quedó, así no arranca siempre con el mismo paso. Se calla
  también sentado en el banco. Se elige con `caminata_continua` (en `parque.gd`).

El volumen de los dos se ajusta con `volumen_pasos` en el Inspector del Jugador
(bus Ambiente). Los archivos se subieron de volumen al convertirlos, porque los
originales eran muy bajos (el paso tenía el pico en -30 dB).
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
- **Loopify**: temas en `assets/audio/loopify/`, con nombre `Artista - Tema.mp3`.

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

### La noche y el día siguiente (antes del parque)

Antes, al apagarse la compu era de noche y la puerta llevaba a un parque al
atardecer. Ahora hay un capítulo corto (menos de un minuto) en el medio.
Todo está en `habitacion.gd` (sección "La noche y el dia siguiente").
Test: `dia2_test.gd`.

1. **La noche:** al levantarse después del apagón la puerta no deja salir
   (*"Ya es re tarde... mañana salgo."*) y la cama pasa a decir **[E] Dormir**.
   Si se llegó por un atajo de prueba antes de las 23:00, el reloj salta a la noche.
2. **Dormir:** se apaga la luz (con el click del interruptor), la cámara se
   acuesta en la almohada mirando el techo, y funde a negro. El cuerpo se
   esconde mientras se acuesta: no tiene animación de acostarse.
3. **Martes, 11:00:** el mismo despertar del lunes, con el reloj en las 11
   (`escritorio.poner_hora()`; el ciclo del día pone el sol solo), el jugador
   donde se despertó ayer, la luz apagada, sin el zumbido de la compu y con
   pájaros entrando por la ventana.
4. **La compu no prende:** el monitor dice "Prender la compu"; al tocarlo suena
   el click del botón y nada (*"No prende. Quedó desenchufada desde el
   apagón."*). No te sienta y la partida no arranca.
5. **La puerta, ahora sí,** lleva al parque (que sigue al atardecer).

**El cartel del día** (`escenas/comun/cartel_dia.gd`): cada despertar arranca
con "Lunes / 08:00" (o "Martes / 11:00") abajo a la izquierda, sobre el negro.
El día se revela de izquierda a derecha con borde difuso, se dibuja una línea
fina y la hora entra con las letras juntándose. Se va mientras aparece la pieza.
Fuentes: Cormorant Garamond itálica (el día) y DM Mono Light (la hora), en
`assets/fuentes/` (OFL). El negro del despertar pasó de 3 a 6 s y el
despertador suena con el cartel ya escrito (`DEMORA_DESPERTADOR`).

⚠ **Faltan los pájaros:** `assets/audio/ambiente/pajaros.ogg` (el mismo que usa
el parque). Con el archivo ahí, suenan solos en la pieza el martes y en el
parque. Textos nuevos en `pensamientos.json`: `puerta_noche`,
`compu_desenchufada`, `cama_manana`.

### El cuerpo del jugador (solo sombra)

El jugador tiene un cuerpo low poly que **solo hace sombra** (`Solo sombras`): la
camara esta adentro de la cabeza y nunca lo ve, pero en las sombras de la pieza y
el parque se ve una persona que camina, se sienta y gira la cabeza.
Test: `cuerpo_test.gd`.

- **El modelo:** `assets/modelos/personaje/Male.fbx` (original, en T-pose, sin
  esqueleto). `tools/hornear_personaje.gd` lo para, lo escala a **1,80 m** (la
  camara quedo donde estaba, un poco mas arriba que los ojos), lo "arma" (brazos
  mas gruesos, algo mas de hombros y piernas: el modelo es flaco y en la sombra
  los brazos se perdian), le **genera un esqueleto de 17 huesos y reparte los
  pesos** de cada vertice (suaves en codos, rodillas, hombros y cadera). Sale
  `personaje.res` (la malla) y `escenas/01_habitacion/cuerpo.tscn` (la escena).
  Volver a correrlo si se cambia el modelo.
- **Las animaciones son procedurales** (`cuerpo.gd`), sin clips:
  - Quieto: respira, brazos separados del cuerpo (ojo: la T-pose del modelo ya
    baja los brazos ~22 grados; `BRAZOS_ABAJO` se mide desde la horizontal).
  - Caminando (el parque, 2,4 m/s): piernas, rodillas, brazos al reves de las
    piernas y un poco de rebote. El paso avanza por DISTANCIA, con el largo que
    da la pierna, asi los pies no patinan. Para atras se invierte; de costado la
    cadera gira hacia donde va.
  - Trotando (la pieza, 5 m/s): codos doblados, mas rodilla, mas inclinado. Ahi
    el paso usa el mismo tranco que los sonidos de pasos: medio ciclo = un paso.
  - Sentado: se sienta **solo cuando la camara baja** (la silla y el banco ya la
    bajan con su tween); no hubo que tocar habitacion.gd ni parque.gd. La cadera va
    donde da la camara y las canillas buscan el piso.
  - La cabeza (y un poco el pecho) mira hacia donde mira la camara.
- **Sombras:** a las luces de la pieza y al sol del parque se les bajo el *bias*
  (estaba en los valores por defecto y despegaba la sombra de los pies). No se
  toco ni color ni intensidad. La luz de la ventana es un parche: la sombra del
  cuerpo solo se ve adentro del rectangulo de sol, y afuera termina recta. Es
  correcto, no un error.
- No tiene animacion propia para el vape ni el celular (a pedido).
