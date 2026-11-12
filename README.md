# Skills del Sistema (edición pública)

Un set de **plugins y skills para Claude Code en Windows**, listo para instalar con un solo script:
diseño de interfaces, pruebas en una ventana de navegador que ves en vivo, manejo de programas de
escritorio, trabajo con acuerdo escrito y seguridad.

Es el mismo setup que uso todos los días, sin mis datos personales.

## Qué instala

### Skills propias

| Skill | Qué hace | Repo |
|---|---|---|
| `navegador-visible` | Prueba todo lo que tenga pantalla en una ventana real de Chrome que ves en tu escritorio, narrando cada paso y pidiendo confirmación antes de lo irreversible | [martin15006/navegador-visible](https://github.com/martin15006/navegador-visible) |
| `pacto-skill` | Acordar por escrito qué se construye, construirlo en tandas y cerrarlo probando criterio por criterio que se cumplió | [martin15006/pacto-skill](https://github.com/martin15006/pacto-skill) |
| `captura-ventana` | Manejar programas de escritorio de Windows (teclado, mouse, diálogos) y capturarlos en PNG | En este repo: [`skills/captura-ventana`](skills/captura-ventana) |

### Plugins de terceros (17, de 8 marketplaces)

| Plugin | Marketplace | Para qué |
|---|---|---|
| `superpowers` | claude-plugins-official | Planificación, debugging sistemático, TDD, revisión de código |
| `frontend-design` | claude-plugins-official | Diseño de interfaces (respaldo liviano) |
| `playwright` | claude-plugins-official | Automatizar navegadores con Playwright |
| `context7` | claude-plugins-official | Documentación actualizada de librerías |
| `ralph-loop` | claude-plugins-official | Bucles de trabajo autónomo |
| `remember` | claude-plugins-official | Memoria entre sesiones |
| `impeccable` | impeccable | Diseño de UI (el principal) |
| `taste-skill` | taste-skill | Estilos concretos e imagen → código. **Fijado en la 1.0** (ver abajo) |
| `agent-browser` | agent-browser | Automatizar el navegador |
| `marketing-skills` | marketingskills | Copy, SEO y presentación |
| `testing-handbook-skills` | trailofbits | Handbook de testing de seguridad |
| `static-analysis` | trailofbits | CodeQL, Semgrep y SARIF |
| `semgrep-rule-creator` | trailofbits | Escribir reglas de detección |
| `insecure-defaults` | trailofbits | Credenciales y configuraciones inseguras |
| `supply-chain-risk-auditor` | trailofbits | Riesgo de dependencias |
| `cybersecurity-skills` | cybersecurity-skills | Playbooks de seguridad que explican lo que encuentran |
| `pya` | pya | Revisión de seguridad rápida con puntaje (0-100) |

### Skills de terceros sueltas

Se bajan de su repo original y se copian con su licencia.

| Skill | Repo original | Para qué |
|---|---|---|
| `emil-design-eng` | [emilkowalski/skills](https://github.com/emilkowalski/skills) | Animación y detalles de interfaz |
| `review-animations` | [emilkowalski/skills](https://github.com/emilkowalski/skills) | Auditar animaciones ya hechas |
| `security-audit` | [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) | Auditoría profunda: otro agente intenta refutar cada hallazgo |

Además instala el CLI [`agent-browser`](https://github.com/vercel-labs/agent-browser) con npm, que es
el que maneja la ventana de `navegador-visible`.

## Requisitos

- Windows 10 u 11.
- [Claude Code](https://claude.com/claude-code) (alcanza con la app de escritorio).
- Git, Node.js (con npm) y Google Chrome.
- Python 3, para `pya`.

No hace falta ser administrador.

## Instalar

1. Clonar el repo:

   ```bash
   git clone https://github.com/martin15006/skills-del-sistema-public.git
   ```

2. Entrar a la carpeta y ver primero qué va a hacer, sin cambiar nada:

   ```powershell
   cd skills-del-sistema-public
   powershell -ExecutionPolicy Bypass -File .\instalar.ps1 -SoloVer
   ```

3. Instalar de verdad:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\instalar.ps1
   ```

4. Reiniciar Claude Code.

| Opción | Qué hace |
|---|---|
| `-SoloVer` | Muestra lo que haría, sin tocar nada |
| `-ConAjustes` | Además pone `AGENT_BROWSER_HEADED=1` y `DO_NOT_TRACK=1`, arregla `python3` si es el acceso directo de la Microsoft Store y agrega `.impeccable/` al gitignore global |
| `-ConClaudeMd` | Pone las reglas de qué skill usar en cada caso como tu CLAUDE.md global, **solo si no tenés uno** |

Se puede correr varias veces: lo que ya está instalado se saltea (dice `ya estaba`).

## Qué toca en tu PC (y qué no)

**Sin opciones**, el script solo:

- agrega los marketplaces e instala los plugins de la tabla;
- copia las skills a `~/.claude/skills`. Si ya tenías una skill con el mismo nombre y es distinta,
  antes la guarda en `~/.claude/skills-respaldo`;
- instala `agent-browser` con `npm install -g`;
- baja `taste-skill` 1.0 a `~/.claude/plugins/fijados`.

**No toca** tu CLAUDE.md, tus variables de entorno, tu Python ni tu configuración de git, salvo que se
lo pidas con `-ConAjustes` o `-ConClaudeMd`. Tampoco desinstala ningún plugin tuyo: si ya tenés
`taste-skill` en otra versión, lo deja como está y te avisa.

## Las reglas de qué skill usar (CLAUDE.md)

Varias de estas skills se pisan entre sí (por ejemplo, `impeccable` y `frontend-design`). En
[`claude/CLAUDE.plantilla.md`](claude/CLAUDE.plantilla.md) está la regla de cuál le gana a cuál.
Con `-ConClaudeMd` se instala como tu CLAUDE.md global si no tenés uno. Si ya tenés, copiá a mano la
parte que te sirva.

## Revisar si hay que actualizar algo

```powershell
powershell -ExecutionPolicy Bypass -File .\revisar.ps1
```

Solo mira, no cambia nada. Dice:

- si hay una versión nueva de este repo en GitHub;
- si las skills instaladas son iguales a las de su repo original;
- si hay versión nueva de agent-browser, y si ya cerraron los bugs que esquivan las skills;
- cuándo se actualizó cada plugin, y si `taste-skill` sigue fijado.

Para además buscar e instalar versiones nuevas de los plugins:

```powershell
powershell -ExecutionPolicy Bypass -File .\revisar.ps1 -ActualizarPlugins
```

> **Ojo:** una actualización de un plugin o una skill de terceros trae código nuevo. Si alguno salta
> de versión grande, mirá qué cambió en su repo antes de seguir usándolo.

## taste-skill, fijado en la 1.0

La 2.x de `taste-skill` junta todo en una sola skill y quita las de estilos concretos (brutalista,
minimalista, soft, brandkit). Por eso se instala desde un commit exacto de la 1.0, y su catálogo es esa
copia local: si apuntara a GitHub, la app de Claude lo refrescaría al arrancar y cargaría la versión
nueva.

**Para usar la última:** desinstalalo (`claude plugin uninstall taste-skill@taste-skill` y
`claude plugin marketplace remove taste-skill`), sacalo de `$pluginsFijados` en `inventario.ps1` y
agregá `leonxlnx/taste-skill` a `$marketplaces` y `taste-skill@taste-skill` a `$plugins`.

## Notas de Windows

- **PYA:** Windows Defender puede bloquear su `seeds.json` (patrones de detección con ejemplos de web
  shells). Es esperado: PYA sigue funcionando sin ese buscador. No hace falta crear excepciones.
- **security-audit:** sus validadores todavía no funcionan en Windows
  ([issue #53](https://github.com/cloudflare/security-audit-skill/issues/53)). La auditoría corre igual;
  `revisar.ps1` avisa cuando lo arreglen.
- **agent-browser:** con la ventana maximizada, `set viewport` responde un error aunque el tamaño se
  aplica ([issue #1981](https://github.com/vercel-labs/agent-browser/issues/1981)). `navegador-visible`
  ya lo esquiva.

## Archivos

| Archivo | Qué es |
|---|---|
| `instalar.ps1` | Instala todo |
| `revisar.ps1` | Revisa qué hay que actualizar, sin cambiar nada |
| `inventario.ps1` | La lista de marketplaces, plugins y skills: para sumar o quitar algo, se edita acá |
| `comun.ps1` | Funciones que comparten los dos scripts (buscar Claude Code, bajar de GitHub sin git, comparar carpetas) |
| `claude/CLAUDE.plantilla.md` | Las reglas de qué skill usar en cada caso |
| `skills/captura-ventana` | La skill `captura-ventana` |

## Licencia y créditos

Los scripts de este repo y `captura-ventana` son de **Juan Sebastián Martín Moncada**, con licencia
[MIT](LICENSE).

Los plugins y las skills de terceros **no están copiados acá**: el script los baja de sus repos
originales, y cada uno conserva su propia licencia y sus autores (ver los enlaces de las tablas).
