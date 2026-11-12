| <h1>UTN-FRLP</h1>| <img src="./logo.png" alt="Logo del Proyecto" width="100"> |
|-------------------------|----------------------------------|

# Proyecto Integrador - DB Scale Lab: Escalado y Alta Disponibilidad de PostgreSQL

Laboratorio de escalado y alta disponibilidad de PostgreSQL 17 con réplicas de lectura, desplegado sobre una red segmentada de 6 subredes unidas por un router Linux (firewall deny-by-default, VIP de escritura con DNAT e inyección de latencia). El laboratorio mide la curva de escalado al agregar réplicas (0, 1 y 2), el efecto de la latencia de red sobre la replicación en streaming, y la tolerancia a fallos mediante caída de réplica y failover manual del primario.

Trabajo Práctico Integrador (TP4) para la materia Gestión Operativa y Seguridad en Redes (GOYS) — UTN FRLP, Grupo 02.

---

## Integrantes
1. Petosa Ayala Franco
2. Bresciani Isabella
3. Eliseche Martin
4. Gutierrez Mora Agustin
5. Kalpin Sofía

## Docentes
1. Rodriguez Emanuel
2. Osvaldo Falabella

## Stack tecnológico

- **Orquestación:** Docker Compose, con perfiles por escenario (base única, 1 réplica, 2 réplicas)
- **Base de datos:** PostgreSQL 17, replicación física en streaming (asincrónica)
- **Aplicación:** Python (FastAPI), separación de pools de lectura/escritura, fallback de lectura al primario configurable
- **Red:** router Linux propio (iptables, iproute2, `tc netem` para latencia inyectada), 6 subredes Docker segmentadas, firewall deny-by-default
- **Carga:** k6, con métricas enviadas a Prometheus por remote write
- **Observabilidad:** Prometheus, Grafana (dashboard de 12 paneles), 3 postgres_exporter, cAdvisor
- **Automatización:** Ansible (preflight, validación de replicación, backup)

## Estado del proyecto

Implementado y medido de punta a punta (Fases 0 a 6). Los 4 experimentos del laboratorio (curva de escalado, caída de réplica, efecto de la red sobre la replicación y la consistencia, failover manual) están documentados con números reales en `documento/resultados-experimento-1.md`, `documento/resultados-experimentos-2-3-4.md` y en el informe final (`documento/informe-final.pdf` / `.docx`).

## Cómo levantarlo

Requiere Docker Compose y, para los playbooks de Ansible, `ansible-playbook` instalado en el host. Copiar `.env.example` a `.env` en la raíz del repo y completar los valores reales (nunca commitear `.env`).

Todos los comandos se corren con `make` desde la raíz del repo:

```bash
make preflight   # valida Docker, imágenes, puertos, RAM/CPU y ruteo antes de levantar nada
make up-base     # escenario sin réplicas (lecturas al primario)
make up-r1       # escenario con 1 réplica de lectura
make up-r2       # escenario con 2 réplicas de lectura (el topológicamente completo)
make test        # sube k6 y corre carga-base, estrés y pico contra el escenario arriba
make validar     # valida replicación, lag y permisos de roles (requiere escenario r2)
make backup      # dump + configuraciones a backups/, con timestamp
make reset SCENARIO=r2   # vuelve al estado inicial de datos (seed limpio); default r2
make down        # baja todos los contenedores (nunca -v: los datos quedan)
```

Con el stack arriba: Grafana en `http://localhost:3000` (dashboard "DB Scale Lab") y Prometheus en `http://localhost:9091`. Ninguna base de datos se publica al host. El runbook completo, con los pasos exactos de cada experimento y de un failover manual, está en `documento/runbook.md`; la guía de demo corta para el stand de la feria está en `documento/guia-demo-stand.md`.

## Resumen de resultados reales

- **Curva de escalado:** agregar 1 sola réplica **no** mejora el throughput ni la latencia bajo carga alta en este hardware compartido (el cuello de botella se traslada del primario a la única réplica). Con **2 réplicas** sí: +70% de throughput y entre 43% y 50% menos de latencia p95, frente a 1 réplica, en los perfiles de carga alta.
- **Caída de una réplica:** el servicio no se interrumpe (0% de errores HTTP durante el corte y la recuperación); la alerta correspondiente dispara y se resuelve sola.
- **Latencia de red y replicación:** el lag de replicación es siempre mayor con latencia agregada (≥20 ms), aunque sin escalar en forma estrictamente proporcional (atribuido al hardware compartido). Un fallback de lectura al primario elimina las lecturas con dato ausente, pero no las lecturas con dato desactualizado.
- **Failover manual:** 2,8 segundos entre detener el primario y la primera escritura exitosa, en la corrida limpia.

## Estructura del repositorio

- `app/` — aplicación FastAPI (pools de lectura/escritura, detección de réplicas caídas, métricas).
- `demo/` — todo lo que compone el laboratorio: `docker-compose.yml`, el router (`router/`), PostgreSQL (`postgres/`), scripts operativos (`scripts/`: reset de estado, inyección de latencia, corte de réplica, failover, escenarios), carga (`k6/`), monitoreo (`prometheus/`, `grafana/`).
- `ansible/` — playbooks de preflight, validación de replicación y backup.
- `diagramas/` — topología de red (Mermaid) e imagen de la arquitectura real.
- `documento/` — resultados de los 4 experimentos, runbook, informe final (`.docx`/PDF) y guía de demo de stand.
- `poster/` — póster A1 del proyecto (editable `.pptx` + PDF).
- `capturas/` — evidencia real de cada fase.
- `templates/` — checklist de entrega de la cátedra.
- `.ai/` — memoria del proyecto para el agente (decisiones técnicas, entorno verificado, plan de fases y reparto de commits).

## Equipo

| Integrante | Rol |
|---|---|
| Martín Eliseche | Coordinación, app Python, Docker Compose, runbook y póster |
| Franco Petosa Ayala | Red segmentada, router y firewall, scripts de latencia y fallas |
| Isabella Bresciani | PostgreSQL: replicación, roles y failover |
| Agustín Gutierrez Mora | Monitoreo (Prometheus y Grafana) y pruebas de carga con k6 |
| Sofía Kalpin | Ansible, evidencias y documento final |
