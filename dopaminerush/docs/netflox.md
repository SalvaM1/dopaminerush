# Netflox — televisión de fondo

Agregado el 2026-10-12. Es una función del mundo 3D, fuera del catálogo de apps.

## Uso y balance inicial

- Se habilita al desbloquear la **quinta app**, y no en el acto: aparece **15 s
  después** (`demora_aviso`), con su propio cartel, igual que el vape. La espera
  le da tiempo al jugador a mirar la app que acaba de conseguir y evita que los
  dos carteles se pisen.
- El cartel es el mismo diseño que el del vape pero en **rojo Netflix**, y se
  construye en `netflox.gd`, no en `habitacion.gd`: el módulo es independiente y
  el código del vape no se toca.
- Solo se usa sentado en la PC, con la sesión activa.
- La primera **T** prende la televisión **y además gira la cámara**. Las dos
  cosas juntas a propósito: si solo prendiera, el jugador se perdería la
  animación de encendido, que pasa en una tele que todavía no está mirando.
- Al prenderse, la pantalla hace el **encendido de un tubo**: una línea
  horizontal que aguanta un instante y se abre en vertical, con un fogonazo. Se
  escala la `Pantalla` entera, así que detrás queda el negro del viewport. Va
  con demora (`duracion_giro - 0.4`) para terminar justo cuando la cámara llega.
- Mientras esté prendida, el drenaje se multiplica por **0.9**: baja un 10%.
- Las siguientes **T** giran la cámara hacia la TV y la devuelven automáticamente.
- La mirada incluye un zoom a **22° de FOV** para que la pantalla se lea desde la
  silla. Al volver o interrumpirse, se restaura el FOV original de la PC (80°).
- El giro dura **0,95 s** con curva `TRANS_CUBIC` / `EASE_IN_OUT`. La cámara gira
  **y** hace un zoom de 80° a 22° al mismo tiempo; comprimir las dos cosas en
  medio segundo era lo que se sentía brusco. La interpolación en sí ya estaba
  bien: un Tween sobre `transform` rota con slerp (comprobado: conserva la escala
  en 1,0000, mientras que un lerp crudo de la matriz la achataría a 0,707).
- La secuencia completa dura **4,2 segundos** y al terminar da **70 de dopamina**.
- Luego hay **30 segundos de cooldown**. Mantener T no repite la acción.
- El drenaje sigue corriendo durante la mirada; no se congela la barra. Por eso
  lo que importa es el **neto**: con un drenaje de ~8,5 se pierden unos 36
  durante la mirada, así que los 70 dejan un saldo de **+34** sobre 100.
  Sostenido, la TV aporta unos **2,05/s** (70 cada 34,2 s).
- No se pueden superponer TV, celular y vape.
- Un tropiezo cancela la mirada sin dar recompensa. El fin del día y el colapso
  apagan la TV y su sonido. Una nueva partida arranca sin el alivio.

- El indicador tiene el mismo formato que el del vape y el del celular: la tecla
  grande arriba y, en chico, lo que hace. El ícono es una **N** y no un emoji,
  porque Open Sans (la fuente por defecto del proyecto) no tiene glifos de emoji
  y los dibuja como cuadraditos.

Estos valores se editan en el Inspector del nodo `Netflox`, o en los exports de
`escenas/01_habitacion/netflox/netflox.gd`.
El zoom se ajusta con `fov_television`, en el grupo **Encuadre**.

## Archivos

- `escenas/01_habitacion/netflox/netflox.gd`: desbloqueo, mirada, cooldown,
  recompensa, reproducción y limpieza de estado.
- `escenas/01_habitacion/netflox/netflox.tscn`: viewport, portada provisional,
  reproductor de video y **AudioStreamPlayer3D** en la posición de la TV.
- `escenas/01_habitacion/netflox/indicador_netflox.tscn`: indicador de T y cooldown.
- `habitacion.tscn`: instancia el módulo y su indicador.
- `habitacion.gd`: configura el módulo y coordina el acceso a la cámara/input.
- `autoload/game_manager.gd`: multiplicador independiente `mult_drenaje_netflox`,
  aplicado en `drenaje_actual()` y restaurado por `reiniciar()`.
- `project.godot`: acción `mirar_television` en la tecla física T.

La televisión existente conserva su posición y geometría. El módulo crea una
superficie sobre su pantalla para mostrar el viewport.

## Verificación

`tools/tests/netflox_test.gd` prueba desbloqueo, tecla T, acumulación de alivios,
dirección de la cámara y del sonido, recompensa, cooldown, exclusión con otros
gestos, tropiezo, fin del día, reproducción con recursos y colapso. Ejecutar:

```text
Godot --headless --path . --script res://tools/tests/netflox_test.gd
```

## Agregar la película después

Por ahora hay una portada de Netflox y silencio: no se incluyó una película.

**Ojo con el rendimiento:** el viewport de la tele es de **640x360** y, mientras
no haya película, se dibuja **una sola vez** (`UPDATE_ONCE`) en lugar de 60 veces
por segundo. Antes era 1280x720 redibujado en cada cuadro para mostrar una imagen
quieta, y con cinco apps abiertas (Godot decodifica Ogg por CPU) eso alcanzaba
para trabar el juego entero. Al agregar la película vuelve a `UPDATE_ALWAYS`, que
es inevitable: conviene que el .ogv sea de 640x360 o menos.

Rutas preparadas:

- Imagen: `assets/video/netflox/pelicula.ogv` (**Ogg Theora**).
- Sonido: `assets/audio/netflox/pelicula.ogg` (también se admite WAV o MP3,
  cambiando `ruta_audio` en el Inspector).

Los dos archivos deben salir del mismo clip, empezar juntos y tener la misma
duración. La pista de audio va separada porque el sonido de VideoStreamPlayer
es 2D; aquí se silencia y se usa el reproductor 3D para que el sonido venga
desde la televisión a la derecha. El video y la pista se repiten al terminar.

Se puede cambiar `ruta_video` y `ruta_audio` sin tocar código. Si los archivos
no están, la portada y todas las mecánicas siguen funcionando. Agregar la
atribución de la película y el audio a `docs/licencias.md` cuando se elijan.
