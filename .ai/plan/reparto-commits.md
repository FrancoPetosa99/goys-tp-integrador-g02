# Reparto de commits

Trabajamos 5 personas en **una sola máquina**, directo sobre `main`. Los commits los hacen las personas, nunca el agente.

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
| **3** | `app/**`, `demo/docker-compose.yml` | `demo/router/firewall.sh` | `demo/postgres/replica-entrypoint.sh`; 2 capturas en `capturas/3-replicacionStreaming/` | `demo/k6/`: `common.js`, `carga-base.js`, `estres.js`, `pico.js` | 5 capturas en `capturas/4-curvaDeEscalado/` |
| **4** | `app/**`, `demo/docker-compose.yml` | `demo/scripts/`: `netem.sh`, `corte-replica.sh`, `escenarios.sh` | `demo/scripts/promote-replica-1.sh` | `demo/prometheus/alerts.yml`, `demo/grafana/dashboards/db-scale-lab.json` | 5 capturas en `capturas/5-…` y `capturas/6-…` |
| **5** | `documento/runbook.md`, `Makefile` | `ansible/ansible.cfg`, `ansible/inventory/hosts.yml`, `ansible/vars/lab.yml` | `ansible/playbooks/03-backup.yml`, `backups/.gitkeep` | `ansible/playbooks/02-validar-replicacion.yml` | `ansible/playbooks/01-preflight.yml`; 3 `.txt` en `capturas/7-automatizacionAnsible/` |
| **6** | `poster/` (editable y PDF) | `diagramas/imagen-diagrama.png` | `templates/checklist-entrega.md` | `README.md`, `progreso.md` | `documento/` (PDF) |

## Protocolo de commit (cada persona, desde esta máquina)
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
- Otro integrante revisa `git diff --staged` en persona antes del push (la regla del README pide revisión antes de pushear a `main`).
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

