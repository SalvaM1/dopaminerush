@echo off
REM ============================================================
REM  Convierte los videos de los canales de Subway Slop
REM ============================================================
REM
REM  COMO SE USA:
REM    1. Renombrar cada video con el ID DE SU CANAL:
REM
REM         slime.mp4       cuchillo.mp4    mukbang.mp4
REM         prensa.mp4      asmr.mp4        jabon.mp4
REM         alfombra.mp4    subway.mp4
REM
REM       El nombre NO es decorativo: la app busca el archivo por el
REM       id del canal. Si se llama distinto, ese canal se queda con
REM       su color de fondo y no pasa nada mas.
REM
REM    2. Ponerlos en  videos_canales\
REM    3. Doble click a este archivo
REM    4. Los .ogv salen en  assets\video\subway\
REM
REM  ES INCREMENTAL: saltea los que ya estan convertidos. Podes ir
REM  agregando canales de a uno sin reconvertir los viejos.
REM
REM  OJO CON LA FORMA: el reproductor de esta app es APAISADO (440x238).
REM  Un video vertical entra igual, pero se le recorta casi todo a los
REM  costados. Buscalos en horizontal.
REM
REM  QUE HACE CADA OPCION:
REM    -t 35          recorta a 35 segundos. Un canal se quema en 30 s y
REM                   el video vuelve a empezar cada vez que volves a el,
REM                   asi que nunca se ve mas alla de ese minuto y medio.
REM    scale=-2:270   baja a 480x270. El reproductor mide 440 de ancho:
REM                   mas resolucion no se ve y cuesta CPU, porque Godot
REM                   decodifica video por software. Y aca puede haber
REM                   DOS videos a la vez (este y el de TikBrainRot).
REM    -q:v 7         calidad de imagen (0 = peor, 10 = mejor).
REM    -q:a 4         calidad de audio. El audio del canal sale del
REM                   video: si un canal tiene .ogv, su .ogg se ignora.
REM    -g:v 64        keyframes, como recomienda la documentacion.
REM    -sn -dn        descarta subtitulos y data streams.
REM    -nostdin       sin esto ffmpeg se come las lineas del .bat y
REM                   salta un "Parse error" con el nombre del script.
REM ============================================================

setlocal enabledelayedexpansion

set ORIGEN=%~1
if "%ORIGEN%"=="" set ORIGEN=%~dp0..\videos_canales

set DESTINO=%~dp0..\assets\video\subway

echo.
echo   origen : %ORIGEN%
echo   destino: %DESTINO%
echo.

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo   ERROR: no se encontro ffmpeg.
    echo   Instalalo con:  winget install Gyan.FFmpeg
    pause
    exit /b 1
)

if not exist "%ORIGEN%" (
    echo   ERROR: no existe la carpeta de origen: %ORIGEN%
    pause
    exit /b 1
)

if not exist "%DESTINO%" mkdir "%DESTINO%"

set /a NUEVOS=0
set /a SALTEADOS=0
set /a FALLOS=0

for %%F in ("%ORIGEN%\*.mp4" "%ORIGEN%\*.webm" "%ORIGEN%\*.mov" "%ORIGEN%\*.mkv") do (
    if exist "%DESTINO%\%%~nF.ogv" (
        set /a SALTEADOS+=1
        echo   [ya estaba]  %%~nxF
    ) else (
        echo   [convierte]  %%~nxF
        ffmpeg -nostdin -y -loglevel error -i "%%F" -t 35 -vf "scale=-2:270" -q:v 7 -q:a 4 -g:v 64 -sn -dn "%DESTINO%\%%~nF.ogv"
        if errorlevel 1 (
            set /a FALLOS+=1
            echo                FALLO
        ) else (
            set /a NUEVOS+=1
        )
    )
)

echo.
echo   convertidos ahora : %NUEVOS%
echo   ya estaban        : %SALTEADOS%
if %FALLOS% GTR 0 echo   fallaron          : %FALLOS%
echo.
echo   Canales que espera la app:
echo     slime  cuchillo  subway  mukbang  prensa  asmr  jabon  alfombra
echo.
pause
