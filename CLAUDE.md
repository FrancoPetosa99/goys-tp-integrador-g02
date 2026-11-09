# CLAUDE.md — TP4 Integrador GOYS · Grupo 02

Proyecto: **DB Scale Lab**, laboratorio de escalado de PostgreSQL con réplicas de lectura sobre una red segmentada (modalidad A). UTN FR La Plata, cátedra GOYS. **Feria de Redes: martes 17/11/2026.**

## Leé primero, en este orden
1. `.ai/README.md` (índice y orden de precedencia)
2. `.ai/contexto/resumen-proceso.md`
3. `.ai/plan/fases.md` y `.ai/plan/reparto-commits.md`
4. `.ai/conocimiento/entorno.md` y `decisiones-tecnicas.md`
5. `.ai/contexto/propuesta-completa.md` (la propuesta con todo el detalle)

## Reglas que NUNCA se rompen

### Git
- **Nunca** ejecutes `git add`, `commit`, `push`, `pull`, `fetch`, `merge`, `rebase`, `checkout`, `switch`, `reset`, `restore`, `stash`, `clean`, `rm`, `mv`, ni `git config` que escriba. Solo lectura: `status`, `log`, `diff`, `branch`, `shortlog`.
- Los commits los hacen las **5 personas**, cada una con su identidad, trabajando directo sobre `main` en esta única máquina. Tu rol es indicar, al cerrar cada fase, qué archivos sube cada una (`/cerrar-fase`).
- Nadie commitea por otro. Tu resumen por archivo existe para que cada persona pueda **explicar** lo que sube.

### Secretos
- Ninguna contraseña ni token en archivos versionados. Todo va en `.env` (ignorado por git) con `.env.example` de muestra con valores ficticios.
- No leas ni muestres el contenido de `.env`.

### Entorno
- No toques el stack `goys-vuln-lab` (contenedores `node-lab`, `py-lab`, `php-lab`, red `goys-vuln-lab_labnet`) ni el PostgreSQL nativo de WSL (puerto 5432 del host).
- **No publiques el puerto 5432 al host.** Solo se publican Grafana (3000) y Prometheus (9091).
- No tenés `sudo`. Si algo lo requiere, detenete y explicá qué hace falta y por qué.
- No modifiques reglas del host ni sysctls del host.
- Pedí confirmación antes de `docker compose down`, `docker rm`, `docker network rm`, `docker volume rm`, `docker system prune` o cualquier borrado.

### Calidad
- Imágenes siempre con **versión fija** (sin `latest`), las de `.ai/conocimiento/entorno.md`.
- Cada criterio de aceptación de una fase se verifica con **comandos reales** y se reporta el resultado. No declares terminada una fase sin esa evidencia.
- No inventes resultados ni métricas. El documento y el póster reflejan solo lo medido.
- Si algo del diseño tiene que cambiar, registralo en `.ai/conocimiento/decisiones-tecnicas.md` y avisá al usuario antes de seguir.
- No afirmes causas que no verificaste. Si no sabés por qué algo funciona, decilo.

### Forma de trabajo
- **Una fase por vez.** Usá la lista de tareas. Al terminar corré `/cerrar-fase N` y **detenete**: no avances hasta que el usuario confirme que los 5 commits están pusheados.
- Cada persona sube solo los archivos de su fila en `.ai/plan/reparto-commits.md`.
- Antes de cerrar una fase, invocá al subagente `revisor-pre-commit`.
- Idioma: español. Mensajes de commit sugeridos: Conventional Commits en español (`feat(demo): …`).
