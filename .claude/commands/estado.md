---
description: Muestra en qué fase está el proyecto y qué falta (solo lectura)
---

Hacé un diagnóstico de solo lectura del estado del proyecto:

1. Leé `.ai/plan/fases.md` y `progreso.md`. Decime cuál es la fase actual y cuáles son sus criterios de aceptación.
2. Con `git status` y `git log --oneline -15`, listá qué archivos están sin commitear y quién commiteó lo último. No ejecutes ningún comando de git que escriba.
3. Con `docker compose ps` (si existe `demo/docker-compose.yml`) mostrá qué servicios están corriendo.
4. Resumí en máximo 10 líneas: qué está hecho, qué falta de la fase actual y qué decisión o dato necesitás de las personas.
