# Reparto de commits

Trabajamos 5 personas en **una sola máquina**. Desde la Fase 1, cada fase se trabaja en su propia rama (`fase-N-<slug>`), creada desde `main` y ya pusheada a `origin` (trackeada), que se mergea a `main` al cerrar la fase. Los commits los hacen las personas, nunca el agente.

| Nombre | Usuario de GitHub | Rol |
|---|---|---|
| Martín Eliseche | MartinEliseche | Coordinación, app Python, Docker Compose, runbook y póster |
| Franco Petosa Ayala | FrancoPetosa99 | Red segmentada, router y firewall, scripts de latencia y fallas |
| Isabella Bresciani | IsabellaBresciani | PostgreSQL: replicación, roles y failover |
| Agustín Gutierrez Mora | agugutierrezz | Monitoreo (Prometheus y Grafana) y pruebas de carga con k6 |
| Sofía Kalpin | Sokalpin | Ansible, evidencias y documento final |

## Quién sube qué
Cada persona sube solo los archivos de su fila en `.ai/plan/reparto-commits.md`. Además, cada persona incluye en su commit **su propia fila** en `progreso.md`.

| Fase | Martín | Franco | Isabella | Agustín | Sofía |
|---|---|---|---|---|---|
| **0** | `CLAUDE.md`, `.ai/**`, `.claude/**` | `.gitignore`, `.env.example` | `.mailmap` | `progreso.md` | `README.md` |
| **1** | `demo/docker-compose.yml`, `demo/router/Dockerfile` | `demo/router/entrypoint.sh`, `demo/router/firewall.sh` | `diagramas/topologia.md` | 3 capturas en `capturas/1-redSegmentadaYRouter/` | 1 captura en `capturas/1-redSegmentadaYRouter/` |
| **2** | `app/**`, `demo/docker-compose.yml` | `demo/router/firewall.sh` | `demo/postgres/`: `init.sql`, `roles.sql`, `seed.sql`, `pg_hba.conf`, `postgresql.conf` | `demo/prometheus/`: `prometheus.yml`, `alerts.yml`; `demo/grafana/`: `provisioning/datasources/prometheus.yml`, `provisioning/dashboards/dashboards.yml`, `dashboards/db-scale-lab.json` | 3 capturas en `capturas/2-baseUnicaYMonitoreo/` |
| **3** | `app/**`, `demo/docker-compose.yml`, `.ai/conocimiento/decisiones-tecnicas.md`, `.ai/conocimiento/entorno.md` | `demo/router/firewall.sh` (sin cambios esta fase), `demo/scripts/reset-estado.sh` | `demo/postgres/replica-entrypoint.sh`; 2 capturas en `capturas/3-replicacionStreaming/` | `demo/k6/`: `common.js`, `carga-base.js`, `estres.js`, `pico.js`; `demo/prometheus/prometheus.yml` | `documento/resultados-experimento-1.md`; 5 capturas en `capturas/4-curvaDeEscalado/` |
| **4** | `app/**`, `demo/docker-compose.yml`, `.ai/conocimiento/decisiones-tecnicas.md`, `.ai/conocimiento/entorno.md`, `.ai/plan/reparto-commits.md` | `demo/scripts/`: `netem.sh`, `corte-replica.sh`, `escenarios.sh`; `.env.example`; 2 capturas: `capturas/5-lagVsLatencia/5-lagVsLatencia.png`, `capturas/5-readAfterWrite/5-readAfterWrite.png` | `demo/scripts/promote-replica-1.sh` | `demo/prometheus/alerts.yml`, `demo/grafana/dashboards/db-scale-lab.json`, `demo/k6/escritura-intensiva.js`, `demo/k6/read-after-write.js` | `documento/resultados-experimentos-2-3-4.md`; 6 capturas de la serie `6-`: **2** en `capturas/6-replicaCaidaDashboard/` (`6-replicaCaidaDashboard-parte1.png` y `-parte2.png`), y 1 cada una en `capturas/6-failoverNormal/`, `capturas/6-failoverEnFalla/`, `capturas/6-failoverRecuperado/`, `capturas/6-alertaFiring/` |
| **5** | `documento/runbook.md`, `Makefile` | `ansible/ansible.cfg`, `ansible/inventory/hosts.yml`, `ansible/vars/lab.yml` | `ansible/playbooks/03-backup.yml`, `backups/.gitkeep` | `ansible/playbooks/02-validar-replicacion.yml` | `ansible/playbooks/01-preflight.yml`; 3 `.txt` en `capturas/7-automatizacionAnsible/` |
| **6** | `poster/` (editable y PDF) | `diagramas/imagen-diagrama.png` | `templates/checklist-entrega.md` | `README.md`, `progreso.md` | `documento/` (PDF) |

## Protocolo de commit (cada persona, desde esta máquina)
La rama de la fase ya existe local y remotamente; no hace falta `git checkout -b`. `git push` (sin argumentos) alcanza: la rama ya trackea `origin/<rama-de-la-fase>`, nunca se pushea directo a `main`. Al cerrar la fase (los 5 commits pusheados a la rama), el merge a `main` se hace con **"Create a merge commit"** (nunca squash, nunca rebase) para no perder la autoría individual de cada commit (la necesita `git shortlog -sne` en A6.4). Si se usa un Pull Request para ese merge, el **base repository** debe ser el fork del equipo.
```bash
git fetch && git status -sb         # ¿aparece "behind"? Si sí, avisar antes de seguir
git add <solo sus archivos>          # nunca "git add ." ni "-A": la carpeta es compartida
git -c user.name="Apellido, Nombre" -c user.email="su-mail@alu.frlp.utn.edu.ar" commit -m "tipo(scope): descripción"
git log -1 --format='%an <%ae>'      # verificar el autor ANTES de pushear
git push                             # con su propio usuario y su token personal
```
- No tocar el `user.name` / `user.email` global.
- No usar `git pull --rebase` a ciegas: la carpeta es compartida y tiene cambios sin commitear de otras personas, y con eso falla. Como todos pushean desde esta máquina, el `main` local es el más actualizado. Si `git status -sb` muestra `behind`, usar `git pull --rebase --autostash`.
- No borrar ni mover archivos de otras personas ni los de `.ai/`, `.claude/` y `CLAUDE.md`: el agente los necesita en todas las fases. Si hace falta una copia de seguridad, hacerla fuera del repo.
- Cada mail de la facultad debe estar agregado a la cuenta de GitHub de esa persona.
- Cerrar sesión de GitHub en VS Code y navegador antes de pasar la máquina.

## Identidades (`user.name` / `user.email`)
| Persona | user.name | user.email |
|---|---|---|
| Martín | MartinEliseche | tinchoeliseche@gmail.com |
| Franco | FrancoPetosa99 | franco.petosa15@gmail.com |
| Isabella | IsabellaBresciani | brescianisa@gmail.com |
| Agustín | agugutierrezz | agugutierrezz27@gmail.com |
| Sofía | Sokalpin | sofikalpin@hotmail.com |

