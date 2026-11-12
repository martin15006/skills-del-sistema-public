---
name: captura-ventana
description: Manejar y capturar (PNG) ventanas de programas de escritorio de Windows que no son una página web, como VS Code, Word, Excel, el Bloc de notas, el Explorador, una terminal o cualquier otro, incluidas sus ventanas secundarias y diálogos. Puede listar las ventanas abiertas, traer una al frente, escribir texto, enviar atajos de teclado, hacer clic, doble clic, clic derecho, arrastrar y usar la rueda del mouse, y guardar la captura de la ventana o de la pantalla completa. Úsala cuando haga falta una imagen de evidencia de una app de escritorio ("captura de VS Code", "pantallazo de la ejecución", "pega la imagen de Word"), cuando haya que operar un programa de escritorio paso a paso, o cuando no haya otra herramienta para ver el escritorio. Para páginas web usa navegador-visible (agent-browser).
---

# Captura y manejo de ventanas del escritorio

Script: `scripts/capturar_ventana.ps1` (PowerShell 5.1, sin instalar nada). Ejecutalo con la
herramienta PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
& "$HOME\.claude\skills\captura-ventana\scripts\capturar_ventana.ps1" <opciones>
```

Si solo tenés Bash, usá `-Command` (con `-File`, PowerShell no arma la lista de `-Pasos`) y comillas
simples por dentro. Con comillas dobles, Bash ejecuta las comillas invertidas:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"\$HOME\.claude\skills\captura-ventana\scripts\capturar_ventana.ps1\" -Hwnd 0x2A0F4 -Pasos @('click:120,340','wait:500')"
```

Para texto con símbolos raros desde Bash, escribí un `.ps1` aparte y ejecutalo con `-File`.

## Qué hace

1. **Elige la ventana**: por `-Titulo` (expresión regular sobre el título), `-Proceso` (expresión
   regular sobre el nombre del programa, por ejemplo `WINWORD`, `Code`, `notepad`) o `-Hwnd`
   (el identificador exacto que muestra `-Listar`). Si coinciden varias, usa la número `-Indice`
   (1 = la que está más al frente) y avisa.
2. **La trae al frente** (la restaura si estaba minimizada). Con `-Maximizar`, la maximiza.
3. **Ejecuta los `-Pasos`** en orden (ver tabla).
4. **Guarda la captura** con `-Salida`: solo esa ventana (sin la sombra) o, con
   `-PantallaCompleta`, todos los monitores. Siempre en píxeles reales, aunque Windows tenga escala
   de 125 % o 150 %.

`-Listar` muestra las ventanas visibles (incluidas secundarias y diálogos) sin tocar nada.
`-PantallaCompleta -Salida x.png` sin elegir ventana captura la pantalla sin cambiar el foco.

## Pasos

| Paso | Qué hace |
|---|---|
| `wait:<ms>` | Espera esos milisegundos |
| `keys:<teclas>` | Atajos en formato SendKeys: `^` Ctrl, `+` Shift, `%` Alt, `{ENTER}`, `{ESC}`, `{TAB}`, `{DOWN}`, `{F5}`… Solo para atajos: para escribir, `text:` |
| `text:<texto>` | Texto literal, letra por letra en Unicode: no depende del teclado (`^ ` ~ @ \`, tildes, emojis). Un salto de línea se envía como Enter |
| `click:x,y` | Clic izquierdo |
| `dclick:x,y` | Doble clic |
| `rclick:x,y` | Clic derecho |
| `move:x,y` | Solo mueve el puntero (menús o ayudas que aparecen al pasar el mouse) |
| `scroll:x,y,n` | Rueda del mouse sobre x,y: `n` > 0 sube, `n` < 0 baja (en "muescas") |
| `drag:x1,y1,x2,y2` | Arrastra con el botón izquierdo |

**Las coordenadas son píxeles dentro de la ventana elegida, medidos sobre una captura de esa misma
ventana** (esquina superior izquierda = 0,0). Si el visor de imágenes te muestra la captura
reducida, convertí a los píxeles reales del PNG.

## Flujo para hacer clic en algo

1. Capturá la ventana sin pasos: `-Titulo "…" -Salida "$env:TEMP\antes.png"`.
2. Mirá el PNG con Read y anotá el centro del botón o campo.
3. Ejecutá el clic y capturá de nuevo para comprobar:
   `-Titulo "…" -Salida "$env:TEMP\despues.png" -Pasos @("click:118,138", "wait:500")`.
4. Si el clic abre una ventana nueva (diálogo, segunda ventana), usá `-Listar` para ver su título o
   handle y apuntá a ella en la siguiente llamada (`-Hwnd 0x…`). Sus coordenadas se miden sobre
   una captura de esa ventana.

## Seguridad (automática)

- Antes de cada paso comprueba que al frente esté **la ventana elegida** o algo que cuelga de ella
  (sus menús y diálogos). Si el foco pasó a otro programa **o a otra ventana principal del mismo
  programa** (otro documento de Word, otra ventana de VS Code), se detiene.
- Antes de cada clic comprueba que el punto esté dentro de la ventana y que **no haya otra ventana
  encima** en ese lugar (una notificación, otro programa). Si la hay, se detiene sin hacer clic.
- Al terminar, el puntero vuelve a donde estaba.
- No avisa si algo tapa la ventana al **capturar**: la captura copia lo que se ve. Mirala siempre.

## Antes de usarla

- Avisá en una línea que vas a tomar el control del teclado y el mouse unos segundos y que el
  usuario no los toque mientras tanto.
- No actúes sobre documentos o datos del usuario más allá de lo que pidió. Para probar algo nuevo,
  usá una ventana de prueba propia, no sus programas abiertos.
- Guardá las capturas de trabajo en la carpeta temporal (`$env:TEMP` o el scratchpad). Solo las
  definitivas van a la carpeta del proyecto (por ejemplo `Evidencias\`).
- Mirá cada captura con Read **antes del paso siguiente**: confirmá que se ve lo que tenía que
  verse. No encadenes dos corridas sin mirar la del medio: si el foco quedó en otro lado (un
  buscador, otra pestaña), la segunda escribe ahí.
- Al abrir un programa, mirá `-Listar`: Word y el Bloc de notas pueden **reabrir documentos del
  usuario**. No les mandes nada; probá en un archivo propio abierto por su ruta y apuntá con `-Hwnd`.
- La captura muestra lo que hay en pantalla: si aparece información personal (documentos de
  identidad, correos, notificaciones), avisale al usuario antes de pegarla en un documento, y borrá
  las capturas de trabajo que no se usen.

## Confirmá antes de lo irreversible

Guardar o sobrescribir un archivo del usuario, cerrar algo con cambios sin guardar, borrar,
enviar, publicar o aceptar algo: primero decí en una línea qué va a pasar y preguntá con
AskUserQuestion (**Sí / No**). Si no tenés esa herramienta, preguntá en texto y frená. No hace falta
en tus propias ventanas de prueba ni en archivos que creaste vos en la carpeta temporal. Tampoco
aceptes por el usuario avisos de confianza o permisos (por ejemplo "Trust Folder" de VS Code).

## Ejemplos

```powershell
$cap = "$HOME\.claude\skills\captura-ventana\scripts\capturar_ventana.ps1"

# Ver qué ventanas hay
& $cap -Listar
& $cap -Listar -Proceso "WINWORD"

# Capturar VS Code maximizado
& $cap -Titulo "Visual Studio Code" -Salida "$env:TEMP\vscode.png" -Maximizar

# Capturar un diálogo concreto por su handle
& $cap -Hwnd 0x80870 -Salida "$env:TEMP\dialogo.png"

# Escribir en un campo y pulsar un botón
& $cap -Titulo "Mi programa" -Salida "$env:TEMP\despues.png" -Pasos @(
    "click:210,76", "text:hola", "click:118,138", "wait:500")

# Pantalla completa (todos los monitores) sin cambiar el foco
& $cap -PantallaCompleta -Salida "$env:TEMP\pantalla.png"
```

Abrir un archivo en la ventana de VS Code que ya está abierta, crear una terminal, ejecutarlo y
capturar (VS Code en español también encuentra los comandos por su nombre en inglés):

```powershell
code -r "C:\ruta\proyecto\programa.py"
& $cap -Titulo "programa\.py.*Visual Studio Code" -Salida "$env:TEMP\ejecucion.png" -Maximizar -Pasos @(
    "keys:^+p", "wait:800", "text:Terminal: Create New Terminal", "wait:900", "keys:{ENTER}", "wait:3000",
    "keys:^+p", "wait:800", "text:View: Toggle Maximized Panel", "wait:900", "keys:{ENTER}", "wait:1200",
    "text:python programa.py", "keys:{ENTER}", "wait:4000")
```

(Crear un terminal nuevo deja el foco en él; mirá abajo los trucos antes de cambiar el orden.)

## Trucos para VS Code (aprendidos en uso real)

- **La paleta pone primero lo "usado recientemente"**, aunque coincida peor. "Terminal: Focus
  Terminal" terminó eligiendo "Focus Terminal *Tabs View*" y el texto se escribió en la lista de
  pestañas. Antes de pulsar `{ENTER}` en un comando nuevo, hacé una captura de diagnóstico con la
  paleta abierta (sin Enter), recortá la zona de la paleta y miralo. Si el que querés no está
  primero, bajá con `{DOWN}` las veces necesarias, o hacé clic directamente en la opción.
- **"Terminal: Clear" deja el foco fuera de la terminal.** Después de limpiar, volvé a enfocarla
  ("Terminal: Enfocar terminal" en VS Code en español) o hacé clic dentro de la terminal.
- **Maximizá el panel antes de ejecutar**, no después: si se agranda con la salida ya impresa, la
  terminal queda casi vacía.
- **Para ver el principio de una salida larga**, no uses "Scroll to Top" (el historial puede tener
  líneas en blanco de limpiezas anteriores): bajá al final con `"keys:^{END}"` y subí línea por
  línea con `"keys:^%{PGUP}"` (Ctrl+Alt+RePág), o usá `scroll:x,y,n` sobre la terminal.
- Al terminar, dejá VS Code como estaba (por ejemplo, "View: Toggle Maximized Panel" otra vez).
- Si algo no llegó a donde debía, comprobá que no se haya escrito en un archivo (fecha de
  modificación de los archivos del proyecto) antes de repetir.
- **Modo Restringido** (carpeta que VS Code no conoce): crear una terminal pide "Trust Folder".
  No lo aceptes por el usuario. Si la ventana es tuya de prueba, cerrala y abrila con
  `code -n --disable-workspace-trust <carpeta>`, que vale solo para esa vez.

## Trucos para Word y Office en español

- Los atajos cambian de letra. Comprobado: **Ctrl+N es Negrita** (sin selección, la aplica a la
  palabra del cursor). Según los atajos de Office en español: **Ctrl+S es Subrayado** (no Guardar),
  Ctrl+G Guardar, Ctrl+U Nuevo y Ctrl+K Cursiva. Ante la duda, usá el menú con clics.
- El diálogo "¿Desea guardar los cambios?" de Word es una ventana aparte (`-Listar` la muestra como
  "Microsoft Word"). Capturala por su handle y leé de qué archivo habla antes de elegir.
- La autocorrección de Word (y la del Bloc de notas) cambia lo escrito: pone mayúsculas, tildes y
  enlaces. Si comparás texto, contá con eso.

## Prueba y documentación

- `pruebas/probar_skill.ps1` comprueba todas las funciones en una ventana de prueba propia (no toca
  otros programas) y muestra OK/FALLA. Corrélo después de cambiar el script:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.claude\skills\captura-ventana\pruebas\probar_skill.ps1"`.
  Dura ~20 s y usa el teclado y el mouse: avisale al usuario antes. Último resultado: 14/14 OK
  (30/10/2026, teclado Latinoamericano, dos monitores al 100 % y 125 %).
- `DOCUMENTACION.md` es la documentación completa para personas (parámetros, funcionamiento
  interno, límites, posibles mejoras). Actualizala si cambiás el script.
- Mantené los `.ps1` en ASCII (sin tildes): PowerShell 5.1 lee mal los UTF-8 sin BOM.

## Límites

- **Programas abiertos como administrador**: se pueden capturar, pero Windows no deja enviarles
  teclas ni clics desde un programa normal.
- **Pantalla negra** en juegos a pantalla completa y videos protegidos (Netflix, por ejemplo).
- **No funciona** con la pantalla bloqueada ni con las ventanas de permisos de administrador (UAC).
- **Apps de la Tienda de Windows:** la Calculadora funciona (teclas, texto y clics; también desde
  minimizada). Aparecen en `-Listar` bajo `ApplicationFrameHost`; apuntá por `-Titulo` o `-Hwnd`.
  Configuración y Fotos no se probaron.
- **Lo que se sale de la ventana sale cortado** (un menú contextual cerca del borde): usá
  `-PantallaCompleta` y recortá.
- Los diálogos de las apps modernas (Paint, Bloc de notas) son parte de la ventana y no aparecen en
  `-Listar`; los clásicos (Word) sí, como ventana aparte.
- Algunos programas ignoran las teclas simuladas (pocos juegos o apps con protección); en ese caso
  probá con clics.
- No lee la pantalla: siempre hay que mirar la captura para saber qué pasó.

## Si falla

| Mensaje | Qué hacer |
|---|---|
| `No se encontro ninguna ventana…` | Corré `-Listar` y usá el título o el handle que aparece |
| `Coinciden N ventanas…` (aviso) | Usá `-Listar` y elegí con `-Hwnd` para no depender del orden |
| `Windows no dejo traer la ventana al frente` | Pedile al usuario que haga clic en ella y repetí |
| `La ventana elegida dejo de estar al frente…` | El foco pasó a otro programa u otra ventana del mismo (otro documento). Mirá `-Listar` y repetí cuando el usuario no esté usando el equipo |
| `…hay otra ventana encima…` | Algo tapa ese punto (notificación, otra app). Esperá a que se vaya o movela y repetí |
| `…queda fuera de la ventana…` | Las coordenadas no son de esta ventana: volvé a capturarla y medí de nuevo |
| La captura sale negra o de otra ventana | La ventana estaba minimizada o tapada: repetí con `-Maximizar` |
