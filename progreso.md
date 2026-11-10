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

## 🚧 Pendientes / decisiones

- [ ] Instalar Ansible en la máquina de trabajo (`sudo apt install -y ansible`)

## 📝 Notas

- Plan de fases completo en `.ai/plan/fases.md`. Decisiones técnicas en `.ai/conocimiento/decisiones-tecnicas.md`.
- Trabajamos los 5 desde una sola máquina compartida: cada persona commitea solo sus propios archivos (ver reparto por fase).
