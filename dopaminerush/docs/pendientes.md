# Pendientes

Lo que falta antes de la entrega, en orden. Tachar (`~~así~~`) lo que se va
haciendo. El detalle técnico de lo ya hecho está en `estado_proyecto.md`.

## A. Imprescindible antes de entregar

1. **Commit de todo lo pendiente** (sin `project.godot`).
2. **Menú de pausa con ESC.** Hoy no hay forma de salir desde adentro (el mouse
   queda capturado). Continuar, volumen (la misma pestaña Sonido del menú),
   sensibilidad del mouse, volver al menú, salir.
3. **Exportar el .exe y probarlo en una compu sin Godot.** No hay
   `export_presets.cfg` todavía. Revisar que carguen los videos, la pantalla
   completa, la escena principal (`menu.tscn`) y el audio (los 9 buses).
4. **Cartel de advertencia la primera vez que la dopamina llega a 0.** Hoy sale
   solo el rectángulo del "tropiezo" 3 s, sin texto ni sonido
   (`escritorio.gd`, `_al_fallar`, con un `TODO: sonido feo aca`). El jugador no
   se entera de que la próxima vez pierde el día. Que avise, con el estilo de los
   carteles del juego, y con un sonido.
5. **Mejorar visualmente la app de TikTok (TikBrainRot).** Es la primera app y
   la que más se usa: que se vea al nivel del resto (Preguntados, Loopify).
6. **Tutorial del 2x de TikTok.** Cuando se desbloquea la velocidad x2, que el
   juego lo explique (un pensamiento como los de primera vez, o un cartel), para
   que el jugador sepa que existe y cómo se usa.
7. **Íconos del dock dibujados.** La barra de tareas del escritorio de la compu
   (abajo, un botón por app) usa emojis como íconos (▶ 🎰 🦉 📺 🛒 🎵) que
   la fuente no tiene: se ven como cuadraditos vacíos. Dibujarlos con el estilo
   de cada app. Revisar también los de la bandeja (red, volumen).
8. **Productos de Mercado Libre con imagen.** Hoy cada producto se muestra con
   un emoji (y algunos no existen en la fuente): no se entiende que son productos
   absurdos e inútiles. Cada uno con su imagen y un texto que lo venda en serio
   (como un aviso real), para que el chiste se lea. Hay 16 en
   `escenas/03_apps/app_05_ofertas/productos.json` (tostadora que imprime tu cara,
   ventilador para el mate, almohada con forma de pierna...): revisarlos y sumar
   los más ridículos.
9. **Tutorial de Mercado Libre.** La primera vez que se abre, explicar cómo se
   juega (las ofertas, el código que llega al celular, la tecla C), con el mismo
   estilo que los demás tutoriales.
10. **Limpieza:** teclas de debug O / U / P / D (apagadas, pero disponibles para
   probar), `forzar_2x_desbloqueado` en false, escenas de prueba
   (`prueba_nucleo.tscn`, `app_placeholder.tscn`), `print()` de diagnóstico.
11. **Atribuciones en los créditos** (con OK del grupo: los créditos no se tocan
   sin preguntar): todo lo de `licencias.md` (temas de Loopify, videos, sonidos,
   fuentes). Confirmar los links de Pixabay y la fuente de la notificación.
12. **Una partida entera de punta a punta**, anotando lo que se sienta raro:
   balance del drenaje, ritmo del capítulo nuevo (noche → martes → parque).

## B. Assets que faltan (los consigue el grupo, se integran después)

- **Casino:** `palanca_sube`, `girando`, `rodillo_para`, `casi`, `jackpot`,
  `moneda`, `luz` (`assets/audio/apps/slots/`). Hoy solo suena la palanca.
- **Celular:** notificación / vibración (`assets/audio/ambiente/celular.ogg`).
- **Mercado Libre:** sonido de compra (el nodo `Comprar` está vacío).
- **TikToks:** llegar a ~30 (hoy 20).
- **Pasos de la pieza:** 3 o 4 variantes más (hoy hay una sola).

## C. Para ampliar, si sobra tiempo

1. **Resumen del día antes de los créditos.** Con el estilo de los carteles de
   los días: "Hoy deslizaste 214 videos. Abriste TikTok 31 veces. Pasaste
   9 horas frente a la pantalla. Saliste 0 veces." La que más pega.
2. **Cartel de día al llegar al parque** ("Martes / 16:30"): une el capítulo
   nuevo con el final y explica el salto de la mañana al atardecer.
3. **Revisión de rendimiento** en la compu donde se va a mostrar (varios videos
   a la vez en una Iris Xe).
4. **Versión en inglés** (para una muestra; es lo más grande de la lista).

### Para probar (no convence del todo: hacerlo fácil de sacar)

- **Abstinencia visible.** A medida que baja la dopamina, la pieza y la
  pantalla se van desaturando; en los últimos 30 s se suma una viñeta que late
  con un sonido de latido. Refuerza el agobio del final sin agregar mecánicas.
  Si no gusta, se apaga con una sola constante.
