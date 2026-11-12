# captura-ventana — Documentación completa

**Versión:** 3 · **Fecha:** 30 de octubre de 2026
**Creada por:** Juan Sebastián Martín Moncada, con Claude Code
**Sistemas probados:** Windows 11 Home (1920×1080 al 125 %) y Windows 11 Pro con dos monitores 1920×1080 (al 100 % y al 125 %) y teclado Latinoamericano

---

## 1. Qué es

`captura-ventana` es una *skill* (habilidad) para Claude Code que le permite a Claude **manejar programas de
escritorio de Windows y tomarles capturas de pantalla**. Sirve para cualquier programa con ventana: VS Code,
Word, Excel, el Bloc de notas, el Explorador de archivos, una terminal, etc.

Nació para un caso concreto, en el equipo de un compañero: tomar las capturas de evidencia de VS Code para el
informe de la Fase 4 (Fundamentos de Programación, UNAD), porque Claude no tenía otra forma de ver ni operar
programas de escritorio.

Con ella Claude puede:

- **Ver qué ventanas hay abiertas**, incluidas las secundarias y los cuadros de diálogo.
- **Elegir una ventana** por su título, por el programa al que pertenece o por su identificador exacto.
- **Traerla al frente**, restaurarla si está minimizada y maximizarla.
- **Escribir texto y usar atajos de teclado** (Ctrl+S, Alt+F4, Enter, flechas, F5…).
- **Usar el mouse**: clic, doble clic, clic derecho, arrastrar, rueda y mover el puntero.
- **Guardar capturas PNG** de una ventana (sin la sombra del borde) o de la pantalla completa, con todos los monitores.

No necesita instalar nada: es un script de PowerShell que usa funciones que ya trae Windows.

---

## 2. Contenido de la carpeta

```
captura-ventana\
├── SKILL.md                    Instrucciones para Claude (cuándo y cómo usarla)
├── DOCUMENTACION.md            Este documento (para personas)
├── scripts\
│   └── capturar_ventana.ps1    El programa principal
└── pruebas\
    ├── probar_skill.ps1        Prueba automática de todas las funciones
    └── ventana_prueba.ps1      Ventana de prueba que usa probar_skill.ps1
```

---

## 3. Instalación

### Para que Claude Code la use

Copia la carpeta `captura-ventana` completa dentro de:

```
C:\Users\<tu usuario>\.claude\skills\
```

Debe quedar `C:\Users\<tu usuario>\.claude\skills\captura-ventana\SKILL.md`. Claude Code la detecta sola en la
siguiente sesión. Por ejemplo: `C:\Users\Usuario\.claude\skills\captura-ventana\`. También está en el repositorio
`skills-del-sistema`, que la instala en otra PC junto con las demás skills.

### Para usarla tú mismo

No hace falta instalarla: puedes ejecutar `scripts\capturar_ventana.ps1` desde PowerShell desde cualquier
carpeta (ver la sección 5).

---

## 4. Cómo se usa con Claude

Basta con pedirlo en palabras. Ejemplos:

- «Toma una captura de VS Code con la terminal mostrando la ejecución del programa.»
- «Abre la terminal de VS Code, ejecuta `python programa.py` y captúralo.»
- «Haz una captura del Word que tengo abierto.»
- «¿Qué ventanas tengo abiertas?»
- «En el Bloc de notas, escribe esta lista y guárdala.»

Claude avisa antes de tomar el control del teclado y el mouse. Mientras trabaja, no debes usarlos (son unos
segundos). Después de cada acción, Claude mira la captura para comprobar que salió bien.

---

## 5. Uso manual desde PowerShell

```powershell
$cap = "$HOME\.claude\skills\captura-ventana\scripts\capturar_ventana.ps1"
Set-ExecutionPolicy -Scope Process Bypass -Force    # solo para esta ventana de PowerShell

# Ver qué ventanas hay
& $cap -Listar

# Capturar VS Code maximizado
& $cap -Titulo "Visual Studio Code" -Salida "$env:USERPROFILE\Desktop\vscode.png" -Maximizar

# Capturar la pantalla completa sin cambiar de ventana
& $cap -PantallaCompleta -Salida "$env:USERPROFILE\Desktop\pantalla.png"

# Escribir en el Bloc de notas (debe estar abierto)
& $cap -Titulo "Bloc de notas" -Pasos @("text:Hola desde la skill", "keys:{ENTER}")
```

Desde Git Bash hay que usar `-Command`. Con `-File`, PowerShell no arma la lista de `-Pasos` y la toma como un
solo texto. Por dentro van comillas simples, porque Bash ejecuta las comillas invertidas que estén dentro de
comillas dobles:

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& \"\$HOME\.claude\skills\captura-ventana\scripts\capturar_ventana.ps1\" -Listar"
```

---

## 6. Parámetros

| Parámetro | Qué hace |
|---|---|
| `-Listar` | Muestra las ventanas visibles: número, handle, programa, tamaño y título. No toca nada. Se puede filtrar con `-Titulo` o `-Proceso`. |
| `-Titulo "<texto>"` | Elige la ventana cuyo título contiene ese texto (acepta expresiones regulares: `"Prueba.*Principal"`). |
| `-Proceso "<nombre>"` | Elige por el nombre del programa: `WINWORD`, `EXCEL`, `Code`, `notepad`, `explorer`, `chrome`… |
| `-Indice <n>` | Si coinciden varias ventanas, usa la número *n* (1 = la que está más al frente). |
| `-Hwnd 0x…` | Elige una ventana exacta por su identificador (*handle*), copiado de `-Listar`. Es la forma más segura cuando hay varias parecidas. |
| `-Maximizar` | Maximiza la ventana antes de trabajar. |
| `-Pasos @(...)` | Lista de acciones en orden (ver sección 7). |
| `-Salida "<ruta.png>"` | Guarda la captura en esa ruta. Sin este parámetro no se captura nada. |
| `-PantallaCompleta` | Captura todos los monitores en vez de solo la ventana. Sin ventana elegida, no cambia el foco. |
| `-EsperaFinalMs <ms>` | Espera antes de la captura final (por defecto 600 ms) para que la ventana termine de dibujarse. |

---

## 7. Pasos (acciones)

| Paso | Qué hace | Ejemplo |
|---|---|---|
| `wait:<ms>` | Espera | `"wait:1500"` |
| `keys:<teclas>` | Atajos de teclado en formato SendKeys (para escribir texto, usar `text:`) | `"keys:^s"` (Ctrl+S), `"keys:%{F4}"` (Alt+F4) |
| `text:<texto>` | Escribe texto literal, letra por letra en Unicode, sin depender de la distribución del teclado. Un salto de línea se envía como Enter | ``"text:x^2 `ok` a@b.co C:\d"`` |
| `click:x,y` | Clic izquierdo | `"click:118,138"` |
| `dclick:x,y` | Doble clic | `"dclick:200,260"` |
| `rclick:x,y` | Clic derecho (menú contextual) | `"rclick:200,260"` |
| `move:x,y` | Solo mueve el puntero (menús o ayudas que aparecen al pasar el mouse) | `"move:300,40"` |
| `scroll:x,y,n` | Rueda del mouse sobre x,y; `n` positivo sube y negativo baja | `"scroll:620,200,-3"` |
| `drag:x1,y1,x2,y2` | Arrastra con el botón izquierdo | `"drag:60,390,350,400"` |

**Códigos de teclas más usados:** `^` Ctrl · `+` Shift · `%` Alt · `{ENTER}` · `{ESC}` · `{TAB}` ·
`{BACKSPACE}` · `{DELETE}` · `{UP}` `{DOWN}` `{LEFT}` `{RIGHT}` · `{HOME}` `{END}` · `{PGUP}` `{PGDN}` ·
`{F1}`…`{F12}`. Para repetir: `{DOWN 3}`.

**Ojo con Office en español:** los atajos cambian de letra. Ctrl+N es Negrita y Ctrl+S es Subrayado; Guardar es
Ctrl+G y Nuevo es Ctrl+U.

---

## 8. Coordenadas: cómo se miden

Las coordenadas `x,y` de los clics son **píxeles dentro de la ventana elegida**, medidos sobre una
captura de esa misma ventana. La esquina superior izquierda de la ventana es `0,0`.

El flujo de trabajo es siempre:

1. Capturar la ventana.
2. Mirar la captura y ubicar el centro del botón o campo.
3. Hacer el clic con esas coordenadas y capturar de nuevo para comprobar.

Las coordenadas están en píxeles reales de la pantalla, aunque Windows tenga escala de 125 % o 150 %, así que
coinciden siempre con los píxeles del PNG. Si un clic abre otra ventana (un diálogo), esa ventana tiene sus
propias coordenadas: se captura aparte y se apunta a ella con `-Hwnd`.

---

## 9. Seguridad

Funciones automáticas para no hacer nada fuera de lugar:

- **Solo actúa sobre la ventana elegida.** Antes de cada tecla o clic comprueba que al frente esté esa ventana
  o algo que depende de ella (sus menús y diálogos). Si el foco pasó a otro programa **o a otra ventana
  principal del mismo programa**, se detiene. Esto último importa en Word o VS Code, donde varios documentos
  comparten un solo proceso. Hasta la versión 2 solo se comparaba el programa, y en una prueba el texto
  terminó en otro documento de Word.
- **No hace clic si hay algo encima.** Antes de cada clic revisa qué ventana hay realmente en ese punto. Si es
  de otro programa (una notificación, otra app), se detiene sin hacer clic.
- **Rechaza coordenadas fuera de la ventana.**
- **Devuelve el puntero a su lugar** al terminar.
- **No escribe contraseñas ni datos personales por su cuenta**: Claude pide al usuario que escriba él mismo
  los datos sensibles (por ejemplo, la cédula en el simulador PythonLab).
- **Pregunta antes de lo irreversible**: guardar o sobrescribir un archivo del usuario, cerrar con cambios sin
  guardar, borrar, enviar, publicar o aceptar avisos de confianza o permisos (como "Trust Folder" de VS Code).

---

## 10. Cómo funciona por dentro

Todo está en `scripts\capturar_ventana.ps1`. Usa funciones de Windows a través de un pequeño bloque de C#
que PowerShell compila al vuelo:

| Tarea | Función de Windows |
|---|---|
| Listar ventanas | `EnumWindows` (ventanas visibles, con título y no ocultas por el sistema: `DWMWA_CLOAKED`) |
| Saber a qué programa pertenece una ventana | `GetWindowThreadProcessId` |
| Saber de qué ventana principal depende un menú o diálogo | `GetAncestor(GA_ROOTOWNER)`. Las ventanas sin título del mismo programa (menús emergentes) también se aceptan; una con título es otra ventana principal y frena. |
| Traer al frente | `SetForegroundWindow`. Windows solo lo permite al programa que envió la última tecla, así que antes simula la tecla F24, que no hace nada en ninguna aplicación. Usar Alt abría el menú de VS Code. |
| Maximizar / restaurar | `ShowWindow` |
| Atajos (`keys:`) | `System.Windows.Forms.SendKeys` |
| Texto (`text:`) | `SendInput` con `KEYEVENTF_UNICODE`, una letra por vez con 8 ms de pausa. Con SendKeys, en teclados latinoamericanos o españoles los símbolos de AltGr (`^ ` ~ @ \`) salían como Ctrl+Alt+tecla: cambiaban, se perdían o disparaban atajos de la app. Si se mandan todas las letras juntas, algunas apps (el Bloc de notas) repiten la última. |
| Mouse | `mouse_event` con movimiento absoluto (`MOVE \| ABSOLUTE \| VIRTUALDESK`) + `SetCursorPos` para clavar el punto exacto. Solo con `SetCursorPos`, los lienzos modernos (Paint de Windows 11) no ven el movimiento y un arrastre queda en un punto. |
| Qué hay en un punto | `WindowFromPoint` + `GetAncestor` |
| Borde visible de la ventana | `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)` (sin la sombra transparente) |
| Captura | `Graphics.CopyFromScreen`: copia los píxeles de la pantalla en ese rectángulo |
| Escala de pantalla | `SetThreadDpiAwarenessContext(PER_MONITOR_AWARE_V2)`, para trabajar en píxeles reales |
| Varios monitores | `GetSystemMetrics(SM_XVIRTUALSCREEN…)`: el rectángulo de todos los monitores |

Como la captura copia lo que se ve en pantalla, la ventana tiene que estar visible y al frente (el script la
trae). Si un menú del mismo programa está abierto encima, sale en la captura, que es lo esperado. Pero también
sale cualquier otra ventana "siempre visible" que la tape, sin aviso. Y lo que se sale del borde (un menú
contextual) queda cortado: para eso, `-PantallaCompleta`.

---

## 11. Prueba automática

`pruebas\probar_skill.ps1` comprueba todas las funciones sin tocar tus programas. Abre su propia ventana de
prueba (con un campo de texto, botones, una zona de clics, una lista y una zona de arrastre), la maneja solo
con `capturar_ventana.ps1` y revisa en el registro de esa ventana que cada acción haya llegado.

```powershell
powershell -ExecutionPolicy Bypass -File "$HOME\.claude\skills\captura-ventana\pruebas\probar_skill.ps1"
```

Dura unos 20 segundos, durante los cuales no hay que usar el teclado ni el mouse. Al final muestra OK o FALLA
por cada función y deja las capturas y el registro en `%TEMP%\prueba_captura_ventana`.

**Resultado del 30 de octubre de 2026: 14 de 14 OK** (teclado Latinoamericano, dos monitores). La versión 2,
con estas mismas pruebas, da 11 de 14: falla el texto con símbolos de AltGr y no frena ante otra ventana
principal del mismo programa.

| Comprobación | Resultado |
|---|---|
| Escribir texto con símbolos, tildes y ñ: ``hola (prueba) {1+1} áéíóú ñÑ ¿¡ x^2 `ok` a@b.co C:\d ~fin #[1]`` | OK |
| Clic izquierdo en un botón | OK |
| Doble clic | OK |
| Clic derecho | OK |
| Rueda del mouse (3 muescas hacia abajo) | OK |
| Arrastrar | OK |
| Abrir una ventana secundaria | OK |
| Encontrar la ventana secundaria con `-Listar` | OK |
| Clic en la ventana secundaria | OK |
| Detenerse si otra ventana principal del mismo programa toma el foco | OK |
| La otra ventana principal no recibió texto | OK |
| Rechazar un clic fuera de la ventana | OK |
| Cerrar con Alt+F4 | OK |
| El puntero vuelve a su lugar | OK |

**Pruebas con programas reales (30/10/2026):**
- **Bloc de notas:** texto con tildes, €, flechas y emojis, y los 94 caracteres ASCII; guardar; menús.
- **Paint:** lápiz, marcador, rectángulo y texto; desplegables, menú Archivo con su submenú y el diálogo de
  "No guardar".
- **Calculadora** (app de la Tienda): por teclado, con texto y con clics, también desde minimizada.
- **Terminales:** cmd dentro de Windows Terminal.
- **VS Code:** el flujo de crear una terminal, maximizar el panel y ejecutar Python, en un monitor al 125 %.
- **Word:** texto con correo y ruta, dos documentos a la vez y el diálogo "¿Desea guardar?".
- **Explorador de archivos:** doble clic, clic derecho y Alt+↑.
- **Frenos:** no hizo clic bajo una ventana que tapaba el punto, y se detuvo cuando otra ventana tomó el foco.
- **Pantalla completa** con dos monitores de escalas distintas (3840×1080).

---

## 12. Límites conocidos

- **Programas abiertos como administrador:** se pueden capturar, pero Windows no deja enviarles teclas ni clics
  desde un programa normal.
- **Pantalla negra** en juegos a pantalla completa y videos protegidos (Netflix, por ejemplo).
- **No funciona** con la pantalla bloqueada ni con las ventanas de permisos de administrador (UAC).
- **Usa el teclado y el mouse reales:** mientras trabaja, el usuario no debe usarlos.
- **No lee la pantalla:** siempre hay que mirar la captura para saber qué pasó.
- **Las esperas son fijas** (`wait:`): si un programa tarda más de lo previsto, hay que aumentarlas.
- **Autocorrección de los programas:** Word y el Bloc de notas corrigen lo escrito (mayúsculas, tildes, enlaces).
  No es un error de la skill, pero hay que tenerlo en cuenta al comparar.
- **Programas que reabren documentos:** Word y el Bloc de notas pueden abrir solos documentos del usuario al
  arrancar. Antes de mandar teclas hay que mirar `-Listar` y apuntar con `-Hwnd` a la ventana propia.
- **La captura no avisa si algo la tapa**, y lo que se sale de la ventana queda cortado.
- **Sin probar todavía:** Excel, Configuración y Fotos, y programas abiertos como administrador.

---

## 13. Solución de problemas

| Mensaje o síntoma | Qué hacer |
|---|---|
| `No se encontro ninguna ventana…` | Ejecutar `-Listar` y usar el título o el handle que aparece. |
| `Coinciden N ventanas…` (aviso) | Usar `-Listar` y elegir con `-Hwnd` para no depender del orden. |
| `Windows no dejo traer la ventana al frente` | Hacer un clic en esa ventana y repetir. |
| `La ventana elegida dejo de estar al frente…` | Alguien o algo (una notificación, otro documento del mismo programa) tomó el foco. Mirar `-Listar` y repetir sin usar el equipo. |
| `El paso '…' necesita N numeros enteros…` | Las coordenadas están mal escritas: van enteros separados por coma (`click:120,340`). |
| `…hay otra ventana encima…` | Algo tapa ese punto. Esperar a que se vaya o moverlo, y repetir. |
| `…queda fuera de la ventana…` | Las coordenadas no corresponden a esta ventana: capturarla y medir de nuevo. |
| La captura sale negra o con otra ventana | La ventana estaba minimizada o tapada: repetir con `-Maximizar`. |
| «No se puede cargar el archivo… la ejecución de scripts está deshabilitada» | Ejecutar antes `Set-ExecutionPolicy -Scope Process Bypass -Force` (solo afecta a esa ventana de PowerShell). |
| En VS Code el texto no llega a la terminal | La paleta de comandos eligió otro comando o el foco quedó en otro lado. Ver los trucos de VS Code en `SKILL.md`. |
| En VS Code no se abre la terminal | La carpeta está en Modo Restringido y VS Code pide "Trust Folder". No aceptarlo por el usuario; en una ventana de prueba propia, abrirla con `code -n --disable-workspace-trust <carpeta>`. |
| Desde Bash, los pasos llegan pegados (`,keys:` escrito en la ventana) | Se llamó con `-File`: usar `-Command "& '…ps1' -Pasos @('…','…')"`. |

---

## 14. Posibles mejoras

### Prioridad alta

1. **Hacer clic por nombre en vez de por coordenadas.** Con *UI Automation* (incluido en Windows), un paso como
   `boton:Guardar` buscaría el botón por su texto. Sería más fácil, no dependería del tamaño de la ventana y
   también permitiría leer el texto de un campo para comprobar un resultado sin mirar la captura.
2. **Esperas inteligentes.** Pasos como `esperar-ventana:Guardar como` o «esperar a que la pantalla cambie», en
   vez de tiempos fijos. Haría todo más rápido y confiable.
3. **Aviso en pantalla y botón de pánico.** Un aviso visible con cuenta regresiva antes de tomar el control, y
   cancelar al instante si el usuario mueve el mouse a una esquina o presiona Esc.
4. **Clics con teclas mantenidas.** `click:x,y,ctrl` o `click:x,y,shift` para seleccionar varios archivos o
   abrir enlaces en otra pestaña.

### Prioridad media

5. **Leer texto de la pantalla (OCR).** Windows trae OCR (`Windows.Media.Ocr`): podría encontrar dónde dice
   «Aceptar» y hacer clic ahí, o extraer texto de una captura.
6. **Capturar ventanas tapadas sin traerlas al frente.** Con `PrintWindow` se podría capturar sin interrumpir al
   usuario.
7. **Recortar y marcar.** `-Region x,y,ancho,alto` para recortar solo una parte, y dibujar un círculo donde se
   hizo clic. Útil para manuales y evidencias.
8. **Grabar el proceso.** Guardar una secuencia de capturas como GIF o video, para evidenciar un procedimiento
   paso a paso.
9. **Abrir y cerrar programas.** `-Abrir "notepad.exe"` y cerrar al final solo lo que la skill abrió.
10. **Avisar si algo tapa la captura.** Antes de capturar, revisar si otra ventana se cruza con el rectángulo
    y decirlo (hoy sale en la foto sin aviso).
11. **Registro de acciones.** Un archivo con la hora y el detalle de cada acción, como evidencia o para revisar
    qué pasó.

### Prioridad baja

12. **Programas como administrador.** Ejecutar el script con permisos elevados, siempre con confirmación del
    usuario.
13. **Instalador de un clic.** Un script que copie la skill a `.claude\skills` automáticamente.
14. **Más pruebas.** Excel, Configuración, Fotos y una notificación real de Windows encima.

---

## 15. Historial de versiones

| Versión | Fecha | Cambios |
|---|---|---|
| 1 | 29/10/2026 | Buscar una ventana por título, traerla al frente, maximizar, enviar teclas y capturar. Probada en VS Code para las evidencias de la Fase 4. Se corrigió que la tecla Alt abría el menú de VS Code: ahora usa F24. |
| 2 | 29/10/2026 | Mouse (clic, doble clic, clic derecho, mover, rueda, arrastrar). Ventanas secundarias y diálogos (`-Listar`, `-Indice`, `-Hwnd`, `-Proceso`). Captura de todos los monitores. Protecciones: no actuar si cambia el programa al frente, no hacer clic si hay algo encima, rechazar coordenadas fuera de la ventana y devolver el puntero. Prueba automática: 12 de 12 OK, incluido texto con tildes y ñ. |
| 3 | 30/10/2026 | Prueba a fondo en otra PC (teclado Latinoamericano, dos monitores al 100 % y 125 %) con el Bloc de notas, Paint, la Calculadora, la terminal, VS Code, Word y el Explorador. Se corrigieron tres fallos. **1.** El texto se escribe en Unicode letra por letra: con SendKeys, `^` salía `&`, el acento grave se pegaba a la vocal, en Word se perdían `@` y `\`, y en VS Code se disparó un atajo. **2.** El mouse se mueve como uno real: en Paint los arrastres no dibujaban. **3.** El freno compara la ventana y no solo el programa: el texto terminó en otro documento de Word. Además: mensaje claro para números mal escritos, regla de preguntar antes de lo irreversible, trucos de Word en español, VS Code restringido y uso desde Bash. Prueba automática: 14 de 14 OK (la versión 2 da 11 de 14 con las pruebas nuevas). Créditos: Juan Sebastián Martín Moncada. |
