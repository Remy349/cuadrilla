# Cuadrilla

**Un orquestador tipo tech lead y una cuadrilla de subagentes especialistas para [OpenCode](https://opencode.ai).**

Un orquestador que clasifica, planifica, delega y verifica, y siete especialistas que ejecutan dentro de permisos estrictos. Los prompts están en inglés (mayor alcance y compatibilidad entre modelos), pero **Cuadrilla responde en el idioma en que le escribas**.

[English](README.md)

## Instalación

**Global** (enlaces simbólicos; se actualiza con `git pull`):

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/cuadrilla/main/install.sh | bash
```

**Por proyecto** (se copia a `.opencode/` para commitearlo con el equipo):

```bash
./install.sh --project /ruta/a/tu/repo
```

**Windows:** `irm https://raw.githubusercontent.com/OWNER/cuadrilla/main/install.ps1 | iex`

Fijar versión: `CUADRILLA_REF=v0.1.0 ./install.sh` · Desinstalar: `./install.sh --uninstall`

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
