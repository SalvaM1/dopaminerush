# Iluminación de la habitación según la hora

Agregado el 2026-10-12. La luz natural sigue exactamente la hora de la barra de
tareas de la computadora, mediante la señal `hora_cambio` del escritorio.

- El día comienza a las **08:00**, con luz clara por la ventana y cielo azul.
- A mediodía aumenta la iluminación. Por la tarde el tono se vuelve más cálido.
- A las **18:00** predomina el atardecer; desde las **20:00** cae la luz natural
  y aparece el cielo nocturno. El sol se apaga, pero queda un tenue fondo azul.
- Los cambios de color, intensidad y dirección se interpolan suavemente.
- Se conserva la velocidad del reloj: **12 minutos por segundo real**. Avanza
  desde que se carga la habitación, también antes de sentarse. Llega a 23:59 y
  permanece allí, evitando que la pieza vuelva a la mañana durante la partida.
- Al comenzar un día nuevo, el reloj y la iluminación vuelven juntos a la mañana.
- El interruptor sigue manejando el plafón; el ciclo controla la luz natural.
  El plafón usa ahora un blanco neutro y conserva su energía y control manual.

## Archivos

- `escenas/01_habitacion/iluminacion/ciclo_dia.gd`: etapas e interpolación;
  controla cielo, sol exterior, vidrio, luz de ventana y rebote interior.
- `escenas/01_habitacion/iluminacion/ciclo_dia.tscn`: luces de ventana y rebote.
- `habitacion.tscn`: instancia `CicloDia`.
- `habitacion.gd`: configura el módulo al cargar la pieza.
- `escenas/02_computadora/escritorio.gd`: publica la hora del reloj y la limita
  al final del día; no hay un segundo reloj independiente para las luces.

Las etapas se ajustan en `ETAPAS`. La intensidad de ventana y rebote se puede
modificar en el Inspector de `CicloDia`. Los recursos del cielo, entorno y vidrio
se duplican para esta habitación. El parque conserva su iluminación propia.

## Verificación

`tools/tests/ciclo_dia_test.gd` comprueba reloj y luz sincronizados, mañana,
mediodía, atardecer, noche, continuidad, límite de hora, interruptor y reinicio.

```text
Godot --headless --path . --script res://tools/tests/ciclo_dia_test.gd
```
