# Plan por fases

Una fase por vez. Al terminar: `/cerrar-fase N` y detenerse. Los archivos de cada fase los redacta el agente; los commitea la persona asignada en `reparto-commits.md`. Las **capturas de pantalla** las toman las personas (el agente entrega la lista exacta de nombres y qué debe verse en cada una).

Fechas objetivo: F0 hasta mar 10/11 · F1 mié 11 · F2 jue 12 · F3 vie 13–sáb 14 · F4 dom 15 · F5 dom 15–lun 16 · F6 lun 16. Feria: **mar 17/11**.

---

## Fase 0 — Preparación del repo
**Archivos que redacta el agente:**
- `.gitignore`: agregar `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `node_modules/`, `pgdata/`, `*-data/`, `k6-results/`, `*.k6.json`, `backups/*.sql`, `backups/*.dump`, `backups/*.gz`, `.claude/settings.local.json`.
- `.env.example`: contraseñas ficticias (`PG_SUPERUSER_PASSWORD`, `APP_WRITER_PASSWORD`, `APP_READER_PASSWORD`, `REPLICATOR_PASSWORD`, `MONITOR_PASSWORD`, `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`), `READ_FALLBACK_TO_PRIMARY`, límites de recursos (D11).
- `.mailmap` con los 5 integrantes. Conocidos: `MartinEliseche <tinchoeliseche@gmail.com>` y `Franco Petosa Ayala <84604362+FrancoPetosa99@users.noreply.github.com>`. Los otros mails se **completan las personas**; no inventarlos.
- `progreso.md`: tabla de integrantes (nombre, usuario de GitHub, rol), proyecto y pendientes.
- `README.md`: nombre del proyecto, descripción, integrantes, docentes, stack y cómo reproducir (marcado como "planificado").

**Criterios de aceptación:**
- A0.1 `git check-ignore -v` confirma que `.env`, `pgdata/` y `__pycache__/` quedan ignorados.
- A0.2 `.env.example` no contiene secretos reales.
- A0.3 `.mailmap` sintácticamente válido; marcar los mails faltantes.
- A0.4 `progreso.md` tiene los 5 integrantes con su usuario de GitHub.

**Tareas manuales de las personas (el agente las lista, no las ejecuta):** instalar Ansible (`sudo apt install -y ansible`), confirmar que Isabella, Agustín y Sofía son colaboradores, agregar cada mail de la facultad a su cuenta de GitHub, crear su token personal para el push.

---

## Fase 1 — Red segmentada y router
**Entregables:** `demo/docker-compose.yml` (solo redes, router y nodos de prueba con perfil `test-red`), `demo/router/Dockerfile`, `entrypoint.sh`, `firewall.sh`, `diagramas/topologia.md`.

**Diseño (propuesta §2.2–2.4):**
| Red | Subred |
|---|---|
| `net-clientes` | 10.50.1.0/24 |
| `net-app` | 10.10.1.0/24 |
| `net-db-primaria` | 10.20.1.0/24 |
| `net-db-local` | 10.30.1.0/24 |
| `net-db-remota` | 10.31.1.0/24 |
| `net-mon` | 10.40.1.0/24 |
Gateway de Docker `.253`; router `.254` en las 6. Nodos con `.10` salvo los de monitoreo (`.20`, `.21`, `.31`–`.33`, `.40`). `driver_opts` según D3.

**Criterios de aceptación:**
- A1.1 `docker compose config` es válido y no hay `latest` en ningún archivo.
- A1.2 Las 6 redes existen con las subredes indicadas y el router tiene `.254` en cada una.
- A1.3 `ip_forward=1` en el router, fijado con `sysctls:`.
- A1.4 Con nodos de prueba alpine: ping entre segmentos pasando por el router (confirmar el salto con `traceroute`).
- A1.5 Firewall: `FORWARD DROP` con las reglas permitidas de §2.4. `nc -zv -w2 10.20.1.10 5432` desde `net-clientes` **falla**; las redes de base de datos no inician conexiones hacia app ni clientes.
- A1.6 Sin salida a Internet: `ping -c1 -W2 1.1.1.1` falla desde cualquier nodo.
- A1.7 VIP: desde `net-app`, conectar a `10.20.1.100:5432` llega a un listener de prueba en `10.20.1.10` (DNAT en el router).
- A1.8 Publicación de puertos: un contenedor de prueba con `ports: 3000:80` en una red del lab responde desde `localhost`. Si falla, aplicar D3b y registrarlo en `decisiones-tecnicas.md`.
- A1.9 `docker compose restart router` vuelve a aplicar las reglas.

**Capturas (personas):** `1-contenedoresRunning.png`, `1-pingEntreSegmentos.png`, `1-conexionBloqueada5432.png`, `1-sinSalidaAInternet.png`.

---

## Fase 2 — Base única, app y monitoreo
**Entregables:**
- `demo/postgres/`: `init.sql` (esquema), `roles.sql`, `seed.sql`, `pg_hba.conf`, `postgresql.conf`.
- `app/`: FastAPI (gunicorn + uvicorn), psycopg con dos pools, `Dockerfile`, `requirements.txt`. Endpoints de la propuesta §2.7, más `/health` y `/metrics`.
- `demo/prometheus/` (`prometheus.yml`, `alerts.yml`), `demo/grafana/` (provisioning de datasource y dashboards, `db-scale-lab.json`).
- Servicios en el Compose: `pg-primary`, `api`, `prometheus`, `grafana`, `pg-exporter-p`, `cadvisor`. `demo/router/firewall.sh` actualizado con las reglas de app, base y monitoreo.

**Esquema:** `categories(id, name único, description, created_at)`, `products(id, category_id FK, name, price, stock, created_at, updated_at)`, índice `products(category_id, price)`. Seed: 10 categorías y ~500.000 productos con `generate_series`.

**Roles:** `app_writer` (SELECT/INSERT/UPDATE), `app_reader` (solo SELECT), `replicator` (solo REPLICATION), `monitor` (`pg_monitor`). `pg_hba.conf` con `scram-sha-256` y filtro por subred de origen: `app_*` desde 10.10.1.0/24, `replicator` desde 10.30.1.0/24 y 10.31.1.0/24, `monitor` desde 10.40.1.0/24.

**App:** pool de escritura a `10.20.1.100:5432` (usuario `app_writer`). Pool de lectura a la lista de hosts de lectura (usuario `app_reader`); con base única apunta al primario. Configuración por variables de entorno. `GET /products/{id}` con fallback al primario si `READ_FALLBACK_TO_PRIMARY=true`.

**Criterios de aceptación:**
- A2.1 Los 8 endpoints responden con datos correctos (probar cada uno con `curl` desde `net-clientes`).
- A2.2 Con `app_reader`, un `INSERT` falla; con `monitor`, `SELECT` sobre `products` falla.
- A2.3 Una conexión a PostgreSQL desde una subred no autorizada es rechazada por `pg_hba.conf`.
- A2.4 Prometheus ve todos los targets en estado `up`; Grafana abre en `localhost:3000` con el dashboard provisionado.
- A2.5 Una prueba corta de k6 (comando suelto, no versionado) genera métricas visibles en Grafana.
- A2.6 La CPU de la app no es el límite: con la carga de prueba, `cadvisor` muestra a PostgreSQL más cargado que la API (si no, subir workers o bajar el trabajo por request).
- A2.7 Ningún secreto en archivos versionados; la contraseña de Grafana viene de `.env`.

**Capturas (personas):** `2-dashboardGrafanaBaseUnica.png`, `2-prometheusTargets.png`, `2-lineaBaseK6.png`.

---

## Fase 3 — Réplicas y curva de escalado
**Entregables:** `demo/postgres/replica-entrypoint.sh` (alta con `pg_basebackup -R`), servicios `pg-replica-1` y `pg-replica-2` con perfiles `r1` y `r2`, `pg-exporter-1/2`, pool de lectura con round-robin en la app, reglas de replicación en `firewall.sh`, `demo/k6/` (`common.js`, `carga-base.js`, `estres.js`, `pico.js`).

**Criterios de aceptación:**
- A3.1 `pg_stat_replication` en el primario muestra cada réplica en `streaming`.
- A3.2 Las réplicas rechazan escrituras (`hot_standby`).
- A3.3 El tráfico de lectura se reparte entre réplicas (verificar con métricas de la app o conexiones por nodo).
- A3.4 Los tres escenarios (base única, `r1`, `r2`) levantan con un comando de Compose.
- A3.5 Los scripts de k6 usan exactamente la mezcla de la propuesta (90/10) y envían métricas a Prometheus (D14).
- A3.6 Hay un procedimiento documentado para volver al **mismo estado inicial de datos** entre corridas (D12).
- A3.7 Se ejecutan las 9 corridas del Experimento 1 (3 pruebas × 0, 1 y 2 réplicas) y se guardan los resultados (tabla en `documento/` o `capturas/4-…`).

**Capturas (personas):** `3-pgStatReplication.png`, `3-replicaRechazaEscritura.png`, `4-curvaCargaBase.png`, `4-curvaEstres.png`, `4-curvaPico.png`, `4-cpuPrimario.png`, `4-comparacionEscenarios.png`.

---

## Fase 4 — Latencia y tolerancia a fallos
**Entregables:** `demo/scripts/` (`netem.sh`, `corte-replica.sh`, `escenarios.sh`, `promote-replica-1.sh`), detección de réplica caída en la app, alertas `PrimarioCaido`, `ReplicaCaida`, `LagAlto` y paneles de lag y estado en el dashboard.

**Criterios de aceptación:**
- A4.1 Experimento 2: `docker stop pg-replica-2` en plena carga. La app marca la réplica como caída y deja de enviarle lecturas; el servicio no se interrumpe. Medir el impacto en latencia y errores.
- A4.2 Experimento 3: latencias de 0, 20, 50 y 100 ms con `tc netem` en la interfaz hacia `net-db-remota`. Medir el lag de `pg-replica-2`. Incluir la prueba corta de read-after-write con y sin `READ_FALLBACK_TO_PRIMARY`.
- A4.3 Experimento 4: `docker stop pg-primary`; `promote-replica-1.sh` promueve la réplica local y cambia el DNAT de la VIP. Medir el tiempo hasta la primera escritura exitosa.
- A4.4 Cada alerta se dispara en su caso y se resuelve al restaurar.
- A4.5 Cada script deja el entorno en un estado conocido (probar que se puede repetir).

**Capturas (personas):** `5-lagVsLatencia.png`, `5-readAfterWrite.png`, `6-replicaCaidaDashboard.png`, `6-failoverNormal.png`, `6-failoverEnFalla.png`, `6-failoverRecuperado.png`, `6-alertaFiring.png`.

---

## Fase 5 — Ansible, Makefile y runbook
**Entregables:** `ansible/` (`ansible.cfg`, `inventory/hosts.yml`, `vars/lab.yml`, `playbooks/01-preflight.yml`, `02-validar-replicacion.yml`, `03-backup.yml`), `Makefile`, `documento/runbook.md`, `backups/.gitkeep`.

**Criterios de aceptación:**
- A5.1 `01-preflight`: Docker y Compose presentes, imágenes con versión fija ya descargadas, puertos 3000 y 9091 libres, RAM y CPU suficientes, y una prueba de ruteo entre segmentos.
- A5.2 `02-validar-replicacion`: réplicas en `streaming`, lag medido, y permisos de cada usuario validados con `assert`.
- A5.3 `03-backup`: configuraciones y un volcado en `backups/` (el volcado no se versiona; ver `.gitignore`).
- A5.4 Estilo según la sección «Convenciones técnicas del proyecto» (al final de este archivo); los 3 playbooks pasan dos veces seguidas (idempotencia de los de lectura).
- A5.5 `make` levanta cada escenario, corre las pruebas y limpia. El runbook cubre puesta en marcha, escenarios, experimentos, failover y recuperación.

**Capturas (personas):** `01-preflight.txt`, `02-validar-replicacion.txt`, `03-backup.txt` en `capturas/7-automatizacionAnsible/`.

---

## Fase 6 — Cierre
**Entregables:** `poster/` (editable + PDF A1), `documento/` (PDF, 5-7 páginas), `diagramas/imagen-diagrama.png`, `templates/checklist-entrega.md` completo, `README.md` y `progreso.md` finales.

**Criterios de aceptación:**
- A6.1 El documento y el póster reflejan solo lo implementado y medido; la sección de limitaciones declara el hardware compartido, el failover manual y la falta de TLS.
- A6.2 Checklist de entrega completo.
- A6.3 La demo corre completa en WSL2 y en la laptop Linux, **sin Internet**, al menos 3 veces seguidas.
- A6.4 El historial de git muestra commits de los 5 integrantes (`git shortlog -sne` agrupa bien con `.mailmap`).
- A6.5 Cada integrante puede explicar sus archivos: el agente prepara 5 preguntas probables del docente por persona.

---

## Convenciones técnicas del proyecto

Estándares propios del proyecto, válidos para todas las fases a partir de acá:

- **Capturas:** carpetas `capturas/<N>-<slugCamelCase>/` y archivos `<N>-<descripcionCamelCase>.png`; las salidas de Ansible se guardan como `.txt` con el nombre del playbook.
- **Ansible:** playbooks numerados por orden de ejecución; cabecera `hosts: controlador` con `connection: local` y `gather_facts: false`; variables centralizadas en `ansible/vars/lab.yml`; comandos con `ansible.builtin.command` y `argv:` (lista, nunca cadena de shell); `changed_when: false` en los playbooks de solo lectura; `register` + `assert` sobre el contenido real de `stdout`; `failed_when: false` solo cuando el fallo del comando es el resultado esperado; un `debug` antes de cada `assert` para que la salida sirva de evidencia.
- **Compose:** `container_name` y `hostname` explícitos, subredes y gateways fijos, anclas YAML para configuración repetida.
- **Commits:** Conventional Commits en español (`tipo(scope): descripción`), con los tipos y scopes que ya figuran en `.ai/plan/reparto-commits.md`.
- **Documento y póster:** formatos de la cátedra — documento A4, 12 pt, interlineado 1,5, 5-7 páginas; póster A1 vertical, letra mínima 24 pt, máximo 3 colores y 2 tipografías, con código QR al repo.
