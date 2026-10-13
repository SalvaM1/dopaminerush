# Perrito del parque

Agregado el 2026-10-12. Aparece a la derecha del jugador al entrar al parque,
tras salir por la puerta de la habitación. Acompaña el paseo hasta el banco.
Espera visible junto al primer tramo y empieza a seguirte cuando caminás.

- Sigue las huellas del jugador con una pequeña separación lateral y evita
  obstáculos. Tiene gravedad y colisión con el terreno; no bloquea al jugador.
- Mantiene **2 metros de margen**, reduce la velocidad al acercarse y espera
  si el jugador se aproxima para acariciarlo. Ajustable con `distancia_seguimiento`.
- Mirándolo de cerca aparece **[E] Acariciar** mediante el sistema `Interactuable`
  existente. La caricia dura 2 segundos: mano visible, movimiento de cabeza y
  cola. La cámara encuadra al perro y luego restaura la mirada y los controles.
- Acariciarlo es opcional y repetible, sin premios ni cambios en la recuperación.
- Al sentarse, se acerca al costado del banco. La caricia se deshabilita durante
  la secuencia de descanso, respiración y créditos.

## Archivos

- `escenas/04_parque/perrito/perrito.tscn`: escena independiente, modelo 3D de
  formas simples, materiales, mano y colisiones; no requiere assets externos.
- `escenas/04_parque/perrito/perrito.gd`: seguimiento, animaciones, caricia y
  restauración de cámara/controles.
- `escenas/04_parque/parque.tscn`: instancia `Perrito`.
- `escenas/04_parque/parque.gd`: configura el compañero y avisa al sentarse.

La velocidad, separación y duración de la caricia se ajustan desde el Inspector
del nodo `Perrito`. El modelo vive bajo `Modelo`, con cabeza, patas y cola
separadas para poder reemplazarlo o retocarlo sin cambiar el resto del parque.

## Verificación

`tools/tests/perrito_test.gd` verifica aparición, suelo, interacción con E,
caricia y controles, recorrido de todas las curvas del camino, descanso junto
al banco y transición a créditos. Ejecutar:

```text
Godot --headless --path . --script res://tools/tests/perrito_test.gd
```
