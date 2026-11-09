# .ai/ — Contexto para agentes

Esta carpeta es la memoria del proyecto para Claude Code. `CLAUDE.md` (raíz) tiene las reglas; acá está el detalle.

| Archivo | Para qué sirve |
|---|---|
| `contexto/resumen-proceso.md` | Qué estamos construyendo, para quién, flujo, reglas y criterios de calidad (resultado de la entrevista de definición). |
| `contexto/propuesta-completa.md` | Propuesta formal completa, incluida la estructura del repo, el cronograma y el `docker compose` planificado. |
| `conocimiento/entorno.md` | Hechos **verificados** de la máquina: versiones, imágenes, puertos, qué funciona y qué no. |
| `conocimiento/decisiones-tecnicas.md` | Decisiones de diseño, con estado: Verificado / A verificar. |
| `plan/fases.md` | Fases 0 a 6: entregables, archivos y criterios de aceptación. |
| `plan/reparto-commits.md` | Quién sube qué en cada fase y cómo se commitea desde una sola máquina. |

## Orden de precedencia si hay conflicto
1. `CLAUDE.md`
2. `conocimiento/decisiones-tecnicas.md` (refleja lo verificado después de la propuesta)
3. `conocimiento/entorno.md`
4. `plan/*`
5. `contexto/propuesta-completa.md`


