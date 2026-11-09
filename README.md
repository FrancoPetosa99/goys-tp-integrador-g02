| <h1>UTN-FRLP</h1>| <img src="./logo.png" alt="Logo del Proyecto" width="100"> |
|-------------------------|----------------------------------|

# Proyecto Integrador - DB Scale Lab: Escalado y Alta Disponibilidad de PostgreSQL

Laboratorio de escalado y alta disponibilidad de PostgreSQL 17 con réplicas de lectura, desplegado sobre una red segmentada de 6 subredes unidas por un router Linux (firewall deny-by-default, VIP de escritura con DNAT e inyección de latencia). El laboratorio mide la curva de escalado al agregar réplicas (0, 1 y 2), el efecto de la latencia de red sobre la replicación en streaming, y la tolerancia a fallos mediante caída de réplica y failover manual del primario.

Trabajo Práctico Integrador (TP4) para la materia de Redes — UTN FRLP, Grupo 02.

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

## Stack tecnológico (planificado)

- **Orquestación:** Docker Compose, con perfiles por escenario (base única, 1 réplica, 2 réplicas)
- **Base de datos:** PostgreSQL 17, replicación física en streaming (asincrónica)
- **Aplicación:** Python (FastAPI), separación de pools de lectura/escritura
- **Red:** router Linux (iptables, iproute2, `tc netem` para latencia inyectada)
- **Carga:** k6
- **Observabilidad:** Prometheus, Grafana, postgres_exporter, cAdvisor
- **Automatización:** Ansible

## Cómo reproducir

> **Estado: planificado, aún no implementado.** Esta sección describe cómo se va a reproducir el laboratorio una vez completadas las fases de implementación; todavía no hay nada ejecutable.

Está previsto levantar el laboratorio con Docker Compose y perfiles, por ejemplo:

```bash
# Escenario base (sin réplicas) — a confirmar nombre de perfil en Fase 1/2
docker compose --profile base up

# Escenario con 1 réplica
docker compose --profile r1 up

# Escenario con 2 réplicas
docker compose --profile r2 up
```

Antes de levantar el stack va a ser necesario copiar `.env.example` a `.env` y completar los valores reales (contraseñas, nunca commitear ese archivo). El detalle de automatización con Ansible, pasos de validación y runbook de failover se van a documentar en `documento/runbook.md` y `ansible/` a medida que se implementen las fases correspondientes (ver `.ai/plan/fases.md`).
