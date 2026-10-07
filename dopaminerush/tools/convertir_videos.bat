@echo off
REM ============================================================
REM  Convierte videos de TikTok al formato que entiende Godot
REM ============================================================
REM
REM  Godot SOLO reproduce Ogg Theora (.ogv). Los .mp4 que bajaste
REM  no los puede abrir: hay que convertirlos una vez.
REM
REM  COMO SE USA:
REM    1. Poner los .mp4 nuevos en  videos_originales\
REM    2. Doble click a este archivo
REM    3. Los .ogv salen en  assets\video\scroll\
REM
REM  ES INCREMENTAL: los que ya estan convertidos los saltea. Podes
REM  agregar videos cuando quieras y correrlo de nuevo sin esperar a que
REM  reconvierta los viejos. Cada .ogv se llama igual que su .mp4, y es
REM  asi a proposito: es lo que le permite al script saber cual ya hizo.
REM
REM  PARA REHACER UNO: borra su .ogv y corre el script otra vez.
REM  PARA REHACER TODOS (si cambias la calidad, por ejemplo): borra todo
REM  el contenido de assets\video\scroll\ y corre el script.
REM
REM  QUE HACE CADA OPCION:
REM    scale=-2:854   baja a 480x854. La ventana mide 400 px de ancho:
REM                   mas resolucion no se ve y cuesta CPU, porque Godot
REM                   decodifica video por software.
REM    -q:v 7         calidad de imagen (0 = peor, 10 = mejor).
REM                   7 se ve bien a este tamano. Si lo ves feo, proba 8.
REM    -q:a 4         calidad de audio.
REM    -g:v 64        cada cuantos cuadros va un keyframe. Lo recomienda
REM                   la documentacion de Godot.
REM    -sn -dn        descarta subtitulos y data streams, que rompen
REM                   la conversion en algunos archivos de TikTok.
REM    -nostdin       IMPRESCINDIBLE. Sin esto ffmpeg lee la entrada
REM                   estandar y se come las lineas que le quedan al
REM                   .bat, que terminan interpretandose como comandos
REM                   suyos: sale un -Enter command- y un -Parse error-
REM                   con el nombre del propio script adentro.
REM ============================================================

setlocal enabledelayedexpansion

set ORIGEN=%~1
if "%ORIGEN%"=="" set ORIGEN=%~dp0..\videos_originales

set DESTINO=%~dp0..\assets\video\scroll

echo.
echo   origen : %ORIGEN%
echo   destino: %DESTINO%
echo.

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo   ERROR: no se encontro ffmpeg.
    echo   Instalalo con:  winget install Gyan.FFmpeg
    echo   Despues cerra y volve a abrir la consola.
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
        ffmpeg -nostdin -y -loglevel error -i "%%F" -vf "scale=-2:854" -q:v 7 -q:a 4 -g:v 64 -sn -dn "%DESTINO%\%%~nF.ogv"
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

if %NUEVOS% GTR 0 (
    echo   Abri Godot: deberia importarlos solo.
) else (
    if %SALTEADOS%==0 echo   No habia ningun video en la carpeta de origen.
)
echo.
pause
