# Funciones que comparten instalar.ps1 y revisar.ps1.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dirFijados = Join-Path $env:USERPROFILE '.claude\plugins\fijados'

# Claude Code: el del PATH, el del instalador (~/.local/bin) o el que trae la app de escritorio, que vive en
# %APPDATA%\Claude\claude-code\<versión>\<hash>\claude.exe y cambia de carpeta con cada actualización.
function BuscarClaude {
    $enPath = Get-Command claude -ErrorAction SilentlyContinue
    if ($enPath) { return $enPath.Source }
    $local = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path $local) { return $local }
    $deLaApp = Join-Path $env:APPDATA 'Claude\claude-code'
    if (-not (Test-Path $deLaApp)) { return $null }
    $versiones = Get-ChildItem $deLaApp -Directory | Where-Object { $_.Name -as [version] } | Sort-Object { [version]$_.Name } -Descending
    foreach ($v in $versiones) {
        $exe = Get-ChildItem $v.FullName -Directory | Sort-Object LastWriteTime -Descending |
            ForEach-Object { Join-Path $_.FullName 'claude.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($exe) { return $exe }
    }
    return $null
}

# agent-browser instalado de verdad. Dentro de una sesión de Claude Code el PATH trae también el
# bin\agent-browser.js del plugin, que no sirve como comando: Windows abre los .js con Windows Script Host, no con Node.
function BuscarAgentBrowser {
    Get-Command agent-browser -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch '\.js$' } | Select-Object -First 1
}

# Baja un repo de GitHub en un commit (o HEAD, la rama principal) sin usar git: el .zip de codeload.github.com.
# Devuelve la carpeta con el contenido, o $null si no se pudo (por ejemplo, si el repo no existe o es privado).
function BajarDeGitHub([string]$repo, [string]$ref, [string]$carpeta) {
    $zip = $carpeta + '.zip'
    $progreso = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'   # con la barra de progreso, Invoke-WebRequest tarda muchísimo
    try {
        Invoke-WebRequest "https://codeload.github.com/$repo/zip/$ref" -OutFile $zip -UseBasicParsing -TimeoutSec 120
        if (Test-Path $carpeta) { Remove-Item $carpeta -Recurse -Force }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $carpeta)
    } catch {
        return $null
    } finally {
        $ProgressPreference = $progreso
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }
    # El .zip trae todo dentro de una carpeta <repo>-<ref>.
    return (Get-ChildItem $carpeta -Directory | Select-Object -First 1).FullName
}

# Huella de un archivo que no cambia por los saltos de línea (CRLF/LF) ni por el BOM.
function HuellaArchivo([string]$ruta) {
    $texto = [IO.File]::ReadAllText($ruta).Replace("`r", '')
    $sha = [Security.Cryptography.SHA256]::Create()
    return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($texto)))
}

function Huellas([string]$carpeta) {
    $tabla = @{}
    if (-not (Test-Path $carpeta)) { return $tabla }
    $base = (Resolve-Path $carpeta).Path.TrimEnd('\')
    Get-ChildItem $base -Recurse -File -Force |
        Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.Name -notmatch '^LICEN[CS]E' } |
        ForEach-Object { $tabla[$_.FullName.Substring($base.Length + 1).Replace('\', '/')] = HuellaArchivo $_.FullName }
    return $tabla
}

# Lista de diferencias entre la carpeta local y la de referencia: ~ distinto, + solo acá, - solo allá.
function Diferencias([string]$local, [string]$referencia) {
    $a = Huellas $local
    $b = Huellas $referencia
    $difs = @()
    foreach ($k in (@($a.Keys) + @($b.Keys) | Sort-Object -Unique)) {
        if (-not $b.ContainsKey($k)) { $difs += "+ $k" }
        elseif (-not $a.ContainsKey($k)) { $difs += "- $k" }
        elseif ($a[$k] -ne $b[$k]) { $difs += "~ $k" }
    }
    return $difs
}

# Commit en el que está instalado un plugin fijado, o $null si no está instalado. Si su carpeta tiene .git,
# Claude Code lo anota en installed_plugins.json (gitCommitSha); si se bajó como .zip, sale de la marca
# fijados\<nombre>.commit que deja instalar.ps1, siempre que el marketplace del plugin sea esa carpeta.
function CommitFijado([hashtable]$f) {
    $nombre, $market = $f.Plugin.Split('@')
    $base = Join-Path $env:USERPROFILE '.claude\plugins'
    try {
        $instalados = (Get-Content (Join-Path $base 'installed_plugins.json') -Raw -Encoding utf8 | ConvertFrom-Json).plugins
        $mercados = Get-Content (Join-Path $base 'known_marketplaces.json') -Raw -Encoding utf8 | ConvertFrom-Json
    } catch { return $null }
    if (-not $instalados.PSObject.Properties[$f.Plugin]) { return $null }
    $sha = @($instalados.($f.Plugin))[0].gitCommitSha
    if ($sha) { return $sha }
    $carpeta = Join-Path $dirFijados $nombre
    $marca = Join-Path $dirFijados "$nombre.commit"
    $enFijados = $mercados.PSObject.Properties[$market] -and ($mercados.$market.installLocation -eq $carpeta)
    if ($enFijados -and (Test-Path $carpeta) -and (Test-Path $marca)) { return (Get-Content $marca -Raw).Trim() }
    return $null
}

# Si el catálogo de un plugin fijado es su copia local (fijados\<nombre>). Con el commit correcto no alcanza:
# si el catálogo apunta a GitHub, la app de Claude lo refresca al arrancar, baja la versión nueva al caché y la
# carga aunque la instalada siga siendo la vieja (pasó con taste-skill el 2026-10-30).
function CatalogoFijadoLocal([hashtable]$f) {
    $nombre, $market = $f.Plugin.Split('@')
    try {
        $mercados = Get-Content (Join-Path $env:USERPROFILE '.claude\plugins\known_marketplaces.json') -Raw -Encoding utf8 | ConvertFrom-Json
    } catch { return $false }
    if (-not $mercados.PSObject.Properties[$market]) { return $false }
    $fuente = $mercados.$market.source
    if (-not $fuente -or $fuente.source -ne 'directory' -or -not $fuente.path) { return $false }
    $carpeta = [IO.Path]::GetFullPath((Join-Path $dirFijados $nombre)).TrimEnd('\')
    return ([IO.Path]::GetFullPath($fuente.path).TrimEnd('\') -ieq $carpeta)
}
