# Cuadrilla

**Un orquestador tipo tech lead y una cuadrilla de subagentes especialistas para [OpenCode](https://opencode.ai).**

Un orquestador que clasifica, planifica, delega y verifica, y siete especialistas que ejecutan dentro de permisos estrictos. Los prompts están en inglés (mayor alcance y compatibilidad entre modelos), pero **Cuadrilla responde en el idioma en que le escribas**.

[English](README.md)

## Instalación

Requiere [OpenCode](https://opencode.ai) y `git`. Usa la sección de **tu shell**: el comando de Linux no funciona en PowerShell (ahí `curl` es un alias de `Invoke-WebRequest`).

| | Linux · macOS · WSL · Git Bash | Windows (PowerShell 5.1 o 7) |
|---|---|---|
| Instalador | `install.sh` | `install.ps1` |
| Instalación global | enlaces simbólicos → se actualiza con `git pull` | copia → se actualiza re-ejecutando |
| Agentes en | `~/.config/opencode/` | `%USERPROFILE%\.config\opencode\` |
| Clon en | `~/.local/share/cuadrilla` | `%LOCALAPPDATA%\cuadrilla` |

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

**Actualizar:** `git -C ~/.local/share/cuadrilla pull` (global) · **Desinstalar:** `./install.sh --uninstall [--project <dir>]`

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

**Actualizar:** vuelve a ejecutar el comando global · **Desinstalar:** `powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall [-Project <dir>]`

<details>
<summary>Problemas comunes en Windows</summary>

- **`No se encuentra ningún parámetro que coincida con el nombre del parámetro 'fsSL'`**: ejecutaste el comando de Linux en PowerShell. Usa el comando de PowerShell de arriba (o el de Linux desde Git Bash).
- **`git is required`**: instala Git (`winget install Git.Git`) y abre una terminal nueva.
- **`la ejecución de scripts está deshabilitada en este sistema`**: solo afecta a `.\install.ps1` desde un clon; usa `powershell -ExecutionPolicy Bypass -File .\install.ps1`. `irm | iex` no se ve afectado.
- **La red corporativa bloquea `raw.githubusercontent.com`**: clona el repo (o descarga el ZIP) y ejecuta `install.ps1` desde ahí; usa los archivos locales y no necesita red.

</details>

### Todas las plataformas

Los archivos existentes con el mismo nombre se respaldan (`*.bak.<timestamp>`), nunca se sobrescriben en silencio. Las versiones están en [`CHANGELOG.md`](CHANGELOG.md) y en [Releases](https://github.com/Remy349/cuadrilla/releases); `CUADRILLA_REF` acepta cualquier tag o rama (por defecto `main`).

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
2. **Se aterriza** en el repo real antes de planificar (stack, scripts, convenciones).
3. **Pregunta** solo lo que bloquea, con un default recomendado.
4. **Planifica** con dependencias: contratos antes que consumidores; paralelo solo si no comparten archivos.
5. **Delega** con briefs autocontenidos (objetivo, contexto, alcance, criterios de aceptación, restricciones).
6. **Verifica** cada reporte contra los criterios; máximo 2 reintentos, luego escala. QA obligatorio en auth, pagos, datos personales y endpoints públicos.
7. **Entrega** un reporte integrado: resultado, cambios, verificación real, supuestos y pendientes.

## Modelos

Los agentes no fijan modelo. Recomendado: modelo fuerte para `cuadrilla` y `cuadrilla-architect`, y uno rápido/barato para los implementadores. Ver [`examples/opencode.json`](examples/opencode.json).

## Licencia

MIT © Santiago Moraga
