# Cuadrilla

**Un orquestador tipo tech lead y una cuadrilla de subagentes especialistas para [OpenCode](https://opencode.ai)** — compatible con OpenCode 1.x y 2.x.

Un orquestador que clasifica, planifica, delega y verifica, y ocho especialistas que ejecutan dentro de permisos estrictos. Los prompts están en inglés (mayor alcance y compatibilidad entre modelos), pero **Cuadrilla responde en el idioma en que le escribas**.

[English](README.md)

## Instalación

Requiere [OpenCode](https://opencode.ai) 1.x o 2.x y `git`. Usa la sección de **tu shell**: el comando de Linux no funciona en PowerShell (ahí `curl` es un alias de `Invoke-WebRequest`).

| | Linux · macOS · WSL · Git Bash | Windows (PowerShell 5.1 o 7) |
|---|---|---|
| Instalador | `install.sh` | `install.ps1` |
| Instalación global | enlaces simbólicos | copia |
| Agentes en | `~/.config/opencode/` | `%USERPROFILE%\.config\opencode\` |
| Clon en | `~/.local/share/cuadrilla` | `%LOCALAPPDATA%\cuadrilla` |
| Comando `cuadrilla` | enlazado en `~/.local/bin` | la carpeta `bin\` del clon se agrega a tu PATH de usuario |
| Actualizar | `cuadrilla update` | `cuadrilla update` |

### Linux / macOS

**Global — todos tus proyectos:**

```bash
curl -fsSL https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.sh | bash
```

**Fijar una versión** (recomendado para equipos y setups reproducibles; versiones en [Releases](https://github.com/Remy349/cuadrilla/releases)):

```bash
curl -fsSL https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.sh | CUADRILLA_REF=v0.1.1 bash
```

**Por proyecto** (se copia a `.opencode/` para commitearlo con el equipo):

```bash
git clone https://github.com/Remy349/cuadrilla.git && cd cuadrilla
./install.sh --project /ruta/a/tu/repo
```

**Desinstalar:** `cuadrilla uninstall [--project <dir>]` (o `./install.sh --uninstall [--project <dir>]`)

### Windows (PowerShell)

**Global — todos tus proyectos:**

```powershell
irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
```

**Fijar una versión:**

```powershell
$env:CUADRILLA_REF = "v0.1.1"; irm https://raw.githubusercontent.com/Remy349/cuadrilla/main/install.ps1 | iex
```

**Por proyecto:**

```powershell
git clone https://github.com/Remy349/cuadrilla.git; cd cuadrilla
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Project C:\ruta\a\tu\repo
```

**Desinstalar:** `cuadrilla uninstall [--project <dir>]` (o `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall [-Project <dir>]`). Con `-NoPath` el instalador no modifica tu PATH.

<details>
<summary>Problemas comunes en Windows</summary>

- **`No se encuentra ningún parámetro que coincida con el nombre del parámetro 'fsSL'`**: ejecutaste el comando de Linux en PowerShell. Usa el comando de PowerShell de arriba (o el de Linux desde Git Bash).
- **`git is required`**: instala Git (`winget install Git.Git`) y abre una terminal nueva.
- **`la ejecución de scripts está deshabilitada en este sistema`**: solo afecta a `.\install.ps1` desde un clon; usa `powershell -ExecutionPolicy Bypass -File .\install.ps1`. `irm | iex` y el comando `cuadrilla` no se ven afectados.
- **`cuadrilla` no se reconoce después de instalar**: abre una terminal nueva (el PATH de usuario se lee al abrirla).
- **La red corporativa bloquea `raw.githubusercontent.com`**: clona el repo (o descarga el ZIP) y ejecuta `install.ps1` desde ahí; usa los archivos locales y no necesita red.

</details>

### Actualizar

```bash
cuadrilla update                    # última versión
cuadrilla update --ref <tag>        # una versión concreta (o una rama: --ref main)
cuadrilla update --project <dir>    # refresca una instalación por proyecto (<dir>/.opencode) en vez de la global
cuadrilla version                   # qué está instalado y en qué formato
```

`update` actualiza el clon y vuelve a ejecutar el instalador desde él: agrega los agentes nuevos y elimina los que una versión retiró. Si la instalación sigue una rama (`main` por defecto), hace `pull`; si está fijada a una versión, pasa a la versión más reciente. Sin el comando, lo mismo se logra con `./install.sh --update` / `.\install.ps1 -Update`.

Las instalaciones anteriores al comando `cuadrilla` (v0.1.x) necesitan ejecutar una vez más el instalador de una línea para obtenerlo. Un simple `git pull` no basta: no enlaza agentes nuevos como `cuadrilla-explore`. A partir de ahí, basta con `cuadrilla update`.

### Todas las plataformas

Los archivos existentes con el mismo nombre se respaldan (`*.bak.<timestamp>`), nunca se sobrescriben en silencio. Cada destino recibe un `.cuadrilla-manifest` (commitéalo en instalaciones por proyecto): registra lo que instaló Cuadrilla, para que las actualizaciones solo reemplacen o eliminen sus propios archivos sin modificar. Las versiones están en [`CHANGELOG.md`](CHANGELOG.md) y en [Releases](https://github.com/Remy349/cuadrilla/releases); `CUADRILLA_REF` acepta cualquier tag o rama (por defecto `main`).

## OpenCode 1.x y 2.x

Cuadrilla distribuye los agentes en dos formatos generados desde una sola fuente:

| Formato | Archivos | Lo leen |
|---|---|---|
| `v1` | `agents/*.md` (la fuente) | OpenCode 1.x **y** 2.x — 2.x traduce el frontmatter V1 al cargarlo (deprecado, pero soportado) |
| `v2` | `dist/v2/agents/*.md` (generados) | Solo OpenCode 2.x: listas `permissions` nativas, sin traducción |

El instalador elige con `--format auto|v1|v2` (`-Format` en Windows; por defecto `auto`): `v2` si OpenCode 2.x es la única versión en tu PATH, `v1` en cualquier otro caso. **Nunca uses `v2` donde algún OpenCode 1.x lea la misma configuración**: 1.x no conoce el campo `permissions` y ejecutaría los agentes sin restricciones. `cuadrilla version` muestra el formato instalado; `cuadrilla update --format v2` lo cambia.

Los comandos (`commands/*.md`) son iguales en ambas versiones.

OpenCode 2.x cambió algunos valores por defecto que Cuadrilla ya contempla: permite `external_directory` (acceso fuera del proyecto) y `websearch` salvo que una regla diga lo contrario, y su agente integrado `explore` puede ejecutar cualquier comando de shell. Todos los agentes de Cuadrilla fijan esos permisos explícitamente, y el orquestador delega en su propio `cuadrilla-explore`, de solo lectura.

## Uso

1. Abre OpenCode y presiona **Tab** hasta ver el agente **cuadrilla**.
2. Describe lo que necesitas.

| Comando | Qué hace |
|---|---|
| `/cuadrilla-plan <pedido>` | Analiza y genera un plan de delegación sin tocar nada. |
| `/cuadrilla-review [foco]` | Revisión de arquitectura + seguridad/QA de los cambios actuales. |
| `/cuadrilla-commit [y push / abrir PR]` | Propone Conventional Commits y commitea tras tu aprobación. |

## Cómo trabaja

1. **Clasifica** el pedido en T0 (pregunta) · T1 (cambio pequeño) · T2 (feature) · T3 (estructural/riesgoso).
2. **Se aterriza** en el repo real antes de planificar (stack, scripts, convenciones), directamente o con `cuadrilla-explore`.
3. **Pregunta** solo lo que bloquea, con un default recomendado.
4. **Planifica** con dependencias: contratos antes que consumidores; paralelo solo si no comparten archivos.
5. **Delega** con briefs autocontenidos (objetivo, contexto, alcance, criterios de aceptación, restricciones).
6. **Verifica** cada reporte contra los criterios; máximo 2 reintentos, luego escala. QA obligatorio en auth, pagos, datos personales y endpoints públicos.
7. **Entrega** un reporte integrado: resultado, cambios, verificación real, supuestos y pendientes.

Todos los agentes piden confirmación antes de leer archivos `.env` o de tocar algo fuera del proyecto.

## Modelos

Los agentes no fijan modelo. Recomendado: modelo fuerte para `cuadrilla` y `cuadrilla-architect`, y uno rápido/barato para los demás. Ver [`examples/opencode.json`](examples/opencode.json) (OpenCode 1.x, clave `agent`) o [`examples/opencode.v2.json`](examples/opencode.v2.json) (OpenCode 2.x, clave `agents`).

## Personalizar permisos

Tus reglas en `opencode.json` se aplican después de las de Cuadrilla, así que prevalecen. En OpenCode 1.x: `agent.<nombre>.permission` (un mapa). En OpenCode 2.x: `agents.<nombre>.permissions` (lista de `{ "action", "resource", "effect" }`; ahí `bash` es `shell` y `task` es `subagent`).

## Desarrollo

```bash
pip install pyyaml
python3 scripts/build.py             # regenera dist/v2 tras editar agents/ (commitea el resultado)
python3 scripts/validate.py          # lint de frontmatter, permisos y referencias; verifica que dist/v2 esté al día
scripts/test-install.sh              # test end-to-end de install.sh + cuadrilla
pwsh -File scripts/test-install.ps1  # test end-to-end de install.ps1 + cuadrilla.ps1
```

CI además valida `dist/v2` contra el schema oficial de OpenCode 2.x (`@opencode/schema`); ver el README en inglés.

## Licencia

MIT © Santiago Moraga
