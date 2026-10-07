# Dopamine Rush — Plan de Apps

Diseño y estado de las 7 apps y del vape.

> Arquitectura del proyecto: `guia_proyecto.md`
> Qué falta en general: `estado_proyecto.md`

---

## 1. El set

El orden es el de desbloqueo. Cada app introduce un **verbo nuevo**: si dos comparten verbo, una sobra.

| # | id | Nombre | Verbo | Tamaño | Posición | Estado |
|---|---|---|---|---|---|---|
| 0 | `scroll` | TikBrainRot | Arrastrar / mirar | 400×800 | (120, 140) | **Lista** |
| 1 | `slots` | Family Savings™ | Irse y volver | 720×460 | (1100, 100) | **Lista** |
| 2 | `racha` | Preguntados | Responder / no perder | 700×450 | (1120, 580) | **Lista** |
| 3 | `subway` | Subway Slop | Rotar fuentes quemadas | 440×384 | (600, 150) | **Lista** |
| 4 | `ofertas` | Mercado Libre | Apurarse / trámite | 460×470 | (565, 545) | **Lista** |
| 5 | `musica` | Loopify | Decidir | 560×320 | a definir | **Pendiente** |
| — | `linkedin` | LinkedOut | Defenderse | se abre sola | no se desbloquea | **Lista** |

Más **el vape**, que no es una app sino una acción del mundo 3D. **Listo.**

### Dos reglas que no se rompen

1. **Ninguna app puede pedir atención continua.** Todas piden en ráfagas y te dejan ir. Si una te ocupa el 100% del tiempo, rompe el juego entero — no podés atender las otras seis.
2. **Ninguna app puede ser demasiado divertida.** Apenas entretenidas y completamente vacías. Si alguien se queda por gusto, la obra deja de tratar sobre el vacío. Es el error más fácil de cometer.

---

## 2. Las apps terminadas

### 0 — TikBrainRot (`scroll`)

Scroll infinito vertical, estética de celular con navbar decorativa.

Cada video dura 8 segundos y la barra de progreso **es** el cooldown: no se puede pasar hasta que termine. **Manteniendo apretado** el video corre al doble de velocidad — se desbloquea la primera vez que la dopamina baja de 60.

Cuando termina, hay que **arrastrar de abajo hacia arriba** para pasar al siguiente. Ese gesto es lo único que da dopamina, con **recompensa variable**: casi siempre poco, un 15% de las veces el triple. Es el mecanismo de las tragamonedas, y es lo que hace que scrollear no se pueda parar.

**Pendiente:** videos reales (~30 clips cortos en loop).

---

### 1 — Family Savings™ (`slots`)

Tragamonedas horizontal con palanca vertical.

**La tirada da la dopamina, no el resultado.** Se arrastra la perilla hasta abajo del todo y la dopamina entra ahí mismo. En las tragamonedas reales el pico es la anticipación, no el premio.

**El giro es el cooldown:** 5 segundos con los rodillos frenando escalonados. La animación dura lo que dura la espera, así no se siente artificial. Ese tiempo muerto es lo que empuja a irse a otra app y volver — es la app que le enseña al jugador ese ritmo.

**Casi-premios:** un 35% de las veces los dos primeros rodillos salen iguales y el tercero no. Como frenan escalonados, queda un segundo entero mirando el tercero girar. Ese segundo es el efecto.

**El paywall:** los créditos alcanzan para 3-7 tiradas. Cuando se acaban hay que "comprarlos": tres pantallas y siete clicks, gratis, por nada, y **el botón se escapa a una posición al azar en cada click**. Es un patrón oscuro real.

**El dinero es un chiste:** solo baja. El jackpot devuelve menos de lo que costó la tirada.

---

### 3 — Subway Slop (`subway`)

Ventana chica tipo picture-in-picture, con estética de reproductor de video (barra con logo rojo, buscador falso, título abajo).

**8 canales** de contenido satisfactorio, cada uno con su color y su sonido:

| Canal | Color | Canal | Color |
|---|---|---|---|
| Slime | Rosa chicle | Prensa hidráulica | Gris industrial |
| Cuchillo caliente | Naranja | ASMR | Violeta |
| Subway Surfers | Azul saturado | Jabón cortado | Pastel |
| Mukbang | Rojo | Limpieza extrema | Verde agua |

**Cada canal tiene su propia FRESCURA.** Mientras lo mirás baja (se quema en ~30 s) y la dopamina es proporcional a ella. **Los canales que no estás mirando se recuperan solos** (~91 s).

Eso convierte la app en un problema de rotación: no es "apretá de nuevo", es *"cuál de los ocho estará recuperado ahora"*.

**El gesto:** mantener apretado el botón `SIGUIENTE ⏭` de la barra inferior, que se llena de rojo. El canal nuevo sale **al azar**, así que puede tocar uno ya quemado.

**El costo del cambio no es el gesto: es el buffering.** Tres segundos de rueda girando (la de YouTube, dibujada por código con `draw_arc`) en los que no entra nada. Spamear es la peor estrategia: cuanto más cambiás, menos ves. Igual que hacer zapping de verdad.

**Cómo se entiende el aburrimiento sin una palabra:** el video se apaga. A medida que el canal se quema, su color se desatura y oscurece — el rosa chicle del slime termina en gris sucio. Y el botón late cuando la frescura baja del 35%.

**El medidor** es una tira separada, pegada debajo del reproductor, que dice `ENTRETENIMIENTO`. Solo muestra el canal actual: ver el estado de los ocho mataría la apuesta.

**Es la tolerancia hecha mecánica:** quemás una fuente, deja de darte algo, tenés que dejarla descansar.

**Contraste deliberado con TikBrainRot:** ahí mantener apretado **acelera** el video; acá **lo descarta**. El mismo gesto con sentido opuesto, para que las dos apps abiertas se peleen en los dedos.

**Pendiente:** videos reales y los 8 sonidos en `assets/audio/apps/canales/<id>.ogg`.

---

### 2 — Preguntados (`racha`)

Parodia de app de idiomas. **Es la única app que te hace PERDER algo.** Las demás son tentación: perseguís una recompensa. Esta es obligación: evitás una pérdida.

Cada ~5 segundos aparece una pregunta de opción múltiple en grilla 2×2, con **15 segundos** para responder. Acierto: dopamina × multiplicador y la racha sube. Error o tiempo vencido: **la racha se rompe** y vuelve a 1.0x.

El multiplicador sube 0.1 por acierto y **topa en 2.0**. Solo afecta a esta app, así que no desequilibra nada.

**Fallar no resta dopamina.** El castigo es perder la racha; restar encima se sentía injusto.

**Las preguntas están en `preguntas.json`**, editable a mano sin tocar código. Cualquiera del grupo puede sumar preguntas.

**Tiene el juice completo**, y sirve de referencia para las demás:
- El sonido de acierto **sube un semitono por cada acierto**: una serie se vuelve una melodía ascendente. Es el truco de mayor impacto de todo el pulido.
- Pausa de anticipación de 0.15 s antes del reveal
- Botones con "labio" inferior que se hunde al presionar
- Las otras opciones se apagan al elegir
- La barra se llena con rebote y se vacía **de golpe** al romperse
- Fuego y latido al llegar a 2.0x, confeti cada 5 aciertos
- Temporizador con tres etapas de urgencia y tic-tac que acelera
- Elogios que escalan desproporcionadamente con la racha

> **En Preguntados el exceso de juice es el argumento, no un problema estético.** Duolingo real es agresivamente satisfactorio a propósito, y esa maquinaria es justo lo que el juego retrata.

---

### LinkedOut (`linkedin`) — fuera del catálogo

**Qué aporta:** hostilidad. Es lo que sube la tensión en las fases finales sin tocar ningún otro número.

**No se abre desde el ícono: la abre el escritorio, sola**, centrada y ocupando el 83% de la pantalla, por encima de todas las ventanas.

**La escalada:** cada 30 s al principio, y cada aparición acorta el intervalo un 12% con piso en 15 s. Mientras está abierta el reloj se congela: ignorarla no acumula apariciones.

**Dos concesiones al jugador**, porque perder por algo que no depende de vos frustra en vez de tensar:
- Mientras está abierta, **el drenaje baja un 25% más lento** (`GameManager.mult_drenaje_externo`)
- **No aparece si la dopamina está bajo el 25%**, y el reloj ni corre en ese caso: espera a que te recuperes

**Las páginas son capturas reales**, en `assets/ui/linkedout/`: `login.png`, `empleo.png`, `feed.png`, `mensajes.png`. Usar capturas en vez de recrear la interfaz es lo que hace que se reconozca en un segundo.

**La página agresiva** está armada con nodos imitando el estilo: barra superior con logo azul y buscador, y una tarjeta blanca que dice *"LinkedOut · Publicación patrocinada · Para vos"* con el mensaje y un botón azul.

Que parezca una publicación patrocinada **real** es lo importante: un fondo rojo con letras gigantes se leería como parodia obvia. El efecto buscado es *"wow, qué loco que LinkedIn te diga esto"*.

Mensajes de tono corporativo y contenido brutal — es la combinación lo que incomoda, no el insulto:

- *"2.847 personas se postularon a empleos hoy. Vos no."*
- *"Hace 340 días que no publicás nada. Tu presencia profesional está desapareciendo."*
- *"Tu red creció un 0% este mes. El promedio de tu sector fue 12%."*
- *"Notamos que estás disponible. ¿Estás buscando trabajo o solo perdiendo el tiempo?"*
- *"Personas de tu edad ya lideran equipos. ¿Querés ver sus perfiles?"*

**No aparece hasta la cuarta vez**, y ahí con 25% de probabilidad creciente. En la etapa final sale siempre: es cuando deja de fingir.

Se cierra con la X de la ventana. Cerrarla da una miga de dopamina — lo importante no es lo que da, es el tiempo que te robó.

---

## 3. Las apps que faltan

### 4 — Mercado Libre (`ofertas`)

**Qué aporta:** ventana de tiempo y trámite. Es la única app que te **apura**, y la única que te saca de la pantalla para poder seguir usándola.

**La oferta.** Aparece un producto con un contador de ~8 segundos. Si se vence, se pierde.

**Al clickear "comprar", el contador para.** El apuro era para decidir, no para completar el trámite: una vez que te enganchó el impulso, ya sos un cliente en proceso de pago. Y si el código también tuviera reloj, una sola distracción haría perder todo el esfuerzo y se sentiría injusto en vez de tenso.

**EL CÓDIGO AL CELULAR.** Llega un código de **3 dígitos al teléfono**, que está sobre el escritorio en el mundo 3D:

- El jugador aprieta una tecla, la cámara gira hacia él, lee el código, vuelve y lo tipea
- Mismo sistema que el vape: un `Marker3D` para la posición de cámara y un tween
- El teléfono **se enciende y suena** cuando llega el código, para que no haya que adivinar cuándo mirar
- **El drenaje NO se congela** durante el trámite, a diferencia del vape: estás perdiendo tiempo en una gestión administrativa mientras todo lo demás se cae. Esa frustración es el punto

**Por qué funciona:** el teléfono es *el otro objeto que roba tu atención*. Que tengas que soltar el mouse y mirar el celular para poder seguir comprando en la compu es exactamente lo que el juego retrata.

Y crea la decisión real de la app: **¿me meto en el trámite ahora, o dejo pasar esta oferta porque tengo tres cosas explotando?**

**Detalles:** contador de "$ gastado hoy" que solo sube (no hace nada: es culpa pura). Productos absurdos, descuentos ridículos, *"quedan 2 unidades"*, *"17 personas viendo esto ahora"*.

**Números de arranque:** 20 por compra, ~8 s de contador, ~10 s entre ofertas.

---

### 5 — Loopify (`musica`)

**Qué aporta:** decisión estratégica.

**No da dopamina propia: multiplica la de las otras** (×1.3) mientras suena. La canción se termina cada ~40 segundos y hay que elegir otra de una lista.

Genera una decisión real cuando estás ahogado: ¿gastás dos segundos en poner música, o los usás en producir?

⚠ **Es la única app que necesita tocar `app_base.gd`**: el multiplicador se aplica en `recompensar()`. Coordinar antes de hacerlo.

---

## 4. El vape (no es una app) — LISTO

Es lo único que rompe el plano de la pantalla: te obliga a soltar el mouse, mirar al costado y hacer algo con el cuerpo. En una obra sobre estar pegado a un monitor, eso tiene un peso que ninguna ventana puede tener.

- **Se desbloquea con la tercera app.** Antes el juego todavía es manejable y no hace falta.
- Un cartel publicitario lo anuncia 3 segundos después: *"¿Ansioso? Date un respiro."*, con botón que late. Misma voz que los carteles de oferta: el juego ofreciéndote otra cosa que no te hace bien.
- Cooldown de 20 s. Al activarlo con **V**, la cámara gira, el vape sube a la boca, sale humo, la cámara vuelve.
- **El drenaje se congela durante toda la animación.** Sin eso, los ~4 segundos de no poder tocar nada cuestan más de lo que el buff ahorra, y no conviene usarlo nunca.
- El buff es de solo **−10% por 15 s**: el valor del vape es el descanso, no el bonus.

---

## 5. Cambios técnicos pendientes

**Loopify** necesita el multiplicador global en `recompensar()` de `app_base.gd`.

Todo lo demás ya está resuelto: LinkedOut usa un temporizador en `escritorio.gd` y `GameManager.mult_drenaje_externo`, sin tocar `app_base.gd`.

---

## 6. Balanceo

**No ajustar nada hasta tener las 7 apps.**

Con la tecla **D** en el juego se abre un panel que muestra drenaje, producción y balance en vivo. El objetivo es que **balance** ronde **1.05 – 1.40**.

Lo que importa no es cuánta dopamina da una app por click, sino **cuánta da por segundo de atención robada**.

| App | Rinde |
|---|---|
| TikBrainRot | 16 por deslizar cada 8 s (o 4 s con 2x), 32 el 15% de las veces |
| Family Savings™ | 20-35 por tirada cada 5 s |
| Subway Slop | 7/seg con el canal fresco, menos a medida que se quema |
| Preguntados | 55 por acierto × multiplicador, cada ~5 s |
| Mercado Libre | 20 por compra |
| Loopify | 0 propia, ×1.3 a las demás |
| LinkedOut | 6 por cerrarla |
| Vape | −10% de drenaje por 15 s |
