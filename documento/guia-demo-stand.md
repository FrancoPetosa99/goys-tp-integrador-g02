# Guía de demo de stand (5 minutos) — Feria de Redes, 17/11/2026

Guion cronometrado para visitas cortas. Los tiempos de arranque y reset están medidos el 12/11/2026 en WSL2, escenario r2 (3 ciclos reales de `up`/`down`, ver `.ai/conocimiento/entorno.md` → "Verificación Fase 6 — A6.3").

Todos los comandos se corren **desde la raíz del repo**.

## Antes de que lleguen visitas (no se hace en vivo)

1. Levantar: `make up-r2`. Con volúmenes existentes el stack queda sano en ~17-18 s. Con datos limpios: `make reset SCENARIO=r2` (~53-63 s).
2. Confirmar salud real: `make validar` (debe mostrar las dos réplicas en `streaming`).
3. Dejar **tráfico corriendo** para que el dashboard tenga datos (por ejemplo `make test` o el escenario de k6 que corresponda según `documento/runbook.md`). Sin tráfico los paneles de throughput y lag quedan vacíos.
4. Abrir en pestañas separadas:
   - Grafana: http://localhost:3000/d/dbscale-lab/db-scale-lab (usuario/clave del `.env`). Rango "Last 15 minutes", refresco 10 s.
   - Prometheus: http://localhost:9091/alerts
   - Una terminal en la raíz del repo.
5. No se descarga nada de Internet (`--pull never`, verificado: cero "Pull" en los 3 ciclos).

## Guion de 5 minutos

**0:00–0:30 — Pitch.** "Laboratorio de escalado de PostgreSQL: un primario escribe, las réplicas reparten las lecturas, todo sobre una red Docker de 6 subredes con firewall propio." Mostrar el póster o `diagramas/imagen-diagrama.png`.

**0:30–1:30 — Dashboard en vivo.** Paneles "Rol actual de cada nodo" y "Estado de cada nodo (pg_up)": primario + 2 réplicas en verde. Resultado medido (Experimento 1): con 1 réplica el throughput no mejora bajo carga alta; con 2 réplicas, +70% de throughput y p95 entre 43% y 50% menor. Si no hay tiempo, mostrar `capturas/4-curvaDeEscalado/4-comparacionEscenarios.png`.

**1:30–2:30 — Latencia de red y lag.** El lag solo se ve **con carga de escritura** (escenario `escritura-intensiva.js`, ver runbook, Experimento 3); arrancarla ~45 s antes de este paso.
```bash
bash demo/scripts/netem.sh add 50
# mirar el panel "Lag de replicación" (sube a los ~20 s)
bash demo/scripts/netem.sh del
```
Revertir siempre con `del` antes de seguir.

**2:30–3:20 — Caída de una réplica.**
```bash
bash demo/scripts/corte-replica.sh replica2 stop
# ~32-35 s hasta ver el nodo en Down / la alerta ReplicaCaida
bash demo/scripts/corte-replica.sh replica2 start
```
Mostrar que el servicio no se corta (panel de errores en 0). La secuencia no cambia el estado inicial: se puede repetir. Si hay poco tiempo, mostrar las capturas del Plan B en lugar de esperar.

**3:20–4:00 — Failover (solo mostrado).** Deja el stack en otro estado, no se hace en vivo. Mostrar `capturas/6-failoverNormal/`, `6-failoverEnFalla/`, `6-failoverRecuperado/` y decir el número medido: **2,8 s** entre detener el primario y la primera escritura exitosa (corrida limpia, Experimento 4).

**4:00–4:40 — Preguntas.** Seguridad (deny-by-default, segmentación), por qué 1 réplica no alcanza (hardware compartido), limitaciones (failover manual, sin TLS).

**4:40–5:00 — Cierre.** QR del póster al repositorio.

## Variante de 2 minutos

- 0:00–0:20: "Escalamos lecturas de PostgreSQL con réplicas sobre una red segmentada, medimos cuánto mejora y qué se rompe."
- 0:20–1:00: dashboard ya abierto, sin correr nada.
- 1:00–1:40: "Con 2 réplicas, +70% de throughput bajo carga alta; failover manual en 2,8 s" + una captura.
- 1:40–2:00: QR y despedida.

## Plan B

No debuguear en vivo: pasar a capturas reales.

| Si falla... | Mostrar |
|---|---|
| Dashboard no carga | `capturas/2-baseUnicaYMonitoreo/2-dashboardGrafanaBaseUnica-parte1.png` y `-parte2.png` |
| No se ve el lag | `capturas/5-lagVsLatencia/5-lagVsLatencia.png` |
| Caída de réplica poco clara | `capturas/6-replicaCaidaDashboard/` (parte1, parte2) y `capturas/6-alertaFiring/6-alertaFiring.png` |
| Failover | `capturas/6-failoverNormal/`, `6-failoverEnFalla/`, `6-failoverRecuperado/` |
| Curva de escalado | `capturas/4-curvaDeEscalado/` (carga base, estrés, pico, comparación, cpuPrimario) |

## Volver al estado inicial

- Solo netem y corte de réplica: no hace falta nada.
- Tras un failover real: `make reset SCENARIO=r2` y después `docker compose --env-file .env -f demo/docker-compose.yml -p dbscale restart router` (revierte la VIP al primario original). Confirmar con `make validar`.

## Al terminar el día

`make down` baja todos los contenedores. Nunca usar `-v`: borraría los datos de las bases.
