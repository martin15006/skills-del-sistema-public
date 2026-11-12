<#
.SYNOPSIS
    Instala en Claude Code un set de plugins y skills: diseño, navegador visible, escritorio de Windows,
    trabajo con acuerdo escrito y seguridad.

.DESCRIPTION
    - Agrega los marketplaces de terceros e instala sus plugins.
    - Baja cada skill suelta desde su repo original (con su licencia) y la copia a ~/.claude/skills.
      Si ya había una skill con ese nombre y es distinta, antes la guarda en ~/.claude/skills-respaldo.
    - Instala el CLI agent-browser (lo usa la skill navegador-visible).
    Por defecto no toca nada más de la PC. Lo demás es opcional:
    - -ConAjustes: variables de entorno, python3 para PYA y .impeccable/ en el gitignore global.
    - -ConClaudeMd: pone la plantilla de reglas como CLAUDE.md global, solo si no tenés uno.
    Se puede correr varias veces: lo que ya está instalado se saltea.
    No corre git para bajar código (usa el .zip de GitHub) y no necesita ser administrador.

.PARAMETER SoloVer
    Muestra lo que haría, sin cambiar nada.

.PARAMETER ConAjustes
    Además pone AGENT_BROWSER_HEADED=1 y DO_NOT_TRACK=1, arregla python3 si es el acceso directo de la
    Microsoft Store (PYA lo necesita) y agrega .impeccable/ al gitignore global.

.PARAMETER ConClaudeMd
    Copia claude\CLAUDE.plantilla.md a ~/.claude/CLAUDE.md si todavía no existe. Si ya tenés uno, no lo toca.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\instalar.ps1 -SoloVer
#>
param(
    [switch]$SoloVer,
    [switch]$ConAjustes,
    [switch]$ConClaudeMd
)

$ErrorActionPreference = 'Continue'

# El inventario (marketplaces, plugins y skills) vive en inventario.ps1; las funciones compartidas, en comun.ps1.
. (Join-Path $PSScriptRoot 'inventario.ps1')
. (Join-Path $PSScriptRoot 'comun.ps1')

$raiz = $PSScriptRoot
$avisos = New-Object System.Collections.Generic.List[string]

function Titulo([string]$texto) {
    Write-Host "`n== $texto ==" -ForegroundColor Cyan
}

function Hacer([string]$descripcion, [scriptblock]$accion) {
    if ($SoloVer) {
        Write-Host "  (solo ver) $descripcion" -ForegroundColor DarkGray
        return
    }
    Write-Host "  $descripcion"
    & $accion
}

function Avisar([string]$texto) {
    Write-Warning $texto
    $avisos.Add($texto)
}

# Copia una skill a ~/.claude/skills. Si ya había otra con ese nombre, antes la guarda en skills-respaldo.
$destinoSkills = Join-Path $env:USERPROFILE '.claude\skills'
$dirRespaldo = Join-Path $env:USERPROFILE '.claude\skills-respaldo'
function PonerSkill([string]$nombre, [string]$origen, [string]$deDonde, [string]$licencia) {
    $destino = Join-Path $destinoSkills $nombre
    $difs = @(Diferencias $destino $origen)
    if ($difs.Count -eq 0) {
        Write-Host "  ya estaba: $nombre (igual a $deDonde)" -ForegroundColor DarkGray
        return
    }
    $que = if (Test-Path $destino) { "reemplazar la skill $nombre ($($difs.Count) archivo(s) distintos de $deDonde; la anterior queda en $dirRespaldo)" } else { "poner la skill $nombre" }
    Hacer $que {
        New-Item -ItemType Directory -Force -Path $destinoSkills | Out-Null
        if (Test-Path $destino) {
            New-Item -ItemType Directory -Force -Path $dirRespaldo | Out-Null
            Move-Item $destino (Join-Path $dirRespaldo ($nombre + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
        }
        Copy-Item $origen $destino -Recurse
        if ($licencia) { Copy-Item $licencia (Join-Path $destino (Split-Path $licencia -Leaf)) }
    }
}

# ------------------------------ Requisitos ------------------------------
Titulo 'Requisitos'

$claude = BuscarClaude
if (-not $claude) {
    Write-Host 'No encuentro Claude Code (ni en el PATH, ni en ~/.local/bin, ni el de la app de escritorio). Instalalo primero (https://claude.com/claude-code) y volvé a correr este script.' -ForegroundColor Red
    exit 1
}
Write-Host "  Claude Code: $claude"

$faltan = @()
foreach ($herramienta in @('git', 'npm')) {
    if (-not (Get-Command $herramienta -ErrorAction SilentlyContinue)) { $faltan += $herramienta }
}
if ($faltan.Count -gt 0) {
    Write-Host ('Faltan: ' + ($faltan -join ', ') + '. Instalá Git y Node.js y volvé a correr el script.') -ForegroundColor Red
    exit 1
}
Write-Host '  git y npm: OK'

# Acá se bajan los repos (también con -SoloVer, para comparar); se borra al final.
$temporal = Join-Path $env:TEMP ('skills-del-sistema-public-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $temporal | Out-Null

# ----------------------------- Marketplaces -----------------------------
Titulo 'Marketplaces'

$listaMarket = (& $claude plugin marketplace list 2>&1 | Out-String)
foreach ($m in $marketplaces) {
    if ($listaMarket -match [regex]::Escape("($m)")) {
        Write-Host "  ya estaba: $m" -ForegroundColor DarkGray
        continue
    }
    Hacer "agregar $m" {
        & $claude plugin marketplace add $m
        if ($LASTEXITCODE -ne 0) { Avisar "No se pudo agregar el marketplace $m" }
    }
}

# ------------------------------- Plugins --------------------------------
Titulo 'Plugins'

$listaPlugins = (& $claude plugin list 2>&1 | Out-String)
foreach ($p in $plugins) {
    if ($listaPlugins -match [regex]::Escape($p)) {
        Write-Host "  ya estaba: $p" -ForegroundColor DarkGray
        continue
    }
    Hacer "instalar $p" {
        & $claude plugin install $p
        if ($LASTEXITCODE -ne 0) { Avisar "No se pudo instalar el plugin $p" }
    }
}

# --------------------------- Plugins fijados ----------------------------
Titulo 'Plugins fijados en una versión vieja'

# Se bajan de su commit exacto (el .zip de GitHub, sin git) a ~/.claude/plugins/fijados/<nombre>, se anota
# el commit en fijados/<nombre>.commit y se instalan desde ahí, con esa carpeta como catálogo. Si el catálogo
# apuntara a GitHub, la app de Claude lo refrescaría al arrancar y cargaría la versión nueva.
# Si ya lo tenés instalado de otra forma, no se toca: solo se avisa.
foreach ($f in $pluginsFijados) {
    $nombre, $market = $f.Plugin.Split('@')
    $destino = Join-Path $dirFijados $nombre
    $actual = CommitFijado $f
    if ($actual -eq $f.Commit -and (CatalogoFijadoLocal $f)) {
        Write-Host "  ya estaba: $($f.Plugin) en $($f.Commit.Substring(0, 7))" -ForegroundColor DarkGray
        continue
    }
    if ($actual -or ($listaPlugins -match [regex]::Escape($f.Plugin))) {
        Avisar "Ya tenés $($f.Plugin) en otra versión: no lo toco. Este kit lo fija en $($f.Commit.Substring(0, 7)) porque $($f.Motivo). Si lo querés así, desinstalalo (claude plugin uninstall $($f.Plugin) y claude plugin marketplace remove $market) y volvé a correr este script."
        continue
    }
    Hacer "instalar $($f.Plugin) fijado en $($f.Commit.Substring(0, 7)) ($($f.Motivo))" {
        $bajado = BajarDeGitHub $f.Repo $f.Commit (Join-Path $temporal ($f.Repo -replace '/', '__'))
        if (-not $bajado) { Avisar "No se pudo bajar $($f.Repo) en el commit $($f.Commit)"; return }
        if (Test-Path $destino) { Remove-Item $destino -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $dirFijados | Out-Null
        Move-Item $bajado $destino
        Set-Content -Path (Join-Path $dirFijados "$nombre.commit") -Value $f.Commit -Encoding ascii
        & $claude plugin marketplace add $destino
        & $claude plugin install $f.Plugin
        if ($LASTEXITCODE -ne 0) { Avisar "No se pudo instalar el plugin fijado $($f.Plugin)"; return }
        # Sacar del caché las otras versiones que la app pudo haber bajado, para que no cargue ninguna
        $versionFijada = (Get-Content (Join-Path $destino '.claude-plugin\marketplace.json') -Raw -Encoding utf8 |
            ConvertFrom-Json).plugins | Where-Object { $_.name -eq $nombre } | Select-Object -ExpandProperty version -First 1
        $cache = Join-Path $env:USERPROFILE ".claude\plugins\cache\$market\$nombre"
        if ($versionFijada) {
            Get-ChildItem $cache -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $versionFijada } |
                ForEach-Object { Remove-Item $_.FullName -Recurse -Force; Write-Host "  saqué del caché $($f.Plugin) $($_.Name)" }
        }
    }
}

# ---------------------------- Skills sueltas ----------------------------
Titulo 'Skills sueltas (de su repo original)'

# Cada repo se baja siempre (también con -SoloVer) para comparar: solo se reemplaza la skill que difiere.
foreach ($grupo in ($skillsSueltas | Group-Object { $_.Repo })) {
    $repo = $grupo.Name
    $clon = BajarDeGitHub $repo 'HEAD' (Join-Path $temporal ($repo -replace '/', '__'))
    if (-not $clon) {
        Avisar "No se pudo bajar $repo. Se saltean sus skills."
        continue
    }
    $licencia = Get-ChildItem $clon -File | Where-Object { $_.Name -match '^LICEN[CS]E' } | Select-Object -First 1
    foreach ($s in $grupo.Group) {
        $origen = Join-Path $clon $s.Carpeta
        if (-not (Test-Path $origen)) {
            Avisar "No encontré $($s.Carpeta) en $repo"
            continue
        }
        PonerSkill $s.Nombre $origen $repo $(if ($licencia) { $licencia.FullName } else { $null })
    }
}

# --------------------- Skills que viven en este repo --------------------
Titulo 'Skills de este repo'

foreach ($s in $skillsDelRepo) {
    $origen = Join-Path $raiz ($s.Carpeta -replace '/', '\')
    if (-not (Test-Path $origen)) {
        Avisar "No encontré $($s.Carpeta) en este repo"
        continue
    }
    PonerSkill $s.Nombre $origen 'este repo' (Join-Path $raiz 'LICENSE')
}

# ---------------------------- agent-browser -----------------------------
Titulo 'agent-browser (el navegador de navegador-visible)'

if (BuscarAgentBrowser) {
    Write-Host '  ya estaba instalado' -ForegroundColor DarkGray
} else {
    Hacer 'npm install -g agent-browser' {
        npm install -g agent-browser
        if ($LASTEXITCODE -ne 0) { Avisar 'No se pudo instalar agent-browser' }
    }
}

# ------------------------- Ajustes (opcionales) -------------------------
$py3 = Get-Command python3 -ErrorAction SilentlyContinue
$py = Get-Command python -ErrorAction SilentlyContinue
$py3EsStore = (-not $py3) -or ($py3.Source -match 'WindowsApps')

if (-not $ConAjustes) {
    Titulo 'Ajustes (salteados: se ponen con -ConAjustes)'
    Write-Host '  -ConAjustes pondría AGENT_BROWSER_HEADED=1 y DO_NOT_TRACK=1, python3 para PYA y .impeccable/ en el gitignore global.' -ForegroundColor DarkGray
    if ($py3EsStore) { Avisar 'python3 es el acceso directo de la Microsoft Store (o no existe) y PYA lo necesita. Corré con -ConAjustes para arreglarlo, o instalá Python 3 desde python.org.' }
} else {
    Titulo 'Ajustes'

    # Variable de usuario: se pone solo si no tiene ya ese valor.
    function PonerVariable([string]$nombre, [string]$valor, [string]$para) {
        if ([Environment]::GetEnvironmentVariable($nombre, 'User') -eq $valor) {
            Write-Host "  ya estaba: $nombre=$valor" -ForegroundColor DarkGray
            return
        }
        Hacer "$nombre=$valor ($para)" {
            [Environment]::SetEnvironmentVariable($nombre, $valor, 'User')
        }
    }

    PonerVariable 'AGENT_BROWSER_HEADED' '1' 'las ventanas de agent-browser se ven'
    PonerVariable 'DO_NOT_TRACK' '1' 'sin avisos de uso de impeccable y otras herramientas'

    # En Windows, 'python3' suele ser el acceso directo de la Microsoft Store, que no hace nada. PYA lo
    # necesita: si pasa eso y hay un Python de verdad, se crea python3.exe al lado de python.exe. Si esa
    # carpeta no deja escribir (Python instalado para todos y usuario sin admin), se crea en cambio el
    # atajo ~/bin/python3 para Git Bash, que es donde Claude Code corre los comandos de PYA.
    function SePuedeEscribir([string]$carpeta) {
        $prueba = Join-Path $carpeta ('.prueba-' + [guid]::NewGuid().ToString('N'))
        try { [IO.File]::Create($prueba).Dispose(); Remove-Item $prueba -Force; return $true } catch { return $false }
    }

    $atajo = Join-Path $env:USERPROFILE 'bin\python3'
    # A dónde apunta el atajo, pasado de ruta de Git Bash (/c/...) a ruta de Windows (C:\...).
    $destinoAtajo = $null
    if ((Test-Path $atajo) -and ((Get-Content $atajo -Raw) -match 'exec "/([a-zA-Z])(/[^"]+)"')) {
        $destinoAtajo = $Matches[1].ToUpper() + ':' + $Matches[2].Replace('/', '\')
    }
    if (-not $py3EsStore -and $py3.Source -ne $atajo) {
        Write-Host "  ya estaba: python3 ($($py3.Source))" -ForegroundColor DarkGray
    } elseif ($destinoAtajo -and (Test-Path $destinoAtajo)) {
        Write-Host "  ya estaba: python3 (atajo de Git Bash $atajo, apunta a $destinoAtajo)" -ForegroundColor DarkGray
    } elseif (-not $py -or $py.Source -match 'WindowsApps') {
        Avisar 'No hay un Python instalado (python y python3 son los accesos directos de la Store). Instalá Python 3 desde python.org; PYA lo necesita.'
    } elseif (-not (Test-Path $atajo) -and (SePuedeEscribir (Split-Path $py.Source))) {
        $py3Nuevo = Join-Path (Split-Path $py.Source) 'python3.exe'
        Hacer "crear $py3Nuevo (copia de python.exe)" {
            if (-not (Test-Path $py3Nuevo)) { Copy-Item $py.Source $py3Nuevo }
        }
    } else {
        $motivo = if (Test-Path $atajo) { 'el que había apunta a un Python que ya no está' } else { "$(Split-Path $py.Source) no deja escribir sin admin" }
        Hacer "crear el atajo $atajo para Git Bash, que apunta a $($py.Source) ($motivo)" {
            $rutaBash = '/' + $py.Source.Substring(0, 1).ToLower() + $py.Source.Substring(2).Replace('\', '/')
            $lineas = @(
                '#!/bin/sh',
                '# python3 para Git Bash (PYA corre sus scripts con "python3 -I ..."). Lo creo instalar.ps1 de',
                '# skills-del-sistema-public porque la carpeta de Python no deja escribir sin ser administrador.',
                '# Si se cambia de Python, volver a correr instalar.ps1 -ConAjustes.',
                "exec `"$rutaBash`" `"`$@`""
            )
            New-Item -ItemType Directory -Force -Path (Split-Path $atajo) | Out-Null
            # Sin BOM y con saltos LF: si no, bash no entiende la primera línea.
            [IO.File]::WriteAllText($atajo, ($lineas -join "`n") + "`n", (New-Object Text.UTF8Encoding $false))
        }
    }

    # La carpeta .impeccable/ que crea impeccable en cada proyecto no debería subirse: gitignore global.
    $ignoreGlobal = Join-Path $env:USERPROFILE '.config\git\ignore'
    $yaEsta = (Test-Path $ignoreGlobal) -and ((Get-Content $ignoreGlobal -ErrorAction SilentlyContinue) -contains '.impeccable/')
    if ($yaEsta) {
        Write-Host '  ya estaba: .impeccable/ en el gitignore global' -ForegroundColor DarkGray
    } else {
        Hacer ".impeccable/ en el gitignore global ($ignoreGlobal)" {
            New-Item -ItemType Directory -Force -Path (Split-Path $ignoreGlobal) | Out-Null
            Add-Content -Path $ignoreGlobal -Value '.impeccable/' -Encoding utf8
        }
    }
}

# ------------------------------ CLAUDE.md -------------------------------
$plantilla = Join-Path $raiz 'claude\CLAUDE.plantilla.md'
$destinoMd = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
if (-not $ConClaudeMd) {
    Titulo 'CLAUDE.md (salteado: se pone con -ConClaudeMd)'
    Write-Host "  Las reglas de qué skill usar en cada caso están en $plantilla" -ForegroundColor DarkGray
} else {
    Titulo 'CLAUDE.md'
    if (-not (Test-Path $plantilla)) {
        Avisar "No encontré $plantilla"
    } elseif ((Test-Path $destinoMd) -and ((HuellaArchivo $plantilla) -eq (HuellaArchivo $destinoMd))) {
        Write-Host '  ya estaba: igual a la plantilla' -ForegroundColor DarkGray
    } elseif (Test-Path $destinoMd) {
        Avisar "Ya tenés un CLAUDE.md ($destinoMd): no lo toco. Si querés las reglas, copiá a mano lo que te sirva de $plantilla."
    } else {
        Hacer "copiar la plantilla a $destinoMd" {
            New-Item -ItemType Directory -Force -Path (Split-Path $destinoMd) | Out-Null
            Copy-Item $plantilla $destinoMd
        }
    }
}

# -------------------------------- Final ---------------------------------
Remove-Item $temporal -Recurse -Force -ErrorAction SilentlyContinue

Titulo 'Listo'
if ($avisos.Count -gt 0) {
    Write-Host "Terminó con $($avisos.Count) aviso(s):" -ForegroundColor Yellow
    $avisos | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} elseif ($SoloVer) {
    Write-Host 'Eso es lo que haría. Para instalar de verdad, correlo sin -SoloVer.'
} else {
    Write-Host 'Todo instalado.' -ForegroundColor Green
}
Write-Host ''
Write-Host 'Después:'
Write-Host '  1. Reiniciá Claude Code para que cargue los plugins y las skills.'
Write-Host '  2. Si Windows Defender bloquea un archivo de PYA (seeds.json, patrones de detección), es esperado: PYA sigue funcionando.'
