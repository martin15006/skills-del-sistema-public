<#
.SYNOPSIS
  Enfoca una ventana del escritorio (por titulo, programa o handle), opcionalmente
  le envia teclas y clics de mouse, y guarda una captura PNG de esa ventana o de
  la pantalla completa.

.EXAMPLE
  # Ver que ventanas hay, incluidas las secundarias y los dialogos
  .\capturar_ventana.ps1 -Listar
  .\capturar_ventana.ps1 -Listar -Proceso "WINWORD"

.EXAMPLE
  # Solo capturar VS Code
  .\capturar_ventana.ps1 -Titulo "Visual Studio Code" -Salida "$env:TEMP\vscode.png" -Maximizar

.EXAMPLE
  # Capturar una ventana concreta usando el handle que mostro -Listar
  .\capturar_ventana.ps1 -Hwnd 0x2A0F4 -Salida "$env:TEMP\dialogo.png"

.EXAMPLE
  # Clic en un boton (coordenadas medidas sobre una captura previa de esa ventana)
  .\capturar_ventana.ps1 -Titulo "Bloc de notas" -Salida "$env:TEMP\despues.png" -Pasos @("click:120,340", "wait:500")

.NOTES
  Pasos admitidos (en orden):
    wait:<ms>          espera esa cantidad de milisegundos
    keys:<teclas>      teclas en formato SendKeys (^ Ctrl, + Shift, % Alt, {ENTER}, {ESC}...)
    text:<texto>       texto literal; los caracteres especiales de SendKeys se escapan solos
    click:x,y          clic izquierdo
    dclick:x,y         doble clic
    rclick:x,y         clic derecho
    move:x,y           solo mueve el puntero (menus o ayudas que aparecen al pasar el mouse)
    scroll:x,y,n       rueda del mouse sobre x,y; n > 0 sube, n < 0 baja
    drag:x1,y1,x2,y2   arrastra con el boton izquierdo de x1,y1 a x2,y2
  Las coordenadas son pixeles dentro de la ventana elegida, medidos sobre una
  captura de esa misma ventana (la esquina superior izquierda es 0,0).

  Seguridad: antes de cada paso se comprueba que la ventana al frente sea del
  mismo programa, y antes de cada clic, que en ese punto no haya otra ventana
  encima (una notificacion, otro programa). Si algo no cuadra, se detiene sin
  hacer nada mas. Al terminar, el puntero vuelve a donde estaba.
#>
param(
    [string]$Titulo = "",
    [string]$Proceso = "",
    [int]$Indice = 1,
    [string]$Hwnd = "",
    [switch]$Listar,
    [string]$Salida = "",
    [switch]$Maximizar,
    [switch]$PantallaCompleta,
    [string[]]$Pasos = @(),
    [int]$EsperaFinalMs = 600
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not ("CapturaVentanaV2" -as [type])) {
    Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class CapturaVentanaV2 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr ctx);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, int dx, int dy, int data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out RECT r, int size);
    [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int v, int size);

    // Ventanas visibles con titulo, de la que esta mas al frente a la de mas atras.
    // Se omiten las "ocultas por DWM" (apps de la Tienda suspendidas, otros escritorios).
    public static List<IntPtr> VentanasVisibles() {
        var lista = new List<IntPtr>();
        EnumWindows(delegate (IntPtr h, IntPtr l) {
            int oculta;
            bool cloaked = DwmGetWindowAttribute(h, 14, out oculta, 4) == 0 && oculta != 0;
            if (IsWindowVisible(h) && GetWindowTextLength(h) > 0 && !cloaked) lista.Add(h);
            return true;
        }, IntPtr.Zero);
        return lista;
    }
    public static string Titulo(IntPtr h) {
        var sb = new StringBuilder(GetWindowTextLength(h) + 1);
        GetWindowText(h, sb, sb.Capacity);
        return sb.ToString();
    }
    public static uint Pid(IntPtr h) { uint pid; GetWindowThreadProcessId(h, out pid); return pid; }
    // Borde visible de la ventana (sin la sombra); cae a GetWindowRect si DWM no responde
    public static RECT Marco(IntPtr h) {
        RECT r;
        if (DwmGetWindowAttribute(h, 9, out r, 16) != 0) GetWindowRect(h, out r);
        return r;
    }
}
"@
}
$W = [CapturaVentanaV2]

# Coordenadas en pixeles reales aunque Windows tenga escala (125 %, 150 %...)
[void]$W::SetThreadDpiAwarenessContext([IntPtr](-4))
[void]$W::SetProcessDPIAware()

$nombresProceso = @{}
function Nombre-Proceso([uint32]$procId) {
    if (-not $nombresProceso.ContainsKey($procId)) {
        $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
        $nombresProceso[$procId] = if ($p) { $p.ProcessName } else { "?" }
    }
    return $nombresProceso[$procId]
}

function Ventanas-Que-Coinciden {
    foreach ($v in $W::VentanasVisibles()) {
        $t = $W::Titulo($v)
        $procId = $W::Pid($v)
        $nombre = Nombre-Proceso $procId
        if ($Titulo -and $t -notmatch $Titulo) { continue }
        if ($Proceso -and $nombre -notmatch $Proceso) { continue }
        $r = $W::Marco($v)
        [pscustomobject]@{
            Handle = $v; Hex = ('0x{0:X}' -f $v.ToInt64()); ProcId = $procId; Proceso = $nombre; Titulo = $t
            Ancho = $r.Right - $r.Left; Alto = $r.Bottom - $r.Top; Minimizada = $W::IsIconic($v)
        }
    }
}

if ($Listar) {
    $lista = @(Ventanas-Que-Coinciden)
    if ($lista.Count -eq 0) { Write-Output "No hay ventanas visibles que coincidan."; exit 0 }
    Write-Output "N.  Handle     Programa           Tamano     Titulo   (orden: de la mas al frente a la de mas atras)"
    $i = 0
    foreach ($v in $lista) {
        $i++
        $tam = if ($v.Minimizada) { "minimizada" } else { "{0}x{1}" -f $v.Ancho, $v.Alto }
        Write-Output ("{0,-3} {1,-10} {2,-18} {3,-10} {4}" -f $i, $v.Hex, $v.Proceso, $tam, $v.Titulo)
    }
    exit 0
}

function Traer-AlFrente([IntPtr]$v) {
    if ($W::IsIconic($v)) { [void]$W::ShowWindow($v, 9); Start-Sleep -Milliseconds 300 }   # SW_RESTORE
    if ($W::GetForegroundWindow() -eq $v) { return $true }
    # Windows solo deja cambiar el foco al proceso que envio la ultima tecla.
    # Se usa F24 (no hace nada en ninguna app); Alt abriria el menu de la ventana.
    foreach ($tecla in 0x87, 0x12) {
        $W::keybd_event($tecla, 0, 0, [UIntPtr]::Zero)
        [void]$W::SetForegroundWindow($v)
        $W::keybd_event($tecla, 0, 2, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 400
        if ($W::GetForegroundWindow() -eq $v) { return $true }
    }
    return $false
}

# text: se envia caracter por caracter como Unicode (SendInput con KEYEVENTF_UNICODE).
# Asi no depende de la distribucion del teclado: con SendKeys, en teclados latinoamericanos
# o espanoles el ^ salia como & y el acento grave quedaba como tecla muerta (` + a = a con tilde).
# El salto de linea se envia como la tecla Enter.
if (-not ("TextoUnicodeCV" -as [type])) {
    Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class TextoUnicodeCV {
    [StructLayout(LayoutKind.Sequential)] struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }
    [StructLayout(LayoutKind.Explicit)] struct UNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] struct INPUT { public uint type; public UNION u; }
    [DllImport("user32.dll", SetLastError = true)] static extern uint SendInput(uint n, INPUT[] entradas, int tam);
    static INPUT Tecla(ushort vk, ushort scan, uint flags) {
        var e = new INPUT(); e.type = 1; e.u.ki.wVk = vk; e.u.ki.wScan = scan; e.u.ki.dwFlags = flags; return e;
    }
    // Una letra por vez con una pausa: si se mandan todas juntas, algunas apps (el Bloc de notas
    // de Windows 11, por ejemplo) leen la letra cuando ya llego la siguiente y repiten la ultima.
    public static uint Escribir(string texto, int pausaMs) {
        uint enviados = 0;
        int tam = Marshal.SizeOf(typeof(INPUT));
        foreach (char c in texto) {
            if (c == '\r') continue;
            INPUT[] par = (c == '\n')
                ? new INPUT[] { Tecla(0x0D, 0, 0), Tecla(0x0D, 0, 2) }
                : new INPUT[] { Tecla(0, c, 4), Tecla(0, c, 4 | 2) };   // KEYEVENTF_UNICODE, KEYUP
            enviados += SendInput(2, par, tam);
            System.Threading.Thread.Sleep(pausaMs);
        }
        return enviados;
    }
}
"@
}

function Escapar-SendKeys([string]$texto) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $texto.ToCharArray()) {
        if ('+^%~(){}[]'.Contains([string]$c)) { [void]$sb.Append('{').Append($c).Append('}') }
        else { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}

function Guardar-Captura([int]$x, [int]$y, [int]$ancho, [int]$alto) {
    $bmp = New-Object System.Drawing.Bitmap $ancho, $alto
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size $ancho, $alto))
    $carpeta = Split-Path -Parent $Salida
    if ($carpeta -and -not (Test-Path $carpeta)) { New-Item -ItemType Directory -Force $carpeta | Out-Null }
    $bmp.Save($Salida, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output "Captura guardada: $Salida ($ancho x $alto)"
}

# Pantalla completa sin elegir ventana: todos los monitores juntos
if ($PantallaCompleta -and -not ($Titulo -or $Proceso -or $Hwnd)) {
    if ($Pasos.Count -gt 0) { throw "Para enviar pasos hay que elegir una ventana (-Titulo, -Proceso o -Hwnd)." }
    if (-not $Salida) { throw "Falta -Salida." }
    Guardar-Captura ($W::GetSystemMetrics(76)) ($W::GetSystemMetrics(77)) ($W::GetSystemMetrics(78)) ($W::GetSystemMetrics(79))
    exit 0
}

# Elegir la ventana
$coincidencias = @()
if ($Hwnd) {
    $base = if ($Hwnd -match '^0x') { 16 } else { 10 }
    $h = [IntPtr][Convert]::ToInt64(($Hwnd -replace '^0x', ''), $base)
    if (-not $W::IsWindow($h)) { throw "No existe ninguna ventana con handle $Hwnd. Usa -Listar para ver las que hay." }
} else {
    if (-not ($Titulo -or $Proceso)) { throw "Indica -Titulo, -Proceso o -Hwnd (o usa -Listar para ver las ventanas)." }
    $coincidencias = @(Ventanas-Que-Coinciden)
    if ($coincidencias.Count -eq 0) { throw "No se encontro ninguna ventana visible que coincida. Usa -Listar para ver las que hay." }
    if ($coincidencias.Count -lt $Indice) { throw "Coinciden $($coincidencias.Count) ventana(s); no existe la numero $Indice. Usa -Listar para verlas." }
    $h = $coincidencias[$Indice - 1].Handle
}
$procObjetivo = $W::Pid($h)
Write-Output ("Ventana: '{0}' (programa {1}, PID {2}, handle 0x{3:X})" -f $W::Titulo($h), (Nombre-Proceso $procObjetivo), $procObjetivo, $h.ToInt64())
if ($coincidencias.Count -gt 1) {
    Write-Output "Aviso: coinciden $($coincidencias.Count) ventanas y se uso la numero $Indice. Para elegir una fija, usa -Listar y -Hwnd."
}

if (-not (Traer-AlFrente $h)) { throw "Windows no dejo traer la ventana al frente. Pide al usuario que haga click en ella y repite." }
if ($Maximizar) { [void]$W::ShowWindow($h, 3); Start-Sleep -Milliseconds 700 }   # SW_MAXIMIZE

# La ventana elegida y lo que cuelga de ella (sus dialogos, menus y ventanas emergentes).
# No alcanza con que sea del mismo programa: Word, VS Code o el Explorador tienen varias
# ventanas principales en un mismo proceso, y el texto podia terminar en otro documento.
function Es-DeLaVentana([IntPtr]$v) {
    if ($v -eq [IntPtr]::Zero -or $W::Pid($v) -ne $procObjetivo) { return $false }
    $duena = $W::GetAncestor($v, 3)   # GA_ROOTOWNER: la ventana principal de la que depende
    if ($duena -eq [IntPtr]::Zero) { $duena = $v }
    if ($duena -eq $h) { return $true }
    # Sin titulo: un menu o una ventana emergente suelta. Con titulo: otra ventana principal (otro documento).
    return ($W::GetWindowTextLength($duena) -eq 0)
}

function Exigir-AlFrente([string]$paso) {
    if (-not (Es-DeLaVentana ($W::GetForegroundWindow()))) {
        throw "La ventana elegida dejo de estar al frente antes del paso '$paso'. Se detuvo para no actuar sobre otra ventana."
    }
}

function Numeros([string]$valor, [int]$cantidad, [string]$paso) {
    $n = @($valor -split ',' | ForEach-Object {
        $t = $_.Trim()
        if ($t -notmatch '^-?\d+$') { throw "El paso '$paso' necesita $cantidad numeros enteros separados por coma." }
        [int]$t
    })
    if ($n.Count -ne $cantidad) { throw "El paso '$paso' necesita $cantidad numeros separados por coma." }
    return , $n
}

# Convierte x,y de la ventana a coordenadas de pantalla y comprueba que el clic caiga en ella
function A-Pantalla([int]$x, [int]$y, [string]$paso) {
    $r = $W::Marco($h)
    $ancho = $r.Right - $r.Left; $alto = $r.Bottom - $r.Top
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $ancho -or $y -ge $alto) {
        throw "El punto $x,$y del paso '$paso' queda fuera de la ventana ($ancho x $alto)."
    }
    $p = New-Object CapturaVentanaV2+POINT
    $p.X = $r.Left + $x; $p.Y = $r.Top + $y
    $raiz = $W::GetAncestor($W::WindowFromPoint($p), 2)   # GA_ROOT
    if (-not ($raiz -eq $h -or (Es-DeLaVentana $raiz))) {
        throw "En el punto $x,$y del paso '$paso' hay otra ventana encima ('$($W::Titulo($raiz))'). Se detuvo sin hacer clic."
    }
    return $p
}

# Mueve el puntero como un mouse de verdad (movimiento absoluto sobre todos los monitores).
# Solo con SetCursorPos, los lienzos modernos (Paint de Windows 11) no ven el movimiento y
# un arrastre queda en un punto.
function Mover-Real([int]$x, [int]$y) {
    $vx = $W::GetSystemMetrics(76); $vy = $W::GetSystemMetrics(77); $vw = $W::GetSystemMetrics(78); $vh = $W::GetSystemMetrics(79)
    $nx = [int][Math]::Round(($x - $vx) * 65535.0 / ($vw - 1))
    $ny = [int][Math]::Round(($y - $vy) * 65535.0 / ($vh - 1))
    $W::mouse_event(0xC001, $nx, $ny, 0, [UIntPtr]::Zero)   # MOVE | VIRTUALDESK | ABSOLUTE
}

function Mover-Puntero($p) { Mover-Real $p.X $p.Y; [void]$W::SetCursorPos($p.X, $p.Y); Start-Sleep -Milliseconds 80 }

function Pulsar([uint32]$abajo, [uint32]$arriba) {
    $W::mouse_event($abajo, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    $W::mouse_event($arriba, 0, 0, 0, [UIntPtr]::Zero)
}

$usaMouse = @($Pasos | Where-Object { $_ -match '^(click|dclick|rclick|move|scroll|drag):' }).Count -gt 0
$cursorOriginal = New-Object CapturaVentanaV2+POINT
[void]$W::GetCursorPos([ref]$cursorOriginal)

try {
    foreach ($paso in $Pasos) {
        $tipo, $valor = $paso -split ':', 2
        if ($tipo -ne 'wait') { Exigir-AlFrente $paso }
        switch ($tipo) {
            'wait' { Start-Sleep -Milliseconds ([int]$valor) }
            'keys' { [System.Windows.Forms.SendKeys]::SendWait($valor) }
            'text' {
                $enviados = [TextoUnicodeCV]::Escribir($valor, 8)
                if ($valor.Length -gt 0 -and $enviados -eq 0) { throw "Windows no acepto el texto del paso '$paso' (puede estar abierto como administrador)." }
            }
            'click' {
                $n = Numeros $valor 2 $paso
                Mover-Puntero (A-Pantalla $n[0] $n[1] $paso); Pulsar 0x02 0x04
            }
            'dclick' {
                $n = Numeros $valor 2 $paso
                Mover-Puntero (A-Pantalla $n[0] $n[1] $paso); Pulsar 0x02 0x04; Start-Sleep -Milliseconds 60; Pulsar 0x02 0x04
            }
            'rclick' {
                $n = Numeros $valor 2 $paso
                Mover-Puntero (A-Pantalla $n[0] $n[1] $paso); Pulsar 0x08 0x10
            }
            'move' {
                $n = Numeros $valor 2 $paso
                Mover-Puntero (A-Pantalla $n[0] $n[1] $paso)
            }
            'scroll' {
                $n = Numeros $valor 3 $paso
                Mover-Puntero (A-Pantalla $n[0] $n[1] $paso)
                $W::mouse_event(0x0800, 0, 0, 120 * $n[2], [UIntPtr]::Zero)   # MOUSEEVENTF_WHEEL
            }
            'drag' {
                $n = Numeros $valor 4 $paso
                $desde = A-Pantalla $n[0] $n[1] $paso
                $hasta = A-Pantalla $n[2] $n[3] $paso
                Mover-Puntero $desde
                $W::mouse_event(0x02, 0, 0, 0, [UIntPtr]::Zero)
                for ($i = 1; $i -le 15; $i++) {
                    Mover-Real ($desde.X + [int](($hasta.X - $desde.X) * $i / 15)) ($desde.Y + [int](($hasta.Y - $desde.Y) * $i / 15))
                    Start-Sleep -Milliseconds 20
                }
                Mover-Puntero $hasta
                $W::mouse_event(0x04, 0, 0, 0, [UIntPtr]::Zero)
            }
            default { throw "Paso no reconocido: '$paso' (usa wait, keys, text, click, dclick, rclick, move, scroll o drag)." }
        }
        if ($tipo -ne 'wait') { Start-Sleep -Milliseconds 120 }
    }

    if (-not $Salida) { Write-Output "Sin -Salida: no se guardo captura."; return }

    Start-Sleep -Milliseconds $EsperaFinalMs
    if ($PantallaCompleta) {
        Guardar-Captura ($W::GetSystemMetrics(76)) ($W::GetSystemMetrics(77)) ($W::GetSystemMetrics(78)) ($W::GetSystemMetrics(79))
    } else {
        if (-not $W::IsWindow($h)) { throw "La ventana se cerro durante los pasos; no hay nada que capturar." }
        if (-not (Es-DeLaVentana ($W::GetForegroundWindow()))) { [void](Traer-AlFrente $h) }
        $r = $W::Marco($h)
        Guardar-Captura $r.Left $r.Top ($r.Right - $r.Left) ($r.Bottom - $r.Top)
    }
} finally {
    if ($usaMouse) { [void]$W::SetCursorPos($cursorOriginal.X, $cursorOriginal.Y) }
}
