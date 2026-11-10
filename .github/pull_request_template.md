<!--
Plantilla de PR para el merge de cada fase a main (DB Scale Lab, GOYS G02).
Completar antes de pedir el merge. Base repository: el fork del equipo.
-->

## Qué incluye

<!-- 2-4 líneas: qué agrega esta fase sobre la anterior. -->

## Criterios

| Criterio | Comando | Resultado |
|---|---|---|
| A_.1 | `` | OK / FALLA |

## Decisiones

<!-- Enlazar las decisiones nuevas o actualizadas en .ai/conocimiento/decisiones-tecnicas.md -->

## Evidencias

<!-- Capturas de capturas/<fase>/, con el nombre exacto de cada archivo. -->

## Quién subió qué

| Persona | Archivos |
|---|---|
| Martín | |
| Franco | |
| Isabella | |
| Agustín | |
| Sofía | |

## Para quien revisa

- [ ] `docker compose config` no tiene errores y no usa `:latest` en ninguna imagen.
- [ ] Ningún secreto en archivos versionados (`.env` sigue ignorado).
- [ ] Ningún puerto de base de datos publicado al host (solo 3000 y 9091).
- [ ] Cada criterio de aceptación de la fase tiene comando y resultado reales, no inventados.
- [ ] Los archivos subidos coinciden con `.ai/plan/reparto-commits.md`.

---

**Al mergear: Create a merge commit, nunca squash.**
