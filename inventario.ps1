# Inventario de skills-del-sistema-public: lo leen instalar.ps1 y revisar.ps1.
# Para sumar o quitar algo, editar estas listas (y la tabla del README).

$marketplaces = @(
    'anthropics/claude-plugins-official',
    'pbakaus/impeccable',
    'vercel-labs/agent-browser',
    'coreyhaines31/marketingskills',
    'trailofbits/skills',
    'briiirussell/cybersecurity-skills',
    'AgriciDaniel/pya'
)

$plugins = @(
    'superpowers@claude-plugins-official',
    'frontend-design@claude-plugins-official',
    'playwright@claude-plugins-official',
    'context7@claude-plugins-official',
    'ralph-loop@claude-plugins-official',
    'remember@claude-plugins-official',
    'impeccable@impeccable',
    'agent-browser@agent-browser',
    'marketing-skills@marketingskills',
    'testing-handbook-skills@trailofbits',
    'static-analysis@trailofbits',
    'semgrep-rule-creator@trailofbits',
    'insecure-defaults@trailofbits',
    'supply-chain-risk-auditor@trailofbits',
    'cybersecurity-skills@cybersecurity-skills',
    'pya@pya'
)

# Plugins fijados en una versión vieja a propósito: se instalan desde ese commit exacto y el revisor no los
# actualiza. Para soltar uno, sacalo de acá y agregá su marketplace a $marketplaces y el plugin a $plugins.
$pluginsFijados = @(
    @{ Plugin = 'taste-skill@taste-skill'; Repo = 'leonxlnx/taste-skill'; Commit = '06d6028b5c623016c59ce8536f578e5a1127b499';
       Motivo = 'la 2.x junta todo en una sola skill y quita las de estilos concretos (brutalista, minimalista, soft, brandkit)' }
)

# Skills sueltas: se bajan de su repo original (con su licencia) y se copian a ~/.claude/skills/<Nombre>.
$skillsSueltas = @(
    @{ Nombre = 'navegador-visible'; Repo = 'martin15006/navegador-visible';   Carpeta = 'skills/navegador-visible' },
    @{ Nombre = 'pacto-skill';       Repo = 'martin15006/pacto-skill';         Carpeta = 'skills/pacto-skill' },
    @{ Nombre = 'emil-design-eng';   Repo = 'emilkowalski/skills';             Carpeta = 'skills/emil-design-eng' },
    @{ Nombre = 'review-animations'; Repo = 'emilkowalski/skills';             Carpeta = 'skills/review-animations' },
    @{ Nombre = 'security-audit';    Repo = 'cloudflare/security-audit-skill'; Carpeta = 'skills/security-audit' }
)

# Skills que viven dentro de este repo (carpeta skills/) y se copian igual a ~/.claude/skills.
$skillsDelRepo = @(
    @{ Nombre = 'captura-ventana'; Carpeta = 'skills/captura-ventana' }
)

# Bugs de terceros que estas skills esquivan. revisar.ps1 avisa cuando los cierren.
$bugsVigilados = @(
    @{ Repo = 'vercel-labs/agent-browser'; Numero = 1981; Que = 'set viewport da EOF con la ventana maximizada';
       QueHacer = 'Actualizá agent-browser (npm install -g agent-browser@latest) cuando salga la versión con el arreglo' },
    @{ Repo = 'cloudflare/security-audit-skill'; Numero = 53; Que = 'los validadores de security-audit no leen archivos en Windows';
       QueHacer = 'Corré instalar.ps1 para bajar la versión arreglada y sacá la nota de Windows de security-audit de tu CLAUDE.md' }
)
