# Dopamine Rush — Paso a Paso v4

Guía operativa. Cada paso tiene un criterio de "listo".
Para entender **cómo funciona** el proyecto, leer `guia_proyecto.md`.
Para el detalle de cada app, leer `plan_apps.md`.

---

## Método

1. **Lo desconocido primero, lo tedioso después.** Si algo va a salir mal, mejor enterarse temprano.
2. **Feo antes que lindo.** El arte llega en la Fase F, cuando ya sabemos que el juego funciona.
3. **Cada persona, un archivo.** Nadie edita la escena de otro.
4. **Probar en voz alta.** Si algo "parece que anda", no anda.

---

# ✅ LO QUE YA ESTÁ

### Núcleo
- [x] `game_manager.gd` — rampa continua de drenaje, ofertas por umbral, luna de miel, tropiezo único, fin del día, etapa final
- [x] `audio_manager.gd` — buses, catálogo de sonidos, fundidos
- [x] `scene_loader.gd` — cambio de escena con fundido
- [x] `app_base.gd` — contrato de las apps, con `posicion_ventana`

### Escritorio
- [x] Barra de dopamina, reloj, barra de 7 íconos
- [x] Ventanas: abrir, cerrar, arrastrar, traer al frente, posición configurable por app
- [x] Cartel de oferta conectado al núcleo
- [x] Tropiezo (primera caída) y fin del día (segunda caída)
- [x] Atajo de prueba: tecla **O** salta al colapso

### Mundo 3D
- [x] Jugador FPS con raycast e interacción
- [x] Dos modos de mirar: de pie (gira el cuerpo) y sentado (gira solo la cámara, con tope)
- [x] Objetos interactuables que se apagan cuando cumplen su función
- [x] Secuencia de despertar: negro + despertador + fundido
- [x] Monitor 3D con SubViewport e input traducido
- [x] Sentarse y levantarse sin cortes
- [x] Colapso (versión mínima) y puerta al parque
- [x] Parque mínimo, menú principal

### Apps
- [x] **TikBrainRot** (`scroll`) — cooldown de video, 2x al mantener apretado, recompensa variable
- [x] **Family Savings™** (`slots`) — palanca posicional, giro como cooldown, casi-premios, paywall con botón que se escapa

---

# ▶ EN QUÉ PUNTO ESTAMOS

Faltan **4 apps**, el **vape**, y después todo lo de arte, balanceo y pulido.

El juego ya se puede jugar de punta a punta: menú → despertar → sentarse → dos apps reales + placeholders → colapso → levantarse → parque.

---

# FASE D — Las apps que faltan

> Antes de arrancar cualquiera, leer la sección 7 de `guia_proyecto.md`.
> **El orden de armado no es opcional:** definir `tamano_ventana` → poner el `Size` del nodo raíz igual → recién ahí acomodar el contenido, anclando cada hijo.

### Paso 30 — Subway Slop (`subway`)
- Carpeta `03_apps/app_03_subway/`. Tamaño `380×680` vertical. Posición `(600, 180)`.
- Goteo pasivo mientras corre. Cada cierto tiempo **aleatorio** el personaje choca y el goteo se corta. Hay que clickear para reiniciar.
- El intervalo aleatorio es lo importante: si fuera fijo, el jugador lo rutiniza y deja de mirar.
- No necesita gameplay real: rectángulos moviéndose alcanzan. El jugador no lo controla, solo lo vigila.
- **Listo cuando:** funciona sola con F6 y suma dopamina al reiniciar.

### Paso 31 — Lingofy (`racha`)
- Carpeta `03_apps/app_04_racha/`. Tamaño `460×520`. Posición `(1150, 600)`.
- Cada ~10 segundos aparece una pregunta de opción múltiple con unos segundos para responder.
- Bien → dopamina + racha sube. Mal o sin responder → **la racha se rompe y perdés dopamina**.
- El multiplicador **solo afecta a esta app**, sube 0.1 por acierto y **topa en 2.0**. Así no desequilibra el juego.
- **Listo cuando:** se puede ganar y perder la racha, y el multiplicador se ve.

### Paso 32 — Kompralo! (`ofertas`)
- Carpeta `03_apps/app_05_ofertas/`. Tamaño `520×420`. Posición `(100, 520)`.
- Aparece un producto con un contador de ~5 segundos. Si clickeás a tiempo, dopamina. Si no, se pierde.
- Es la única app que te **apura**: todas las demás van a tu ritmo.
- Un contador de "$ gastado hoy" que solo sube. Los productos son absurdos y nunca llega nada.
- **Listo cuando:** ídem.

### Paso 33 — Loopify (`musica`)
- Carpeta `03_apps/app_06_musica/`. Tamaño `560×320`. Posición `(660, 760)`.
- No da dopamina propia: **multiplica la de las otras** (×1.3) mientras suena. La canción se termina cada ~40 s y hay que elegir otra.
- ⚠ **Toca `app_base.gd`** (el multiplicador se aplica en `recompensar()`). Coordinar antes.
- **Listo cuando:** ídem.

### Paso 34 — LinkedOut (`linkedin`)
- Carpeta `03_apps/app_07_linkedin/`. Pantalla completa. Posición `(0, 0)`.
- **No se abre desde el ícono: se abre sola** y tapa todo. Hay que cerrarla para seguir.
- Cerrarla da una miga de dopamina. Su función real es robar tiempo y esconder lo que estabas mirando.
- Escalada: al principio cada ~45 s, en la etapa final cada ~12 s.
- ⚠ **Toca `app_base.gd` y `escritorio.gd`** (hace falta un `intervalo_apertura` y un temporizador en el escritorio).
- **Listo cuando:** aparece sola y se cierra con la X.

> **Los pasos 33 y 34 son los únicos que tocan archivos compartidos.** Conviene que los haga la misma persona, o que esos cambios se hagan primero y de una sola vez, antes de que los demás avancen.

### Paso 35 — Coordinación del caos
Con las seis juntas, verificar entre todos:
- Que las `posicion_ventana` no se pisen
- Que los sonidos ocupen rangos de frecuencia distintos (una grave, una media, una aguda)
- Que las acciones premiadas sean realmente distintas entre sí
- Si la pantalla queda vacía, definir una séptima app
- **Listo cuando:** con las seis abiertas se puede jugar sin que ninguna tape a otra injustamente.

> **HITO:** el juego completo, feo, jugable de punta a punta.

---

# FASE E — Lo que falta del mundo 3D

### Paso 36 — El vape
> Es lo único que rompe el plano de la pantalla. Te obliga a soltar el mouse, mirar al costado, hacer algo con el cuerpo.

- Va en `habitacion.gd`, no es una app.
- Cooldown de ~25-30 s. Un indicador discreto avisa cuando está listo.
- Al activarlo: la cámara gira al costado y se acerca al vape (tween, como el de sentarse).
- Minijuego breve: mantener apretado mientras una barra se llena, o girar la rueda del mouse.
- Al terminar: golpe grande de dopamina (~60), viñeteado, sonido. La cámara vuelve.
- **Lo que lo hace un trade-off real:** mientras vapeás no podés atender las apps y la barra sigue bajando.
- No hace falta modelar una mano: con el movimiento de cámara, un viñeteado y el sonido alcanza.
- **Listo cuando:** se puede usar, se siente bien, y cuesta tiempo real.

### Paso 37 — Encuadre del monitor
- Ajustar `PuntoSentado` hasta que la pantalla llene bien el campo visual y el marco del monitor se vea alrededor.
- Puro tanteo: mover el marker, probar, repetir.
- **Listo cuando:** se lee claramente que estás frente a un monitor dentro de una habitación.

### Paso 38 — El colapso completo
Hoy hay una versión mínima. Falta:
- Apagar **todas** las luces en el mismo frame
- `AudioManager.silenciar_todo()`
- 2-3 segundos de negro y **silencio absoluto**, sin texto ni música
- Encender muy tenue la luz de la ventana
- **Listo cuando:** el corte se siente seco, no un fundido. Que no quede claro si se cortó la luz o si el personaje se desmayó.

> El silencio es el efecto principal de toda la obra. La tentación va a ser rellenarlo. Hay que resistirla.

---

# FASE F — Ambientes y gráficos

### Paso 39 — Dirección de arte
- Definir una referencia visual y guardarla. **Los dos ambientes tienen que salir del mismo pack de assets** o el corte se va a notar.
- Recomendado: habitación en penumbra, luz fría azulada, el monitor como única fuente cálida. El parque al revés.
- **Listo cuando:** hay 3-5 imágenes de referencia y todo el equipo las vio.

### Paso 40 — Modelos de la habitación
- Un solo pack low-poly en `.glb`: **kenney.nl**, **poly.pizza**, **quaternius.com** (todos CC0).
- Necesario: cama, escritorio, silla, monitor, despertador, ventana, puerta, 2-3 objetos de relleno.
- **Anotar todo en `docs/licencias.md` al momento de descargar.**
- **Listo cuando:** la habitación se lee como una habitación.

### Paso 41 — Colisiones e iluminación
- Por cada mesh: seleccionar → menú `Mesh` → `Create Trimesh Static Body`.
- `WorldEnvironment` + `DirectionalLight3D` por la ventana + `OmniLight3D` en el monitor.
- **Listo cuando:** no se atraviesa ningún mueble y el monitor es la fuente de luz dominante.

### Paso 42 — El parque
- Pack de naturaleza CC0. Área caminable chica (~30×30) rodeada de árboles densos y niebla.
- Jugador con `velocidad` a ~3.0. El cuerpo se siente distinto.
- Audio: pájaros y viento. **Sin música.**
- **Nada que hacer.** Sin objetivos, sin barra, sin coleccionables.
- **Listo cuando:** el contraste con la habitación es evidente al entrar.

### Paso 43 — Interfaz del escritorio
- Wallpaper real, íconos dibujados, tipografía elegida, estilo de ventana coherente.
- Cada app con su identidad visual (que parodien sin copiar logos reales).
- **Listo cuando:** la pantalla se lee como un sistema operativo y no como un prototipo.

### Paso 44 — Videos reales en TikBrainRot (opcional)
- Godot importa video en **Ogg Theora**. Convertir con ffmpeg o HandBrake.
- **Bajar a 360p o menos** — la ventana mide 400 px, decodificar 1080p es trabajo tirado.
- **Antes de convertir 30, probar con 2** reproduciéndose a la vez, en la computadora más lenta del grupo.
  ```
  ffmpeg -i entrada.mp4 -vf scale=-2:640 -c:v libtheora -q:v 6 -c:a libvorbis salida.ogv
  ```

### Paso 45 — Final del parque
- Un banco interactuable → fundido a blanco lento → créditos.
- **Listo cuando:** el juego termina.

---

# FASE G — Balanceo

> Se hace **después** del arte: lo mismo se siente más difícil con audio saturado y pantalla temblando.

### Paso 46 — Que las apps rindan parecido
- Medir cuánta dopamina por segundo da cada app si se la atiende bien.
- Lo que importa no es la dopamina por click sino **por segundo de atención robada**.
- **Por qué:** si una rinde el doble, el jugador usa solo esa y las otras cinco sobran.
- **Listo cuando:** ninguna app es obviamente mejor que las otras.

### Paso 47 — Sesión de balanceo
- Jugar de punta a punta cronometrando. Objetivo: **6-10 minutos**.
- Si dura menos, bajar `RAMPA`. Si dura más, subirla.
- Anotar **en qué minuto se aburrieron** — ese dato importa más que la dificultad.
- **Un solo número por sesión de prueba.**
- **Listo cuando:** tres partidas seguidas caen dentro del rango.

### Paso 48 — Tolerancia (opcional)
- Solo si tras balancear la rampa el juego se siente monótono.
- `USAR_TOLERANCIA = true` en `game_manager.gd`.
- **Listo cuando:** se decidió si va o no, y quedó documentado por qué.

---

# FASE H — Juicy

> **Principio: toda acción del jugador devuelve algo en tres canales — visual, sonoro y de movimiento.**

### Paso 49 — Feedback de la barra
- Sube con tween suave, no de golpe. Destello al recibir dopamina.
- Latido cuando está en rojo, más rápido cuanto más baja. Temblor en los últimos segundos.
- **Listo cuando:** se puede saber cómo va la partida sin leer la barra.

### Paso 50 — Feedback de las apps
- Número flotante que sube y se desvanece. Escalado rápido del elemento (5%, 0.15 s).
- Sonido corto y distinto por app. Partículas mínimas en los aciertos grandes.
- **Listo cuando:** scrollear un video se siente bien aunque no dé nada.

### Paso 51 — Ventanas con vida
- Abrir con scale desde 0.9 y fade (0.2 s). Sombra bajo la ventana activa.
- Sonido distinto para abrir y cerrar.
- **Listo cuando:** abrir una ventana se siente como un gesto.

### Paso 52 — El cartel de oferta
- Entra deslizándose, con sonido de notificación. El botón pulsa.
- **Es el momento donde el juego te está vendiendo algo:** tentador, no informativo.
- **Listo cuando:** dan ganas de clickearlo.

### Paso 53 — Escalada sensorial
- La interfaz se degrada a medida que sube el drenaje: colores más saturados, movimiento más nervioso, leve zoom.
- En la etapa final: aberración cromática, temblor, distorsión en el bus `Master`.
- **Listo cuando:** los últimos dos minutos son físicamente incómodos de mirar.

---

# FASE I — Entrega

### Paso 54 — Créditos
- Nombres del equipo y rol de cada uno. **Todas** las atribuciones de `docs/licencias.md`. Materia y año.

### Paso 55 — Limpieza
Sacar todo lo de prueba:
- El atajo de la tecla **O** en `escritorio.gd` (función `_forzar_colapso`)
- Cualquier `print()` de diagnóstico
- `escenas/prueba_nucleo.tscn`
- `app_placeholder.tscn`, si ya no se usa
- `forzar_2x_desbloqueado` de TikBrainRot, en `false`

### Paso 56 — Configuración final
- `Main Scene` = `menu.tscn`
- **Window Override en 0** y Mode en `Fullscreen`
- **Listo cuando:** F5 arranca desde el menú a pantalla completa.

### Paso 57 — Playtest externo
- 4-5 personas de afuera del equipo.
- **No explicar nada. No hablar durante.** Verlos trabarse es la información valiosa.
- Anotar dónde miran, dónde se traban, en qué minuto se aburren.
- Preguntar al final: *¿de qué te pareció que trataba?* y *¿cómo te sentiste en el minuto 8?*

### Paso 58 — Ajuste final
- **La pregunta que importa:** ¿sintieron alivio al llegar al parque? Si no, subir la intensidad de la etapa final.

### Paso 59 — Exportar
- `Project → Export`, instalar plantillas si Godot las pide.
- Probar el ejecutable en una computadora sin Godot instalado.

---

## Checklist de hitos

- [x] Núcleo, escritorio y mundo 3D completos
- [x] Dos apps terminadas
- [ ] **Las seis apps funcionando juntas**
- [ ] El vape
- [ ] Colapso completo y encuadre
- [ ] Arte y ambientes
- [ ] Balanceado, 6-10 minutos
- [ ] Juicy
- [ ] Entregado
