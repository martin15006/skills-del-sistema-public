<#
.SYNOPSIS
    Revisa si hay que actualizar algo de lo que instaló skills-del-sistema-public.

.DESCRIPTION
    Por defecto solo mira: no instala ni cambia nada.
    - Este repo: si hay una versión nueva en GitHub.
    - Skills: si la instalada es igual a la de su repo original (o a la copia de este repo).
    - agent-browser: la versión instalada contra la última, y si ya cerraron los bugs que esquivan las skills.
    - Plugins: cuándo se actualizó cada uno por última vez, y si los fijados siguen fijados.

.PARAMETER ActualizarPlugins
    Además actualiza los catálogos y los plugins (claude plugin update). Después hay que reiniciar Claude Code.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\revisar.ps1
#>
param(
    [switch]$ActualizarPlugins
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'inventario.ps1')
. (Join-Path $PSScriptRoot 'comun.ps1')

$pendientes = New-Object System.Collections.Generic.List[string]
$diasPlugin = 30

function Titulo([string]$texto) { Write-Host "`n== $texto ==" -ForegroundColor Cyan }
function Bien([string]$texto) { Write-Host "  OK  $texto" -ForegroundColor Green }
function Info([string]$texto) { Write-Host "      $texto" -ForegroundColor DarkGray }
function Ojo([string]$texto, [string]$queHacer) {
    Write-Host "  !!  $texto" -ForegroundColor Yellow
    if ($queHacer) { Write-Host "      -> $queHacer" -ForegroundColor Gray }
    $pendientes.Add($texto)
}

# Lo que hace que un plugin fijado no aguante, además del commit: un catálogo que no es la copia local, u
# otras versiones en el caché, que la app pudo haber bajado y cargado.
function ProblemasDelFijado($fijado, [string]$version) {
    $nombre, $market = $fijado.Plugin.Split('@')
    $problemas = @()
    if (-not (CatalogoFijadoLocal $fijado)) { $problemas += 'su catálogo no es la copia local' }
    $cache = Join-Path $env:USERPROFILE ".claude\plugins\cache\$market\$nombre"
    $otras = @(Get-ChildItem $cache -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $version })
    if ($otras.Count -gt 0) { $problemas += "hay otra versión en el caché ($(($otras | ForEach-Object { $_.Name }) -join ', '))" }
    return $problemas
}

function ApiGitHub([string]$ruta) {
    # Devuelve el objeto, o el código de error (404, etc.) como número.
    try { return Invoke-RestMethod "https://api.github.com/$ruta" -TimeoutSec 20 }
    catch {
        if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
        return 0
    }
}

$claude = BuscarClaude

# -------------------------------- Este repo --------------------------------
Titulo 'Este repo'
if (-not (Test-Path (Join-Path $PSScriptRoot '.git'))) {
    Info 'No es un clon de git (¿lo bajaste como .zip?): no puedo ver si hay una versión nueva'
} else {
    $local = (git -C $PSScriptRoot rev-parse HEAD 2>$null | Out-String).Trim()
    $remoto = ((git -C $PSScriptRoot ls-remote origin HEAD 2>$null | Out-String) -split '\s+')[0]
    if (-not $remoto) { Info 'No pude consultar GitHub' }
    elseif ($local -eq $remoto) { Bien 'Al día con GitHub' }
    else { Ojo 'Hay una versión nueva de este repo en GitHub' 'En esta carpeta: git pull, y después corré instalar.ps1' }
}

# ------------------------- Bajar los repos de las skills -------------------------
$temporal = Join-Path $env:TEMP ('revisar-skills-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $temporal | Out-Null
$clones = @{}
foreach ($repo in ($skillsSueltas | ForEach-Object { $_.Repo } | Sort-Object -Unique)) {
    $bajado = BajarDeGitHub $repo 'HEAD' (Join-Path $temporal ($repo -replace '/', '__'))
    if ($bajado) { $clones[$repo] = $bajado }
}
$dirSkills = Join-Path $env:USERPROFILE '.claude\skills'

# --------------------------------- Skills ---------------------------------
Titulo 'Skills'
foreach ($s in $skillsSueltas) {
    $instalada = Join-Path $dirSkills $s.Nombre
    if (-not (Test-Path $instalada)) { Ojo "$($s.Nombre) no está instalada" 'Corré instalar.ps1'; continue }
    if (-not $clones.ContainsKey($s.Repo)) { Info "$($s.Nombre): no pude bajar $($s.Repo) para comparar"; continue }
    $difs = @(Diferencias $instalada (Join-Path $clones[$s.Repo] $s.Carpeta))
    if ($difs.Count -eq 0) { Bien "$($s.Nombre): igual a $($s.Repo)" }
    else {
        Ojo "$($s.Nombre): distinta de $($s.Repo) ($($difs.Count) archivo(s))" 'Si no la cambiaste vos, salió una versión nueva: corré instalar.ps1 (la tuya queda en ~\.claude\skills-respaldo)'
    }
}
foreach ($s in $skillsDelRepo) {
    $instalada = Join-Path $dirSkills $s.Nombre
    if (-not (Test-Path $instalada)) { Ojo "$($s.Nombre) no está instalada" 'Corré instalar.ps1'; continue }
    $difs = @(Diferencias $instalada (Join-Path $PSScriptRoot ($s.Carpeta -replace '/', '\')))
    if ($difs.Count -eq 0) { Bien "$($s.Nombre): igual a la copia de este repo" }
    else {
        Ojo "$($s.Nombre): distinta de la copia de este repo ($($difs.Count) archivo(s))" 'Si hiciste git pull, corré instalar.ps1 (la tuya queda en ~\.claude\skills-respaldo)'
    }
}

# ------------------------------- agent-browser -------------------------------
Titulo 'agent-browser'
$agentBrowser = BuscarAgentBrowser
if (-not $agentBrowser) {
    Ojo 'agent-browser no está instalado' 'Corré instalar.ps1'
} else {
    # --version no abre el navegador, así que capturar su salida es seguro.
    $versionLocal = ((& $agentBrowser.Source --version 2>$null | Out-String) -replace 'agent-browser', '').Trim()
    $ultima = (npm view agent-browser version 2>$null | Out-String).Trim()
    if (-not $ultima) { Info "Instalada: $versionLocal (no pude consultar npm)" }
    elseif ($versionLocal -eq $ultima) { Bien "agent-browser $versionLocal (la última)" }
    else { Ojo "agent-browser $versionLocal; salió la $ultima" 'Con las ventanas de agent-browser cerradas: npm install -g agent-browser@latest' }
}

# ------------------------------ Bugs vigilados ------------------------------
Titulo 'Bugs de terceros que las skills esquivan'
foreach ($b in $bugsVigilados) {
    $issue = ApiGitHub "repos/$($b.Repo)/issues/$($b.Numero)"
    if ($issue -is [int]) { Info "No pude consultar $($b.Repo)#$($b.Numero)"; continue }
    if ($issue.state -eq 'closed') {
        Ojo "Cerraron $($b.Repo)#$($b.Numero): $($b.Que)" $b.QueHacer
    } else { Bien "$($b.Repo)#$($b.Numero) sigue abierto ($($b.Que))" }
}

# --------------------------------- Plugins ---------------------------------
Titulo 'Plugins'
if (-not $claude) {
    Info 'No encuentro Claude Code: salteo los plugins'
} elseif ($ActualizarPlugins) {
    Write-Host '  Actualizando los catálogos…'
    & $claude plugin marketplace update 2>&1 | Out-Null
    foreach ($p in $plugins) {
        $salida = (& $claude plugin update $p 2>&1 | Out-String)
        if ($salida -match 'already at the latest') { Bien "$p al día" }
        elseif ($salida -match 'updated from (\S+) to (\S+)') {
            Ojo "$p actualizado de $($Matches[1]) a $($Matches[2])" 'Reiniciá Claude Code. Si saltó de versión grande (ej. 5.x a 6.x), mirá qué cambió en su repo'
        } else { Ojo "$p no se pudo actualizar" ''; Info ($salida.Trim()) }
    }
} else {
    $lista = $null
    try { $lista = (& $claude plugin list --json 2>$null | Out-String) | ConvertFrom-Json } catch { }
    if (-not $lista) { Info 'No pude leer la lista de plugins' }
    else {
        $viejos = 0
        foreach ($p in $lista) {
            $dias = [int]((Get-Date) - [datetime]$p.lastUpdated).TotalDays
            $fijado = $pluginsFijados | Where-Object { $_.Plugin -eq $p.id } | Select-Object -First 1
            if ($fijado) {
                $corto = $fijado.Commit.Substring(0, 7)
                $problemas = @()
                if ((CommitFijado $fijado) -ne $fijado.Commit) { $problemas += "no está en el commit fijado ($corto)" }
                $problemas += @(ProblemasDelFijado $fijado $p.version)
                if ($problemas.Count -eq 0) { Bien "$($p.id) · $($p.version) · fijado a propósito en $($corto): $($fijado.Motivo)" }
                else {
                    Ojo "$($p.id) (fijado): $($problemas -join ' y ')" 'La app de Claude puede estar cargando otra versión. Para fijarlo: desinstalalo (y su marketplace) y corré instalar.ps1'
                }
                continue
            }
            if ($dias -gt $diasPlugin) { $viejos++; Info "$($p.id) · $($p.version) · sin actualizar hace $dias días" }
            else { Bien "$($p.id) · $($p.version) · actualizado hace $dias días" }
        }
        if ($viejos -gt 0) {
            Ojo "$viejos plugin(s) sin actualizar hace más de $diasPlugin días" 'Para buscar versiones nuevas e instalarlas: .\revisar.ps1 -ActualizarPlugins'
        }
    }
}

# ---------------------------------- Final ----------------------------------
Remove-Item $temporal -Recurse -Force -ErrorAction SilentlyContinue
Titulo 'Resumen'
if ($pendientes.Count -eq 0) { Write-Host '  Todo al día.' -ForegroundColor Green }
else {
    Write-Host "  $($pendientes.Count) cosa(s) para mirar:" -ForegroundColor Yellow
    $pendientes | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
