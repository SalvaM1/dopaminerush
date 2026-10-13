# Netflox — televisión de fondo

Agregado el 2026-10-12. Es una función del mundo 3D, fuera del catálogo de apps.

## Uso y balance inicial

- Se habilita al desbloquear la **cuarta app** (Subway Slop), después del vape.
- Solo se usa sentado en la PC, con la sesión activa.
- La primera **T** enciende la televisión de la derecha y muestra Netflox.
- Mientras esté prendida, el drenaje se multiplica por **0.9**: baja un 10%.
- Las siguientes **T** giran la cámara hacia la TV y la devuelven automáticamente.
- La mirada incluye un zoom suave a **22° de FOV** para que la pantalla se lea
  desde la silla. Al volver o interrumpirse, se restaura el FOV original de la PC.
- La secuencia completa dura **3 segundos** y al terminar da **15 de dopamina**.
- Luego hay **25 segundos de cooldown**. Mantener T no repite la acción.
- El drenaje sigue corriendo durante la mirada; no se congela la barra.
- No se pueden superponer TV, celular y vape.
- Un tropiezo cancela la mirada sin dar recompensa. El fin del día y el colapso
  apagan la TV y su sonido. Una nueva partida arranca sin el alivio.

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
