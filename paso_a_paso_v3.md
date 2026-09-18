# Dopamine Rush — Paso a Paso v3

Guía operativa. Cada paso tiene un criterio de "listo".
Para entender **cómo funciona** el proyecto, leer primero `guia_proyecto.md`.

---

## Método

1. **Lo desconocido primero, lo tedioso después.** Si algo va a salir mal, mejor enterarse temprano.
2. **Feo antes que lindo.** El arte llega en la Fase F, cuando ya sabemos que el juego funciona.
3. **Una app completa antes que siete a medias.**
4. **Cada persona, un archivo.** Nadie edita la escena de otro.
5. **Probar en voz alta.** Si algo "parece que anda", no anda.

---

## ✅ FASES A-C — COMPLETADAS

### Fase A — Núcleo
- [x] `game_manager.gd` con rampa continua, ofertas, luna de miel, tropiezo único y fin del día
- [x] `scene_loader.gd` con fundidos
- [x] `audio_manager.gd` con buses, catálogo y fundidos
- [x] `barra_dopamina.tscn`
- [x] `app_base.gd`

### Fase B — Escritorio
- [x] Contenedor de ventanas, barra de íconos (7)
- [x] Abrir / cerrar / traer al frente ventanas
- [x] `cartel_oferta.tscn` conectado al núcleo
- [x] Tropiezo y pantalla de fin del día

### Fase C — Primera app
- [x] TikBrainRot completa e integrada
- [ ] **Paso 29 — Documentar el molde en `docs/bitacora.md`** ← pendiente

### Fase E (adelantada) — Integración 3D
- [x] Jugador FPS con raycast, dos modos de mirar
- [x] Secuencia de despertar
- [x] Monitor 3D con SubViewport e input traducido
- [x] Sentarse / levantarse
- [x] Colapso (versión mínima)
- [x] Puerta al parque + parque mínimo

---

# FASE D — Las seis apps restantes

> Se hacen en paralelo, una persona cada una. Todas siguen el contrato de la sección 7 de `guia_proyecto.md`.
> Antes de empezar, leer esa sección entera. El orden de armado (tamaño primero, anclar después) no es opcional.

### Paso 30 — Family Savings™ (`slots`)
- Carpeta `03_apps/app_02_slots/`. `tamano_ventana` horizontal, tipo `(700, 460)`.
- Tirás → animación de unos segundos → aparece un premio que **hay que ir a recoger** antes de que se pierda.
- Es la app que le enseña al jugador el ritmo de irse y volver a otra ventana.
- **Listo cuando:** funciona sola con F6 y suma dopamina al cobrar.

### Paso 31 — Subway Slop (`subway`)
- Gameplay de fondo que da dopamina pasiva. El personaje muere cada tanto y hay que reiniciarlo.
- Por ahora, rectángulos moviéndose alcanzan como placeholder.
- **Listo cuando:** ídem.

### Paso 32 — Chatly (`chat`)
- El corazón emocional del juego. Llegan mensajes, se responde eligiendo entre respuestas sugeridas.
- **Todas las respuestas disponibles son vacías** ("jaja", "sisi", "dale").
- Si se la ignora, el tono de los mensajes cambia y se vuelve personal.
- **Listo cuando:** ídem.

### Paso 33 — Loopify (`musica`)
- No da dopamina propia: **multiplica la de las otras** mientras suena.
- Implementación: una variable global de multiplicador que lee `recompensar()`. **Requiere tocar `app_base.gd`, así que coordinar con el equipo.**
- La canción se termina cada tanto y hay que elegir otra.
- **Listo cuando:** ídem.

### Paso 34 — PingMe (`notificaciones`)
- No se abre: **aparece sola**, encima de las otras ventanas, tapándolas.
- Se cierra con un click y da una miga de dopamina.
- Su función real es robar tiempo y esconder lo que estabas mirando.
- **Listo cuando:** ídem.

### Paso 35 — StreamPlus (`serie`)
- Da dopamina sola, poquita. Cada 20-30 segundos aparece "¿Seguís ahí?" y si no se clickea, se corta.
- **La más prescindible.** Si falta tiempo, se corta esta.
- **Listo cuando:** ídem.

### Paso 36 — Coordinación del caos
Con las siete juntas, verificar entre todos:
- Que no se abran en la misma zona de la pantalla (ajustar `POSICION_INICIAL` y `OFFSET_VENTANA` en `escritorio.gd`, o pasar a una lista de posiciones fijas por app)
- Que sus sonidos ocupen rangos de frecuencia distintos
- Que las acciones premiadas sean realmente distintas entre sí
- **Listo cuando:** con las siete abiertas se puede jugar sin que ninguna tape a otra de forma injusta.

> **HITO:** el juego completo, feo, jugable de punta a punta.

---

# FASE E — Lo que falta de la integración

### Paso 37 — Encuadre del monitor
- Ajustar `PuntoSentado` hasta que la pantalla llene bien el campo visual y el marco del monitor se vea alrededor.
- Puro tanteo, sin código: mover el marker, probar, repetir.
- **Listo cuando:** se lee claramente que estás frente a un monitor dentro de una habitación.

### Paso 38 — El colapso completo
Hoy hay una versión mínima. Falta:
- Apagar **todas** las luces de la habitación en el mismo frame
- `AudioManager.silenciar_todo()`
- 2-3 segundos de negro y **silencio absoluto**, sin texto ni música
- Encender muy tenue la luz de la ventana
- **Listo cuando:** el corte se siente seco, no un fundido. Que no quede claro si se cortó la luz o si el personaje se desmayó.

> El silencio es el efecto principal de toda la obra. La tentación va a ser rellenarlo. Hay que resistirla.

### Paso 39 — Reinicio del día completo
- `_al_empezar_nuevo_dia()` de `escritorio.gd` debería recargar la habitación entera en vez de resetear a mano:
  ```gdscript
  GameManager.reiniciar()
  SceneLoader.cambiar_escena("res://escenas/01_habitacion/habitacion.tscn")
  ```
- Así el jugador vuelve a despertarse con el despertador.
- **Listo cuando:** arruinar el día devuelve al principio de verdad.

---

# FASE F — Ambientes y gráficos

### Paso 40 — Dirección de arte
- Definir una referencia visual y guardarla.
- Recomendado: habitación en penumbra, luz fría azulada, el monitor como única fuente cálida. El parque al revés: luz cálida, espacio abierto.
- El contraste entre los dos es lo que hace funcionar el final.
- **Listo cuando:** hay 3-5 imágenes de referencia y todo el equipo las vio.

### Paso 41 — Modelos de la habitación
- Un solo pack low-poly en `.glb`: **kenney.nl**, **poly.pizza**, **quaternius.com** (todos CC0).
- La consistencia de un pack único vale más que la calidad individual de cada mueble.
- Necesario: cama, escritorio, silla, monitor, despertador, ventana, puerta, 2-3 objetos de relleno.
- **Anotar todo en `docs/licencias.md` al momento de descargar.**
- **Listo cuando:** la habitación se lee como una habitación.

### Paso 42 — Colisiones e iluminación
- Por cada mesh: seleccionar → menú `Mesh` → `Create Trimesh Static Body`.
- `WorldEnvironment` (sin él Godot 4 renderiza plano) + `DirectionalLight3D` por la ventana + `OmniLight3D` en el monitor.
- **Listo cuando:** no se atraviesa ningún mueble y el monitor es la fuente de luz dominante.

### Paso 43 — El parque
- Pack de naturaleza CC0. Plano de pasto, árboles, un banco, un camino.
- Área caminable chica (~30×30) rodeada de árboles densos y niebla: se siente amplio sin serlo.
- Jugador con `velocidad` bajada a ~3.0. El cuerpo se siente distinto.
- Audio: solo pájaros y viento. **Sin música.**
- **Nada que hacer.** Sin objetivos, sin barra, sin coleccionables. Cualquier cosa que se agregue traiciona el punto.
- **Listo cuando:** el contraste con la habitación es evidente al entrar.

### Paso 44 — Interfaz del escritorio
- Reemplazar los cuadrados de colores: wallpaper real, íconos dibujados, tipografía elegida, estilo de ventana coherente.
- Cada app con su identidad visual (que se parezcan a las apps que parodian sin copiar logos reales).
- **Listo cuando:** la pantalla se lee como un sistema operativo y no como un prototipo.

### Paso 45 — Videos reales en TikBrainRot (opcional)
- Godot importa video en **Ogg Theora**. Hay que convertir con ffmpeg o HandBrake.
- **Bajar la resolución a 360p o menos** — la ventana mide 400 px, decodificar 1080p es trabajo tirado.
- **Antes de convertir 30, probar con 2** reproduciéndose a la vez y mirar los FPS en la computadora más lenta del grupo.
- Comando de referencia:
  ```
  ffmpeg -i entrada.mp4 -vf scale=-2:640 -c:v libtheora -q:v 6 -c:a libvorbis salida.ogv
  ```

### Paso 46 — Final del parque
- Un banco interactuable → fundido a blanco lento → créditos.
- **Listo cuando:** el juego termina.

---

# FASE G — Balanceo

> Se hace **después** del arte: el arte cambia cómo se percibe la dificultad. Lo mismo se siente más difícil con audio saturado y pantalla temblando.

### Paso 47 — Que las apps rindan parecido
- Medir cuánta dopamina por segundo da cada app si se la atiende bien.
- Ajustar `dopamina_por_interaccion` de cada una hasta que rindan similar.
- **Por qué:** si una rinde el doble, el jugador usa solo esa y las otras seis sobran.
- **Listo cuando:** ninguna app es obviamente mejor que las otras.

### Paso 48 — Sesión de balanceo
- Jugar de punta a punta cronometrando. Objetivo: **6-10 minutos**.
- Si dura menos, bajar `RAMPA`. Si dura más, subirla.
- Anotar **en qué minuto se aburrieron** — ese dato importa más que la dificultad.
- **Un solo número por sesión.**
- **Listo cuando:** tres partidas seguidas caen dentro del rango.

### Paso 49 — Tolerancia (opcional)
- Solo si tras balancear la rampa el juego se siente monótono.
- `USAR_TOLERANCIA = true` en `game_manager.gd` y ajustar `TOLERANCIA_CAIDA`.
- Efecto: la misma acción rinde cada vez menos.
- **Listo cuando:** se decidió si va o no, y quedó documentado por qué.

---

# FASE H — Juicy

> Que cada acción se sienta satisfactoria. Es la fase que más cambia la percepción del juego por menos trabajo.
> **Principio: toda acción del jugador devuelve algo en tres canales — visual, sonoro y de movimiento.**

### Paso 50 — Feedback de la barra
- Que suba con un tween suave, no de golpe
- Destello blanco al recibir dopamina
- Latido cuando está en rojo, más rápido cuanto más baja
- Temblor sutil de toda la pantalla en los últimos segundos
- **Listo cuando:** se puede saber cómo va la partida sin leer la barra.

### Paso 51 — Feedback de las apps
- Número flotante (`+8`) que sube y se desvanece
- Escalado rápido del elemento (crece 5% y vuelve, en 0.15 s)
- Sonido corto y distinto por app
- Partículas mínimas en los aciertos grandes
- **Listo cuando:** scrollear un video se siente bien aunque no dé nada.

### Paso 52 — Ventanas con vida
- Que se abran con scale desde 0.9 y fade rápido (0.2 s), no de golpe
- Sombra bajo la ventana activa
- Sonido distinto para abrir y cerrar
- **Listo cuando:** abrir una ventana se siente como un gesto.

### Paso 53 — El cartel de oferta
- Que entre deslizándose, con sonido de notificación
- Que el botón pulse para invitar al click
- **Es el momento donde el juego te está vendiendo algo:** tiene que verse tentador, no informativo
- **Listo cuando:** dan ganas de clickearlo.

### Paso 54 — Escalada sensorial
- Que la interfaz se degrade a medida que sube el drenaje: colores más saturados, movimiento más nervioso, leve zoom
- En la etapa final: aberración cromática, temblor, distorsión en el bus `Master`
- **Listo cuando:** los últimos dos minutos son físicamente incómodos de mirar.

---

# FASE I — Menú, créditos y entrega

### Paso 55 — `menu.tscn`
- Título, "Comenzar", "Salir". Nada más. Sin opciones.
- El mismo zumbido bajo que la habitación al empezar.
- **Listo cuando:** "Comenzar" carga la habitación.

### Paso 56 — `creditos.tscn`
- Nombres del equipo y rol de cada uno
- **Todas** las atribuciones de `docs/licencias.md`
- Materia y año
- **Listo cuando:** están completos y correctos.

### Paso 57 — Escena principal
- `Project Settings → Application → Run → Main Scene` = `menu.tscn`
- Poner los **Window Override en 0** y el Mode en `Fullscreen`
- **Listo cuando:** F5 arranca desde el menú a pantalla completa.

### Paso 58 — Playtest externo
- 4-5 personas de afuera del equipo
- **No explicar nada. No hablar durante.** Verlos trabarse es la información valiosa.
- Anotar dónde miran, dónde se traban, en qué minuto se aburren
- Preguntar al final: *¿de qué te pareció que trataba?* y *¿cómo te sentiste en el minuto 8?*
- **Listo cuando:** hay notas de 4-5 sesiones.

### Paso 59 — Ajuste final
- Corregir según lo observado
- **La pregunta que importa:** ¿sintieron alivio al llegar al parque? Si no, subir la intensidad de la etapa final.
- **Listo cuando:** la duración es consistente y el final funciona.

### Paso 60 — Exportar
- `Project → Export`, instalar plantillas si Godot las pide
- Probar el ejecutable en una computadora sin Godot instalado
- **Listo cuando:** corre en otra máquina.

---

## Checklist de hitos

- [x] Núcleo, escritorio y primera app
- [x] Recorrido 3D completo (despertar → compu → colapso → parque)
- [ ] **Las siete apps funcionando juntas**
- [ ] Colapso completo y encuadre
- [ ] Arte y ambientes
- [ ] Balanceado, 6-10 minutos
- [ ] Juicy
- [ ] Entregado

---

## Reparto sugerido (6 personas)

| Rol | Ahora | Después |
|---|---|---|
| **Núcleo** | Integrar apps, colapso completo | Balanceo |
| **3D / Jugador** | Encuadre, reinicio del día | Habitación con modelos |
| **App A** | Family Savings™ | + StreamPlus, juicy |
| **App B** | Subway Slop | + Loopify, juicy |
| **App C** | Chatly | + PingMe, juicy |
| **Arte / Audio** | Buscar y catalogar assets, capas de audio | Parque, mezcla final |
