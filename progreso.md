# Bitácora del grupo — TP4

> Registrar acá el avance: qué hizo cada integrante, decisiones tomadas y pendientes.
> Esto ayuda a coordinar el trabajo y deja evidencia de la participación de todos.

---

## 👥 Integrantes

| Nombre | Usuario de GitHub | Rol en el grupo |
|--------|-------------------|-----------------|
| Martín Eliseche | MartinEliseche | Coordinación, app Python, Docker Compose, runbook y póster |
| Franco Petosa Ayala | FrancoPetosa99 | Red segmentada, router y firewall, scripts de latencia y fallas |
| Isabella Bresciani | IsabellaBresciani | PostgreSQL: replicación, roles y failover |
| Agustín Gutierrez Mora | agugutierrezz | Monitoreo (Prometheus y Grafana) y pruebas de carga con k6 |
| Sofía Kalpin | Sokalpin | Ansible, evidencias y documento final |

## 🎯 Proyecto

- **Modalidad:** A — Desarrollo
- **Tema:** DB Scale Lab — escalado y alta disponibilidad de PostgreSQL 17 con réplicas de lectura, sobre una red segmentada de 6 subredes unidas por un router Linux.
- **Problema/objetivo:** Medir cómo escala un sistema de lectura intensiva al agregar réplicas de PostgreSQL (0, 1 y 2), cómo afecta la latencia de red a la replicación en streaming, y validar la tolerancia a fallos (caída de réplica y failover manual del primario), cubriendo los ejes de Redes, Operación y Seguridad (segmentación deny-by-default, mínimo privilegio en la base y secretos fuera del repositorio).

## 🗓️ Registro de avance

| Fecha | Qué se hizo | Quién | Commit |
|-------|-------------|-------|--------|
| 09/11 | Fase 0 — Preparación del repo: `.gitignore`, `.env.example`, `.mailmap`, `progreso.md` y `README.md` redactados (reparto por archivo en `.ai/plan/reparto-commits.md`) | Todo el grupo | _(completar al commitear)_ | 
| 09/11 |  Fase 1: compose de red segmentada (6 redes, driver_opts D3) y Dockerfile del router (alpine + iptables) | Martín | feat(demo): agregar compose de red segmentada y Dockerfile del router | 
| 09/11 |  Fase 1: entrypoint y firewall del router (FORWARD DROP, VIP por DNAT, modo FIREWALL_MODE para diagnóstico) | Franco | feat(router): agregar entrypoint y firewall idempotente del router | 
| 09/11 |  Fase 1: diagrama de topología (6 redes, flujos permitidos, tabla de reglas de firewall) | Isabella | docs(diagramas): agregar diagrama de topología de red fase 1 | 
| 09/11 |  Fase 1: capturas de contenedores arriba, ping entre segmentos y conexión bloqueada a 5432 | Agustín | docs(capturas): agregar evidencias de contenedores, ping entre segmentos y bloqueo de fase 1 | 
| 09/11 |  Fase 1: captura de ping fallido a 1.1.1.1 desde un nodo del lab | Sofía | docs(capturas): agregar evidencia de falta de salida a Internet fase 1 | 
| 10/11 |  Fase 2: API FastAPI (8 endpoints, health y metrics), compose ampliado con sidecars de ruteo, plantilla de PR y decisiones actualizadas | Martín | feat(app) + feat(demo) | 
| 10/11 |  Fase 2: .env.example ampliado (host y puerto de la base, pools, workers y límites de CPU y memoria); firewall.sh no cambió porque las reglas de la fase 1 ya alcanzaban | Franco | feat(env) + docs(progreso) | 
| 10/11 |  Fase 2: esquema categories/products, 4 roles de mínimo privilegio, seed de 500.000 productos, pg_hba.conf y postgresql.conf finales con la replicación ya preparada | Isabella | feat(postgres) x2 | 
| 10/11 |  Fase 2: prometheus.yml (4 targets), alerta PrimarioCaido, datasource y dashboard "DB Scale Lab" provisionados (10 paneles) | Agustín | feat(prometheus) + feat(grafana) | 
| 10/11 |  Fase 2: capturas de targets en UP, línea base de k6 y dashboard de Grafana con carga en curso (2 partes) | Sofía | docs(capturas) x2 | 
| 11/11 |  Fase 3: fix del round-robin de lecturas y de la cardinalidad de métricas, compose con réplicas, exportadores y sidecars; decisiones D1, D12, D14, D21, D22 y D23 | Martín | fix(app) x2 + feat(demo) | 
| 11/11 |  Fase 3: script de reseteo de estado entre corridas (borra solo los volúmenes de PostgreSQL y reinicializa el escenario) | Franco  | feat(scripts) | 
| 11/11 |  Fase 3: alta de réplicas con pg_basebackup -R y capturas de replicación en streaming y de escritura rechazada en réplica | Isabella | feat(postgres) + docs(capturas) | 
| 11/11 |  Fase 3: escenarios de carga k6 (carga base, estrés y pico, mezcla 90/10) y scrape de pg-exporter-1 y 2 | Agustín | feat(k6) + feat(prometheus) | 
| 11/11 |  Fase 3: resultados del Experimento 1 y 5 capturas de la curva de escalado | Sofía | docs(documento) + docs(capturas) | 
| 11/11 |  Fase 4: detección de réplica caída con recheck y timeouts configurables en la app, compose de la fase, decisiones D6, D7, D8 y D16 actualizadas y D24 a D31 nuevas | Martín | feat(app) + chore(demo) | 
| 11/11 |  Fase 4: scripts de latencia (netem), corte de réplica y escenarios, variables nuevas en .env.example y capturas de lag vs latencia y read-after-write | Franco | feat(demo) + docs(capturas) | 
| 11/11 |  Fase 4: script de failover manual promote-replica-1.sh (promueve la réplica 1 y repunta la VIP, idempotente) | Isabella | feat(demo) | 
| 11/11 |  Fase 4: alertas PrimarioCaido, ReplicaCaida y LagAlto, paneles de rol, estado y lag, y escenarios k6 de escritura intensiva y read-after-write | Agustín | feat(monitoreo) + feat(k6) | 
| 11/11 |  Fase 4: resultados de los experimentos 2, 3 y 4 y 6 capturas de réplica caída y failover | Sofía | docs + docs(capturas) |
| 11/11 |  Fase 5: Makefile para orquestar escenarios, pruebas, backup y limpieza, y runbook operativo | Martín | feat(demo) + docs(documento) | 
| 11/11 |  Fase 5: configuración e inventario de Ansible y variables centralizadas del laboratorio | Franco | feat(ansible) x2 | 
| 11/11 |  Fase 5: playbook de backup del primario y de las configuraciones, y estructura de backups/ | Isabella | feat(ansible) + chore(demo) | 
| 11/11 |  Fase 5: playbook de validación de streaming, lag por LSN y permisos de los roles | Agustín | feat(ansible) | 
| 11/11 |  Fase 5: playbook de preflight, decisión D32 y evidencias de los 3 playbooks | Sofía | feat(ansible) + docs(repo) + docs(capturas) | 
| 12/11 |  Fase 6: decisiones D33 a D35, verificación de la demo (3 ciclos en WSL2) en entorno.md y reparto de commits de la fase | Martín | docs(repo) + docs(progreso) | 
| 12/11 |  Fase 6: diagrama real de la arquitectura (`imagen-diagrama.png`) y su referencia en `topologia.md` | Franco | docs(diagramas) x2 | 
| 12/11 |  Fase 6: checklist de entrega con solo ítems verificados y corrección del `.mailmap` para los 5 integrantes | Isabella | docs(repo) + fix(repo) | 
| 12/11 |  Fase 6: README final con estado real, Makefile, estructura y resultados medidos | Agustín | docs(repo) | 
| 12/11 |  Fase 6: guía de demo de stand de 5 minutos con plan B | Sofía | docs(documento) | 







## 🚧 Pendientes / decisiones

- [ ] Probar los 3 ciclos de arranque/apagado de la demo (escenario r2) en la laptop Linux del grupo — ver `.ai/conocimiento/entorno.md`, sección "Verificación Fase 6 — A6.3" (ya corrido 3 veces en WSL2)
- [ ] Repetir al menos un ciclo con la Wi-Fi cortada físicamente (en WSL2 y en la laptop Linux), como prueba adicional de "sin Internet" más allá de `--pull never`
- [ ] Practicar la guía de demo de stand (`documento/guia-demo-stand.md`) con cronómetro antes de la Feria
- [ ] Imprimir el póster A1 y revisar que el QR escanee bien en papel

## 📝 Notas

- Plan de fases completo en `.ai/plan/fases.md`. Decisiones técnicas en `.ai/conocimiento/decisiones-tecnicas.md`.
- Trabajamos los 5 desde una sola máquina compartida: cada persona commitea solo sus propios archivos (ver reparto por fase).
