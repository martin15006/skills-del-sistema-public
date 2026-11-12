# Selección automática de skills

Las skills se activan solas por su `description`: no hace falta nombrarlas. Cuando varias se solapan,
**elegí la mejor y avisá en UNA línea cuál y por qué** antes de arrancar (por ejemplo, *"Uso impeccable
porque es un rediseño general de UI"*). Precedencia cuando hay empate:

- **Diseño general de UI, web, componentes, landing o dashboard** → `impeccable` (la principal, la más
  completa). `frontend-design` solo como respaldo liviano si impeccable no aplica.
  - Sus hooks revisan el diseño después de cada edición de interfaz. La carpeta **`.impeccable/`** que
    crea en cada proyecto **nunca se sube**: si el proyecto no la tiene en su `.gitignore`, agregala.
- **Animación, motion, micro-interacciones, "que se sienta bien"** → `emil-design-eng`. Para
  **auditar** animaciones ya hechas → `review-animations`.
- **Un estilo concreto** (brutalista, minimalista, soft, brandkit) o **imagen → código** → `taste-skill`.
- **Cualquier cosa con pantalla** (probar una app o un servidor que levantaste, login, formularios,
  verificar un cambio de UI, abrir o buscar en una web) → **`navegador-visible`**: una ventana real de
  Chrome en el escritorio del usuario. Le gana al panel de navegador integrado, a Claude Preview y al MCP
  de Playwright, porque esos corren donde el usuario no mira. Una vez abierta la ventana, **toda** la
  prueba sigue en ella hasta el final.
- **Programas de escritorio de Windows que no son web** (captura de evidencia de VS Code, Word o la
  terminal; operar o probar paso a paso una app de escritorio) → **`captura-ventana`**. Lo web sigue en
  `navegador-visible`.
- **Trabajo con acuerdo escrito** (una funcionalidad mediana en un proyecto existente, un proyecto o una
  versión nueva, "hagamos el pacto", historias de usuario y criterios, retomar o sellar un pacto) →
  **`pacto-skill`**. En ese trabajo le gana a `writing-plans`, `executing-plans` y
  `subagent-driven-development`: las obligaciones del pacto son el plan. No se usa para cambios chicos
  ni bugs sueltos.
- **Seguridad del código propio:**
  - **Auditoría de seguridad o pentest de un repo entero**, o "¿hay vulnerabilidades reales?" →
    **`security-audit`** (Cloudflare): cada hallazgo lo intenta refutar otro agente, así que deja pocos
    falsos positivos. Perfil `quick` salvo que se pida más. En Windows sus validadores
    (`validate-*.cjs`) todavía no funcionan (issue cloudflare/security-audit-skill#53): no los
    parchees, cerrá la corrida como `incomplete`, decí por qué y mostrá igual los hallazgos verificados.
    Guardá la salida en `Escritorio\Auditorias de seguridad\<carpeta del repo>\<AAAA-MM-DD> run-<N>`
    (no en su carpeta por defecto, que queda escondida) y al terminar decí la ruta exacta.
  - **Revisión rápida con puntaje (0-100), secretos, dependencias, malware y configs de agentes o MCP**
    → **`pya`**. Windows Defender puede bloquear su `references/seeds.json` (patrones de detección con
    ejemplos de web shells): si pasa, `ioc_scan.py` falla y es esperado. Seguí sin él, decilo en el
    informe y no pidas ni crees excepciones en el antivirus.
  - **Aprender, o que explique qué encontró y por qué** → `cybersecurity-skills`.

> Si dos skills siguen empatadas, elegí la más específica para la tarea y decilo. Nunca te quedes
> trabado preguntando cuál usar.
