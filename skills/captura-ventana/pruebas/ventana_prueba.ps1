# Ventana de prueba para la skill captura-ventana.
# Registra cada evento (clics, texto, rueda, arrastre) en -Registro y publica en
# -Posiciones (JSON) su handle y el centro de cada control en pixeles de pantalla,
# para que probar_skill.ps1 sepa donde hacer clic con cualquier escala de Windows.
param(
    [Parameter(Mandatory = $true)][string]$Registro,
    [Parameter(Mandatory = $true)][string]$Posiciones
)

# Pixeles reales: asi los controles y las coordenadas coinciden con las capturas
Add-Type -Namespace PruebaCaptura -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][PruebaCaptura.Dpi]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function L([string]$m) { Add-Content -Path $Registro -Value $m -Encoding UTF8 }
Set-Content -Path $Registro -Value "inicio" -Encoding UTF8

function Centro($c) {
    $p = $c.PointToScreen((New-Object Drawing.Point ([int]($c.Width / 2)), ([int]($c.Height / 2))))
    return @{ X = $p.X; Y = $p.Y }
}

$f = New-Object Windows.Forms.Form
$f.Text = "Prueba captura-ventana - Principal"
$f.AutoScaleMode = "Dpi"
$f.Size = New-Object Drawing.Size 720, 480
$f.StartPosition = "Manual"; $f.Location = New-Object Drawing.Point 120, 80

$tb = New-Object Windows.Forms.TextBox
$tb.Location = New-Object Drawing.Point 20, 20; $tb.Size = New-Object Drawing.Size 300, 25
$f.Controls.Add($tb)

$b1 = New-Object Windows.Forms.Button
$b1.Text = "Boton 1"; $b1.Location = New-Object Drawing.Point 20, 60; $b1.Size = New-Object Drawing.Size 150, 40
$b1.Add_Click({ L "clic Boton 1; texto=$($tb.Text)" })
$f.Controls.Add($b1)

$zona = New-Object Windows.Forms.Panel
$zona.BackColor = [Drawing.Color]::LightBlue
$zona.Location = New-Object Drawing.Point 20, 120; $zona.Size = New-Object Drawing.Size 300, 100
$zona.Add_MouseDown({ L "zona mousedown $($_.Button)" })
$zona.Add_MouseDoubleClick({ L "zona doble clic" })
$f.Controls.Add($zona)

$arr = New-Object Windows.Forms.Panel
$arr.BackColor = [Drawing.Color]::LightGreen
$arr.Location = New-Object Drawing.Point 20, 240; $arr.Size = New-Object Drawing.Size 300, 80
$script:inicioArrastre = $null
$arr.Add_MouseDown({ $script:inicioArrastre = $_.Location })
$arr.Add_MouseUp({ L ("arrastre de {0},{1} a {2},{3}" -f $script:inicioArrastre.X, $script:inicioArrastre.Y, $_.X, $_.Y) })
$f.Controls.Add($arr)

$lb = New-Object Windows.Forms.ListBox
$lb.Location = New-Object Drawing.Point 360, 20; $lb.Size = New-Object Drawing.Size 300, 200
1..100 | ForEach-Object { [void]$lb.Items.Add("Elemento $_") }
$lb.Add_MouseWheel({ L "rueda delta=$($_.Delta)" })
$f.Controls.Add($lb)

$b2 = New-Object Windows.Forms.Button
$b2.Text = "Abrir secundaria"; $b2.Location = New-Object Drawing.Point 360, 240; $b2.Size = New-Object Drawing.Size 150, 40
$b2.Add_Click({
    L "abre secundaria"
    $s = New-Object Windows.Forms.Form
    $s.Text = "Prueba captura-ventana - Secundaria"
    $s.AutoScaleMode = "Dpi"
    $s.Size = New-Object Drawing.Size 380, 220
    $s.StartPosition = "Manual"; $s.Location = New-Object Drawing.Point 500, 300
    $bc = New-Object Windows.Forms.Button
    $bc.Text = "Cerrar secundaria"; $bc.Location = New-Object Drawing.Point 20, 20; $bc.Size = New-Object Drawing.Size 180, 40
    $bc.Add_Click({ L "clic Cerrar secundaria"; $this.FindForm().Close() })
    $s.Controls.Add($bc)
    $s.Add_Shown({
        # $s y $bc ya no existen cuando se dispara este evento: se usa $this
        $datos = @{ handle = $this.Handle.ToInt64(); cerrar = (Centro $this.Controls[0]) }
        Set-Content -Path ($Posiciones -replace '\.json$', '_secundaria.json') -Value ($datos | ConvertTo-Json) -Encoding UTF8
    })
    $s.Show($f)
})
$f.Controls.Add($b2)

# Abre, al rato, otra ventana principal del mismo proceso (sin duena) y le da el foco:
# simula otro documento del mismo programa. No deberia recibir el texto destinado a la principal.
$b3 = New-Object Windows.Forms.Button
$b3.Text = "Otra principal"; $b3.Location = New-Object Drawing.Point 360, 300; $b3.Size = New-Object Drawing.Size 150, 40
$b3.Add_Click({
    L "pide otra principal"
    $t = New-Object Windows.Forms.Timer
    $t.Interval = 700
    $t.Add_Tick({
        $this.Stop()
        $o = New-Object Windows.Forms.Form
        $o.Text = "Prueba captura-ventana - Otra principal"
        $o.AutoScaleMode = "Dpi"
        $o.StartPosition = "Manual"; $o.Location = New-Object Drawing.Point 200, 200; $o.Size = New-Object Drawing.Size 380, 160
        $ot = New-Object Windows.Forms.TextBox
        $ot.Location = New-Object Drawing.Point 20, 20; $ot.Size = New-Object Drawing.Size 300, 25
        $ot.Add_TextChanged({ L "otra principal recibio: $($this.Text)" })
        $o.Controls.Add($ot)
        $o.Show()
        $o.Activate()
    })
    $t.Start()
})
$f.Controls.Add($b3)

$f.Add_Shown({
    $r = $arr.RectangleToScreen($arr.ClientRectangle)
    $datos = @{
        handle = $f.Handle.ToInt64()
        texto = Centro $tb; boton1 = Centro $b1; zona = Centro $zona; lista = Centro $lb; abrir = Centro $b2; otra = Centro $b3
        arrastreInicio = @{ X = $r.Left + 30; Y = $r.Top + [int]($r.Height / 2) }
        arrastreFin = @{ X = $r.Right - 30; Y = $r.Top + [int]($r.Height / 2) }
    }
    Set-Content -Path $Posiciones -Value ($datos | ConvertTo-Json) -Encoding UTF8
})
$f.Add_FormClosed({ L "cerrada; primer elemento visible=$($lb.TopIndex)" })
[Windows.Forms.Application]::Run($f)
