<#
.SYNOPSIS
  Prueba automatica de la skill captura-ventana.

.DESCRIPTION
  Abre una ventana de prueba propia (ventana_prueba.ps1) y, usando solo
  capturar_ventana.ps1, escribe texto, hace clic, doble clic, clic derecho,
  usa la rueda, arrastra, abre una ventana secundaria, la encuentra con -Listar,
  la cierra con un clic, comprueba que se detenga si otra ventana principal del
  mismo programa toma el foco (sin escribirle nada), que un clic fuera de la
  ventana se rechace y cierra todo con Alt+F4. Despues revisa en el registro de la ventana de prueba
  que cada accion haya llegado y muestra OK o FALLA. No toca otros programas.

  Mientras corre (unos 20 segundos) no hay que usar el teclado ni el mouse.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\probar_skill.ps1
#>
param([string]$Carpeta = (Join-Path $env:TEMP "prueba_captura_ventana"))

$ErrorActionPreference = "Stop"
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$cap = Join-Path (Split-Path -Parent $aqui) "scripts\capturar_ventana.ps1"
New-Item -ItemType Directory -Force $Carpeta | Out-Null
$registro = Join-Path $Carpeta "registro.txt"
$pos = Join-Path $Carpeta "posiciones.json"
$posSec = Join-Path $Carpeta "posiciones_secundaria.json"
Remove-Item $registro, $pos, $posSec -ErrorAction SilentlyContinue

function Esperar-Archivo([string]$ruta, [string]$que) {
    for ($i = 0; $i -lt 60 -and -not (Test-Path $ruta); $i++) { Start-Sleep -Milliseconds 250 }
    if (-not (Test-Path $ruta)) { throw "No aparecio $que." }
    Start-Sleep -Milliseconds 300
    return Get-Content $ruta -Raw | ConvertFrom-Json
}

# Convierte un punto de pantalla a coordenadas dentro de la ventana (como en sus capturas)
function Rel([int64]$handle, $punto) {
    $r = [CapturaVentanaV2]::Marco([IntPtr]$handle)
    return "{0},{1}" -f ($punto.X - $r.Left), ($punto.Y - $r.Top)
}

Write-Output "Abriendo la ventana de prueba. No uses el teclado ni el mouse durante unos 20 segundos..."
$proceso = Start-Process powershell -PassThru -ArgumentList @(
    '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
    '-File', "`"$aqui\ventana_prueba.ps1`"", '-Registro', "`"$registro`"", '-Posiciones', "`"$pos`"")

# Texto con simbolos de SendKeys y con caracteres del espanol (aeiou con tilde, enie, signos de apertura).
# Se arma con codigos para que este archivo siga siendo ASCII y PowerShell 5.1 lo lea bien.
# Incluye los simbolos que en teclados latinoamericanos o espanoles van con AltGr o son teclas muertas
# (^ ` ~ @ \ # [ ]): con SendKeys salian cambiados (^ -> &, ` + o -> o con tilde) o se perdian.
$textoPrueba = "hola (prueba) {1+1} " + (-join [char[]]@(0xE1, 0xE9, 0xED, 0xF3, 0xFA, 0x20, 0xF1, 0xD1, 0x20, 0xBF, 0xA1)) +
    ' x^2 `ok` a@b.co C:\d ~fin #[1]'

$resultados = [ordered]@{}
try {
    $p = Esperar-Archivo $pos "la ventana de prueba"
    & $cap -Listar -Titulo "Prueba captura-ventana" | Out-Null   # carga el tipo CapturaVentanaV2 y la escala real
    $hp = '0x{0:X}' -f [int64]$p.handle

    $antes = New-Object CapturaVentanaV2+POINT
    [void][CapturaVentanaV2]::GetCursorPos([ref]$antes)

    & $cap -Hwnd $hp -Salida (Join-Path $Carpeta "1_principal.png") -Pasos @(
        "click:$(Rel $p.handle $p.texto)", "text:$textoPrueba",
        "click:$(Rel $p.handle $p.boton1)",
        "dclick:$(Rel $p.handle $p.zona)",
        "rclick:$(Rel $p.handle $p.zona)",
        "scroll:$(Rel $p.handle $p.lista),-3",
        "drag:$(Rel $p.handle $p.arrastreInicio),$(Rel $p.handle $p.arrastreFin)",
        "click:$(Rel $p.handle $p.abrir)", "wait:800") | Out-Null

    $s = Esperar-Archivo $posSec "la ventana secundaria"
    $lista = & $cap -Listar -Titulo "Prueba captura-ventana"
    $resultados["Encontrar la ventana secundaria con -Listar"] = [bool]($lista | Where-Object { $_ -match 'Secundaria' })

    $hs = '0x{0:X}' -f [int64]$s.handle
    & $cap -Hwnd $hs -Salida (Join-Path $Carpeta "2_secundaria.png") | Out-Null
    & $cap -Hwnd $hs -Pasos @("click:$(Rel $s.handle $s.cerrar)", "wait:700") | Out-Null

    # Otra ventana principal del mismo programa toma el foco a mitad de los pasos: debe detenerse sin escribir
    $detenido = $false
    try { & $cap -Hwnd $hp -Pasos @("click:$(Rel $p.handle $p.otra)", "wait:1500", "text:NO DEBE LLEGAR") | Out-Null }
    catch { $detenido = $_.Exception.Message -match 'dejo de estar al frente' }
    $resultados["Detenerse si otra ventana del mismo programa toma el foco"] = $detenido

    $rechazado = $false
    try { & $cap -Hwnd $hp -Pasos @("click:99999,99999") | Out-Null } catch { $rechazado = $_.Exception.Message -match 'fuera de la ventana' }
    $resultados["Rechazar un clic fuera de la ventana"] = $rechazado

    $despues = New-Object CapturaVentanaV2+POINT
    [void][CapturaVentanaV2]::GetCursorPos([ref]$despues)
    $resultados["El puntero vuelve a su lugar"] = ($antes.X -eq $despues.X -and $antes.Y -eq $despues.Y)

    & $cap -Hwnd $hp -Pasos @("keys:%{F4}", "wait:900") | Out-Null
} finally {
    Start-Sleep -Milliseconds 300
    if (-not $proceso.HasExited) { Stop-Process -Id $proceso.Id -Force }
}

$log = @(Get-Content $registro -Encoding UTF8)
$arrastre = $log | Where-Object { $_ -like "arrastre de *" } | Select-Object -First 1
$distanciaArrastre = 0
if ($arrastre -match '^arrastre de (\d+),\d+ a (\d+),\d+$') { $distanciaArrastre = [int]$Matches[2] - [int]$Matches[1] }
$comprobaciones = [ordered]@{
    "Escribir texto con simbolos, tildes y enie" = $log -contains "clic Boton 1; texto=$textoPrueba"
    "Clic izquierdo en un boton"             = [bool]($log | Where-Object { $_ -like "clic Boton 1*" })
    "Doble clic"                             = $log -contains "zona doble clic"
    "Clic derecho"                           = $log -contains "zona mousedown Right"
    "Rueda del mouse (3 muescas abajo)"      = $log -contains "rueda delta=-360"
    "Arrastrar"                              = $distanciaArrastre -gt 100
    "Abrir una ventana secundaria"           = $log -contains "abre secundaria"
    "Clic en la ventana secundaria"          = $log -contains "clic Cerrar secundaria"
    "Cerrar con Alt+F4"                      = [bool]($log | Where-Object { $_ -like "cerrada*" })
    "La otra ventana principal no recibio texto" = -not ($log | Where-Object { $_ -like "otra principal recibio*" })
}
foreach ($k in $resultados.Keys) { $comprobaciones[$k] = $resultados[$k] }

Write-Output ""
$fallas = 0
foreach ($k in $comprobaciones.Keys) {
    if ($comprobaciones[$k]) { Write-Output "  OK     $k" } else { Write-Output "  FALLA  $k"; $fallas++ }
}
Write-Output ""
Write-Output "Resultado: $($comprobaciones.Count - $fallas) de $($comprobaciones.Count) comprobaciones OK."
Write-Output "Capturas y registro en: $Carpeta"
if ($fallas -gt 0) { exit 1 }
