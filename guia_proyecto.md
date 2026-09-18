# Dopamine Rush — Guía del Proyecto

Documento de referencia. Si te acabás de sumar al proyecto, leé esto entero antes de tocar nada.
Última actualización: con TikBrainRot terminada y el recorrido 3D completo funcionando.

---

## 0. Cómo usar este documento con Claude

Si vas a trabajar con Claude (o cualquier asistente) en tu propia máquina:

1. **Pegá este documento completo al inicio de la conversación.** Sin el contexto de la arquitectura, cualquier asistente va a proponer soluciones que no encajan con lo que ya está construido.
2. **Pegá también los scripts relevantes** a lo que estés haciendo. Los más importantes son `game_manager.gd`, `app_base.gd` y `ventana_app.gd`.
3. **Aclarale que no puede cambiar los archivos compartidos** (sección 6). Si tu tarea parece requerir cambiarlos, avisale al equipo primero.
4. Cuando pidas ayuda con una app, mencioná explícitamente: *"tiene que heredar de AppBase y respetar el contrato de la sección 7"*.

---

## 1. Qué es el juego

Una experiencia de 6-10 minutos. El jugador se despierta, se sienta frente a una computadora y tiene que mantener una barra de dopamina arriba de cero usando apps. El drenaje sube continuamente: lo que alcanzaba hace un minuto ya no alcanza. Cuando la barra baja demasiado, el juego le **ofrece** una app nueva con un cartel publicitario. Acepta, respira un momento, y vuelve a ahogarse. Con siete apps abiertas y el drenaje disparado, ya no se puede. Corte. Negro. Se levanta y sale a un parque en silencio. Fin.

**La tesis:** el juego no trata sobre "las redes son malas". Trata sobre la **escalada**: que lo que ayer alcanzaba, hoy no. Todo el diseño existe para que eso se sienta en el cuerpo.

**Regla para evaluar cualquier idea nueva:** si no sirve para que se sienta la escalada o para que el contraste final pegue, no va.

---

## 2. Estado actual

### Terminado y funcionando
- Los tres autoloads: `GameManager`, `AudioManager`, `SceneLoader`
- Jugador en primera persona con raycast e interacción
- Habitación 3D (geometría provisoria) con el recorrido completo: despertar → apagar despertador → caminar → sentarse → jugar → colapso → levantarse → salir
- Monitor 3D con la interfaz renderizada dentro vía SubViewport, con el mouse funcionando sobre la pantalla
- Escritorio falso: barra de dopamina, reloj, barra de íconos, ventanas arrastrables, cartel de oferta, tropiezo, fin del día
- **TikBrainRot** (app 0) completa
- Parque mínimo (plano + cielo + luz)

### Pendiente
- **6 apps** (ver sección 8)
- Encuadre fino del monitor
- Secuencia completa del colapso (luces, silencio)
- Arte, audio real, balanceo, pulido, menú y créditos

### Provisorio, se va a reemplazar
- Toda la geometría de la habitación son cubos
- `escenas/prueba_nucleo.tscn` es descartable
- `escenas/03_apps/app_placeholder.tscn` se usa para las apps que faltan

---

## 3. Estructura del proyecto

```
res://
├── autoload/
│   ├── game_manager.gd          Dopamina, drenaje, ofertas, colapso
│   ├── audio_manager.gd         Capas de sonido, buses, fundidos
│   └── scene_loader.gd          Cambio de escena con fundido
│
├── escenas/
│   ├── 00_menu/                 (pendiente)
│   ├── 01_habitacion/
│   │   ├── habitacion.tscn/.gd  Escena principal del juego
│   │   ├── jugador.tscn/.gd     FPS, raycast, dos modos de mirar
│   │   └── interactuable.gd     Script reutilizable para objetos
│   ├── 02_computadora/
│   │   ├── escritorio.tscn/.gd  El "sistema operativo" falso
│   │   ├── ventana_app.tscn/.gd Marco de ventana reutilizable
│   │   ├── barra_dopamina.tscn/.gd
│   │   └── cartel_oferta.tscn   (sin script, lo maneja escritorio.gd)
│   ├── 03_apps/
│   │   ├── app_base.gd          CLASE MADRE — no se toca
│   │   ├── app_placeholder.tscn/.gd
│   │   ├── app_01_scroll/       TikBrainRot (terminada)
│   │   ├── app_02_slots/        (pendiente)
│   │   ├── app_03_subway/       (pendiente)
│   │   ├── app_04_chat/         (pendiente)
│   │   ├── app_05_musica/       (pendiente)
│   │   ├── app_06_notificaciones/ (pendiente)
│   │   └── app_07_serie/        (pendiente)
│   ├── 04_parque/parque.tscn
│   └── 05_creditos/             (pendiente)
│
├── assets/
│   ├── modelos/                 .glb descargados
│   ├── texturas/
│   ├── audio/
│   │   ├── ambiente/            sonidos 3D: despertador, pájaros
│   │   ├── apps/                una capa por app
│   │   ├── musica/
│   │   └── ui/                  clicks, notificaciones
│   ├── fuentes/
│   └── ui/                      íconos, wallpapers
│
└── docs/
    ├── guia_proyecto.md         ← este archivo
    ├── paso_a_paso.md           Qué hacer y en qué orden
    ├── licencias.md             ATRIBUCIONES — obligatorio
    └── bitacora.md              Qué hizo cada uno
```

---

## 4. Configuración del proyecto

| Ajuste | Valor | Dónde |
|---|---|---|
| Viewport | 1920 × 1080 | Display → Window |
| Window Override | 1600 × 900 (solo para desarrollar) | Display → Window |
| Stretch Mode | `canvas_items` | Display → Window → Stretch |
| Stretch Aspect | `keep` | Display → Window → Stretch |

**Importante:** el juego funciona internamente en 1920×1080. Los Override solo achican la ventana mientras desarrollás. En la entrega se ponen en 0.

### Input Map

| Acción | Tecla |
|---|---|
| `mover_adelante` | W |
| `mover_atras` | S |
| `mover_izquierda` | A |
| `mover_derecha` | D |
| `interactuar` | E |
| `pausa` | Esc |

### Buses de audio

`Master` → `Musica`, `Apps`, `Ambiente`, `UI`

Los nombres tienen que coincidir exactamente (mayúsculas incluidas) con los del `audio_manager.gd`.

---

## 5. Arquitectura: cómo se hablan las piezas

### El principio: nadie conoce a nadie

```
                    ┌─────────────────┐
                    │   GameManager   │  ← Autoload
                    │  dopamina, apps │
                    └────────┬────────┘
                             │ señales
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
   ┌─────────┐         ┌──────────┐         ┌──────────┐
   │ Barra   │         │  Apps    │         │Escritorio│
   └─────────┘         └──────────┘         └──────────┘
```

Las apps **no saben** que existe la barra. La barra **no sabe** que existen las apps. Todos hablan solo con `GameManager` a través de señales.

Esto es lo que permite que seis personas trabajen en paralelo sin pisarse, y lo que hace que se pueda cambiar el motor del juego por dentro sin romper nada de lo que cuelga.

### Señales del GameManager

| Señal | Cuándo se emite |
|---|---|
| `dopamina_cambio(valor, max)` | Cada frame que cambia la dopamina |
| `oferta_app(indice, titulo, texto, boton)` | La dopamina bajó del umbral: hay que mostrar el cartel |
| `app_desbloqueada(indice)` | El jugador aceptó la oferta |
| `etapa_final_iniciada()` | Ya no se puede ganar |
| `fallo_temprano()` | Primera caída a 0: tropiezo, se sigue |
| `dia_arruinado()` | Segunda caída: fin del día |
| `colapso()` | Caída a 0 en la etapa final: corte de luz |

### Cómo funciona la escalada

1. El drenaje **sube continuamente** con el tiempo (rampa). Nunca da saltos bruscos.
2. Cuando la dopamina baja del 35%, el juego **ofrece** una app nueva con un cartel publicitario.
3. El jugador acepta → la app se desbloquea, el drenaje pega un salto (`DRENAJE_POR_APP`) pero entra una **luna de miel**: el drenaje cae a un 45% y vuelve a la normalidad gradualmente en 20 segundos.
4. Ese vaivén es lo que da ritmo: tensión → alivio → tensión, cada ola más fuerte.
5. Cuando ya no quedan apps que ofrecer, 30 segundos después arranca la **etapa final**: el drenaje se dispara y el colapso es inevitable.

**La fase final es imposible de ganar a propósito.** El juego trata sobre una escalada sin techo; un final donde "ganás" contradiría la tesis. El jugador hace todo bien y pierde igual. Ahí es cuando entiende.

### Perder

- **Primera caída a 0** → tropiezo: pantalla tapada 3 segundos, revive con 30
- **Segunda caída** → fin del día: cartel "te aburriste, se te fue el día" + botón "Empezar un nuevo día"
- **En la etapa final** → colapso, corte de luz, parque

---

## 6. Archivos compartidos: NO SE TOCAN

Si tu tarea parece requerir cambiar alguno de estos, avisá al equipo antes:

- `autoload/game_manager.gd`
- `escenas/03_apps/app_base.gd`
- `escenas/02_computadora/ventana_app.tscn/.gd`
- `escenas/01_habitacion/jugador.gd` e `interactuable.gd`

**Regla general con Git: nadie edita una escena que no es suya.** Los `.tscn` se rompen feo al hacer merge y no hay forma cómoda de resolver el conflicto.

---

## 7. Cómo hacer una app (el contrato)

Esto es lo más importante del documento si te toca hacer una app.

### Estructura

```
escenas/03_apps/app_0X_nombre/
├── app_nombre.gd
└── app_nombre.tscn
```

### El script

```gdscript
extends AppBase        # ← NO "extends Control"

func _gui_input(event: InputEvent) -> void:
	# ...detectar la acción del jugador...
	recompensar()      # ← esto suma dopamina
```

`AppBase` te da gratis: `recompensar()`, `iniciar()`, `detener()`, las capas de audio, y las propiedades del Inspector.

### Propiedades en el Inspector (nodo raíz)

| Propiedad | Qué es |
|---|---|
| `Id App` | Identificador interno, sin espacios (`slots`, `chat`). Lo usa el AudioManager |
| `Nombre App` | Lo que ve el jugador |
| `Tamano Ventana` | El tamaño que va a tomar la ventana |
| `Dopamina Por Interaccion` | Cuánto da cada acción premiada |

### Las reglas

1. El nodo raíz tiene que ser un **`Control`** (o algo que herede de Control)
2. Heredar de `AppBase`
3. Llamar a `recompensar()` en la acción premiada
4. Tiene que funcionar sola con F6, sin el resto del juego
5. **Ninguna app puede pedir atención continua.** Todas piden atención en ráfagas y te dejan ir. Si una app te ocupa el 100% del tiempo, rompe el juego entero — el jugador no puede atender las otras seis.
6. **Ninguna app puede ser demasiado divertida.** Tienen que ser apenas entretenidas y completamente vacías. Si alguien se queda ahí por gusto, la obra deja de tratar sobre el vacío. Este es el error más fácil de cometer.

### El orden de armado (importante)

Este orden no es opcional — saltearlo cuesta horas:

1. **Definir `tamano_ventana` primero**
2. **Poner el `Size` del nodo raíz igual a ese valor** (con ancla Top Left, para diseñar al tamaño real)
3. **Recién ahí acomodar el contenido**, anclando cada hijo

### Anclar, nunca arrastrar

Cada hijo necesita su ancla: `Full Rect`, `Top Wide`, `Bottom Wide`, `Center`, etc. Las anclas son proporciones del padre, así que se adaptan solas cuando la app se estira dentro de la ventana.

Si posicionás arrastrando, la app va a verse bien en el editor y rota dentro de la ventana.

### Cómo probarla

Con F6 sobre su `.tscn`. La app arranca sola aunque nadie llame a `iniciar()`, gracias a este bloque al final del `_ready()`:

```gdscript
	await get_tree().process_frame
	if not esta_activa:
		iniciar()
```

Copialo en tu app.

### Cómo integrarla

En `escritorio.gd`, poner la ruta en el array `ESCENAS_APPS`, en la posición que corresponda. Usá clic derecho sobre el archivo → **Copy Path** para no equivocarte.

---

## 8. Las siete apps

El orden es el orden en que se van ofreciendo. Cada una tiene que ocupar una casilla distinta: si dos se parecen, una sobra.

| # | id | Nombre | Input | Ritmo | Carga mental | Estado |
|---|---|---|---|---|---|---|
| 0 | `scroll` | TikBrainRot | Arrastrar mouse | Goteo constante | Nula | **Lista** |
| 1 | `slots` | Family Savings™ | Click y volver | El jugador elige | Nula | Pendiente |
| 2 | `subway` | Subway Slop | Reiniciar cuando muere | Interrupción | Nula | Pendiente |
| 3 | `chat` | Chatly | Teclado / elegir respuesta | Impredecible | **Alta** | Pendiente |
| 4 | `musica` | Loopify | Elegir canción | Intervalo medio | Estratégica | Pendiente |
| 5 | `notificaciones` | PingMe | Cerrar | Random hostil | Nula, molesta | Pendiente |
| 6 | `serie` | StreamPlus | Click ocasional | Intervalo largo | Nula | Pendiente |

### Cómo funciona TikBrainRot (referencia)

Sirve de molde para pensar las demás:

- Cada video dura 5 segundos. La barra de progreso **es** el cooldown.
- Mientras el video corre, no se puede pasar al siguiente.
- Manteniendo apretado el botón izquierdo, el video corre a 2x y termina en 2.5 segundos. El 2x se desbloquea la primera vez que la dopamina baja de 60.
- Cuando el video termina, hay que arrastrar de abajo hacia arriba para pasar al siguiente. **Ese gesto es lo único que da dopamina.**
- La recompensa es **variable**: casi siempre da poco, un 15% de las veces da el triple. Es el mecanismo de las tragamonedas, y es lo que hace que scrollear no se pueda parar.

### Notas de diseño de las que faltan

- **Family Savings™:** tirás, hay animación de unos segundos, aparece un premio que **hay que ir a recoger** antes de que se pierda. Es la app que le enseña al jugador el ritmo de irse y volver.
- **Subway Slop:** gameplay de fondo que da dopamina pasiva; el personaje muere cada tanto y hay que reiniciarlo.
- **Chatly:** el corazón emocional. Llegan mensajes, se responde eligiendo entre respuestas sugeridas, y **todas las respuestas disponibles son vacías** ("jaja", "sisi", "dale"). Si la ignorás, el tono de los mensajes cambia y se vuelve personal. Es la única app donde ignorar tiene un costo humano.
- **Loopify:** no da dopamina propia, **multiplica la de las otras** mientras suena. La canción se termina y hay que elegir otra.
- **PingMe:** no se abre, **aparece sola** encima de las otras ventanas. Se cierra con un click. Su función real es robar tiempo y tapar lo que estabas mirando.
- **StreamPlus:** la más prescindible. Comparte mecánica con Subway Slop. Si hay que cortar una app, es esta.

### Coordinación entre apps

Cuando estén las siete, verificar entre todos:
- Que no se abran en la misma zona de la pantalla
- Que sus sonidos ocupen **rangos de frecuencia distintos** (una grave, una media, una aguda). Si son todas agudas, es barro sonoro, no saturación.
- Que las acciones premiadas sean realmente distintas entre sí

---

## 9. El sistema de audio

### Dos tipos de sonido

**Diegéticos (3D):** existen en el mundo y se oyen según dónde estés. El despertador, el zumbido de la compu, los pájaros. Van como `AudioStreamPlayer3D` **puestos en la escena**, en el objeto que los produce. No los maneja el AudioManager.

**No diegéticos (2D):** las capas de las apps, los clicks, la música. Sin posición en el mundo. Esos sí los maneja el `AudioManager`.

### Para agregar el sonido de una app

1. Poner el archivo en `assets/audio/apps/` con el nombre que ya está en el catálogo `SONIDOS` de `audio_manager.gd`
2. Seleccionarlo en el FileSystem → pestaña **Import** → tildar **Loop** → **Reimport**
3. Listo — `AppBase` ya llama a `iniciar_capa(id_app)` al abrirse

Mientras el archivo no exista, la consola avisa "falta el archivo" y el juego sigue funcionando en silencio.

### Formatos

`.ogg` para todo lo largo o en loop. `.wav` para efectos cortos.

### Fuentes libres

- **pixabay.com/sound-effects** — sin atribución
- **freesound.org** — ojo con las licencias, muchos son CC-BY (atribución obligatoria)

**Anotá todo en `docs/licencias.md` en el momento de descargar.** Buscar esto al final para armar los créditos es una tarde perdida y un riesgo académico real.

---

## 10. El monitor 3D y el SubViewport

Esto es lo más raro técnicamente del proyecto, y conviene entenderlo antes de tocarlo.

```
SubViewport (1920×1080)  ──renderiza──▶  textura  ──se pega──▶  QuadMesh "Pantalla"
     └── Escritorio                                                del monitor 3D
```

El escritorio 2D vive **adentro** de un `SubViewport`. Lo que ese viewport dibuja se convierte en textura y se aplica al quad del monitor. Por eso la interfaz es parte del objeto 3D y la cámara puede moverse.

El input va al revés: `habitacion.gd` lanza un rayo desde la cámara, ve dónde choca contra el `AreaPantalla`, convierte ese punto a coordenadas del viewport y le manda un evento sintético al `SubViewport`.

### Lo crítico

- **`Pantalla` (QuadMesh) y `AreaPantalla` (BoxShape3D) tienen que medir exactamente lo mismo en X e Y.** Si difieren, los clicks caen desplazados.
- El `SubViewport` necesita `Update Mode = Always`, o la pantalla queda congelada.
- El material de la pantalla lo crea `habitacion.gd` por código. No se lo asignes desde el editor.
- La pantalla tiene que mantener 16:9 o la interfaz sale deformada.

### Estructura de nodos

```
Monitor (StaticBody3D)          ← interactuable.gd, "Sentarse"
├── Marco (MeshInstance3D)
├── CollisionShape3D
├── Pantalla (MeshInstance3D)   ← QuadMesh
│   └── AreaPantalla (Area3D)
│       └── CollisionShape3D
└── PuntoSentado (Marker3D)     ← dónde va la cámara al sentarse
```

`PuntoSentado` cuelga del `Monitor` para que se mueva con él.

---

## 11. El flujo de la habitación

Cada objeto se **apaga** cuando cumplió su función (`interactuable.activo = false`). Por eso nunca hay dos carteles a la vez ni se puede hacer algo fuera de orden.

| Momento | Qué responde a la E |
|---|---|
| Negro inicial | nada |
| Despierto, sin caminar | solo el despertador |
| Caminando | solo el monitor |
| Sentado | nada (estás en la interfaz) |
| Colapso / negro | solo el cartel de levantarse |
| Levantado | solo la puerta |

### Los dos modos de mirar

- **De pie** (`mirar_sentado = false`): el mouse gira el **cuerpo**, así el WASD avanza hacia donde mirás.
- **Sentado** (`mirar_sentado = true`): el cuerpo queda quieto, el mouse gira solo la **cámara**, con tope de 75° a cada lado.

Al levantarse, la cámara vuelve a su transformación **local** (relativa al cuerpo), no a la global. Eso es lo que la deja alineada sin importar hacia dónde estuvieras mirando.

---

## 12. Convenciones

- Archivos y carpetas en **`snake_case`**: `barra_dopamina.gd`
- Nodos en la escena en **`PascalCase`**: `BarraDopamina`
- Todo en español, **sin acentos ni ñ** en nombres de archivos y variables (los acentos dan problemas al exportar)
- Señales en pasado: `app_desbloqueada`, `dopamina_cambio`
- Comentar el **por qué**, no el **qué**

---

## 13. Errores que ya cometimos (no los repitas)

**Scripts embebidos en la escena.** Al crear un script, dejá **Built-in Script destildado**. Un script embebido no se puede reutilizar y es una bomba de conflictos en Git. Si te pasó: clic derecho sobre el nodo → **Extract Script**.

**Diseñar la app a pantalla completa.** Ver sección 7. Diseñá al tamaño real de la ventana desde el principio.

**Posicionar arrastrando en vez de anclar.** Se ve bien en el editor y se rompe al integrar.

**Olvidar el Mouse Filter.** Los nodos decorativos (paneles de fondo, ColorRects) tienen que estar en **`Ignore`**, o se comen los clicks que necesita el `_gui_input` del nodo raíz. Los `Label` ya vienen en Ignore.

**Pelearse con un nodo dentro de un contenedor.** Si algo está dentro de un `HBoxContainer` o `VBoxContainer`, **no se lo posiciona**: se configura desde el contenedor o desde `Container Sizing` del hijo. El editor te bloquea moverlo a mano y es correcto que lo haga.

**Escribir rutas a mano.** Clic derecho sobre el archivo → **Copy Path**. Godot distingue mayúsculas y un typo te cuesta media hora.

**Un cambio de configuración que no toma efecto.** Reiniciá Godot. Pasa sobre todo con las opciones de "Embed Game".

**Propiedades grises que no se pueden editar.** El recurso es compartido o viene del tema. Clic derecho sobre el campo → **Make Unique**.

**Dejar `print()` de diagnóstico.** Sacalos apenas resolvieron lo que tenían que resolver. Ensucian la consola y pueden romper cosas cuando el contexto cambia.

---

## 14. Números de balanceo

Todos viven en `game_manager.gd`. **No los toques sin avisar** — el balanceo se hace en una fase dedicada, al final.

| Constante | Valor | Qué controla |
|---|---|---|
| `DRENAJE_INICIAL` | 2.0 | Qué tan cómoda es la primera app |
| `RAMPA` | 0.05 | **La velocidad de la escalada. El número principal.** |
| `DRENAJE_POR_APP` | 1.4 | Cuánto aprieta cada app nueva |
| `UMBRAL_OFERTA` | 0.35 | Qué tan desesperado hay que estar para el cartel |
| `LUNA_MIEL_DURACION` | 20.0 | Cuánto dura el alivio |
| `LUNA_MIEL_ALIVIO` | 0.45 | A qué % cae el drenaje al desbloquear |
| `RAMPA_FINAL` | 0.8 | Qué tan rápido es el colapso final |

**Regla de balanceo:** cambiar **un solo número por sesión de prueba**. Si cambiás tres, no sabés cuál mejoró qué.

Lo que importa no es cuánta dopamina da una app por click, sino **cuánta da por segundo de atención robada**. Si un giro de Family Savings da 20 pero consume 4 segundos, rinde 5 por segundo.

---

## 15. Para probar rápido

Atajo para llegar al colapso sin jugar la partida entera. Poner temporalmente en `_process()` de `habitacion.gd`:

```gdscript
	if Input.is_key_pressed(KEY_F1):
		GameManager.apps_desbloqueadas = GameManager.APPS.size()
		GameManager.etapa_final = true
		GameManager.dopamina = 5.0
```

**Sacalo cuando termines.**
