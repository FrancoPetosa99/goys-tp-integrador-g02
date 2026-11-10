---
description: Cierra una fase, verifica los criterios y entrega a cada persona qué archivos commitear
argument-hint: <número de fase>
---

Cerrá la **fase $ARGUMENTS**. Seguí estos pasos en orden y no hagas ningún `git add`, `commit`, `push` ni `pull`.

1. **Rama.** Mostrá la rama actual con `git branch --show-current` (solo lectura). Si es `main`, es un hallazgo: avisá que durante una fase no debería estarse en `main` y preguntá cómo seguir antes de continuar.
2. **Verificación.** Releé los criterios de aceptación de la fase en `.ai/plan/fases.md`. Ejecutá cada uno con comandos reales y armá una tabla: criterio, comando, resultado (OK / FALLA). Si algo falla, detenete y decime qué falta: no cierres la fase.
3. **Revisión previa.** Invocá al subagente `revisor-pre-commit` sobre los archivos de la fase y mostrame su informe. Si encuentra secretos, imágenes sin versión fija, o archivos sin dueño asignado (o que alguien vaya a commitear un archivo que no es suyo), corregilo o avisame antes de seguir.
4. **Reparto.** Con la tabla de `.ai/plan/reparto-commits.md`, generá un bloque por persona (Martín, Franco, Isabella, Agustín, Sofía) con:
   - Los archivos exactos que sube (rutas completas; para capturas, los nombres de archivo exactos y qué debe verse en cada una).
   - El comando completo, listo para copiar:
     ```bash
     git fetch && git status -sb
     git add <archivos>
     git -c user.name="<user.name>" -c user.email="<user.email>" commit -m "<tipo(scope): descripción>"
     git log -1 --format='%an <%ae>'
     git push                             # a origin/fase-N-<slug>, ya trackeada
     ```
     Aclará que no se usa `git pull --rebase` a ciegas (ver `.ai/plan/reparto-commits.md`). Usá los datos de la tabla de identidades; si falta alguno, dejá el marcador `<COMPLETAR>` y avisame. No inventes mails.
   - Su fila sugerida para `progreso.md` (fecha, qué se hizo, quién, mensaje del commit).
   - **Explicación para la defensa:** 3 líneas por archivo (qué hace, por qué se hizo así y una pregunta que podría hacer el docente), para que la persona pueda explicarlo.
5. **Cierre.** Terminá con el resumen: qué quedó hecho, qué decisiones se registraron en `decisiones-tecnicas.md`, y esta frase: "Cuando los 5 commits estén pusheados a la rama de la fase, el equipo mergea `fase-$ARGUMENTS-<slug>` a `main` con **merge commit** (nunca squash) — por línea de comandos o por Pull Request (base repository = fork del equipo). Fase $ARGUMENTS lista. Avisame cuando los 5 commits estén pusheados para pasar a la fase siguiente." Luego **detenete**.
