# Experimento 1 — Curva de escalado (0, 1 y 2 réplicas)

Resultados de las 9 corridas (3 pruebas × 3 escenarios), tal como se midieron. Datos crudos en `k6-results/` (carpeta local, ignorada por git): `<escenario>-<prueba>.summary.txt` (salida completa de k6), `<escenario>-<prueba>.meta.json` (horarios y CPU) y `experimento-1.log` (bitácora corrida por corrida, con horarios en epoch ms y hora local).

## Método

- Antes de **cada** corrida se ejecutó `demo/scripts/reset-estado.sh <escenario>` para volver al mismo estado inicial (seed de 500.000 productos / 10 categorías, sin escrituras previas).
- Los 3 escenarios comparten el mismo límite de CPU por contenedor: PostgreSQL 2 CPUs (primario y cada réplica), API 4 CPUs, k6 4 CPUs — sin cambios respecto a `.env.example` (D11): en ningún escenario hizo falta subir estos límites porque la API y k6 nunca se acercaron a su tope mientras PostgreSQL sí (ver columnas de CPU abajo).
- `cpu_<nodo>` es `rate(container_cpu_usage_seconds_total[D])` evaluado al final de la corrida, con `D` = duración real de la corrida (cAdvisor, vía Prometheus); es el promedio de cores usados durante toda la corrida, no un pico instantáneo.
- La métrica `reads_by_node` viene de `api_reads_by_node_total` (contador propio de la app, por host de lectura), leída al final de cada corrida con réplicas.
- La corrida 1/9 (base/carga-base) la ejecutó una sesión anterior del agente; se usó tal cual porque su resumen y metadatos quedaron completos y verificables (ver bitácora). Las 8 corridas restantes se ejecutaron en esta sesión.

## Tabla de resultados

| Escenario | Prueba | Throughput (req/s) | Latencia p95 | % error HTTP | CPU primario (de 2) | CPU réplica 1 | CPU réplica 2 |
|---|---|---:|---:|---:|---:|---:|---:|
| base (0 réplicas) | carga-base | 18.85 | 429.82 ms | 0.00% | 0.73\* | — | — |
| base (0 réplicas) | estrés | 43.02 | 8.82 s | 0.00% | 1.60 | — | — |
| base (0 réplicas) | pico | 29.62 | 14.34 s | 0.00% | 1.10 | — | — |
| r1 (1 réplica) | carga-base | 19.35 | 228.33 ms | 0.00% | 0.01 | 0.45 | — |
| r1 (1 réplica) | estrés | 42.71 | 8.88 s | 0.00% | 0.01 | 1.55 | — |
| r1 (1 réplica) | pico | 26.73 | 14.38 s | 0.00% | 0.01 | 1.07 | — |
| r2 (2 réplicas) | carga-base | 19.34 | 230.55 ms | 0.00% | 0.01 | 0.23 | 0.22 |
| r2 (2 réplicas) | estrés | **72.81** | **5.05 s** | 0.00%\*\* | 0.02 | 1.20 | 0.75 |
| r2 (2 réplicas) | pico | **45.43** | **7.12 s** | 0.00% | 0.01 | 0.58 | 1.02 |

\* Valor de referencia tomado por la sesión anterior (no reproducido en esta sesión; el resto de la fila es consistente con el resumen completo de k6 guardado).
\*\* `http_req_failed` fue 0.00% (1 de 34997 `checks_total` falló, pero no corresponde a una petición HTTP fallida — ver limitaciones).

## Lectura de los resultados, por hipótesis (propuesta §3.5)

**H1 — agregar réplicas aumenta el máximo de peticiones sostenidas y baja p95/p99.**
Se confirma, pero **solo con 2 réplicas y bajo carga alta**:
- En **carga base** (20 VUs constantes, lejos de saturar cualquier nodo) no hay diferencia perceptible entre 0, 1 y 2 réplicas (18.85 → 19.35 → 19.34 req/s; p95 ~230ms en los tres). A esta carga ningún escenario está limitado por PostgreSQL, así que agregar réplicas no tiene nada que paralelizar.
- En **estrés** y **pico**, pasar de 0 a 1 réplica **no mejora nada** (estrés: 43.02 → 42.71 req/s, p95 8.82s → 8.88s; pico: 29.62 → 26.73 req/s, p95 14.34s → 14.38s). Con una sola réplica, todas las lecturas se concentran en un único nodo que termina tan saturado como lo estaba el primario en el escenario base (CPU de la réplica ~1.55/2 y ~1.07/2, prácticamente igual al CPU del primario en base bajo la misma prueba). El cuello de botella simplemente se mueve de un nodo a otro.
- Pasar de 1 a 2 réplicas sí mejora de forma clara: estrés +70% de throughput (42.71 → 72.81 req/s) y p95 -43% (8.88s → 5.05s); pico +70% (26.73 → 45.43 req/s) y p95 -50% (14.38s → 7.12s).

**Conclusión honesta:** con la mezcla 90/10 de este laboratorio y una sola réplica, el escalado de lectura **no mejora la curva** frente a la base única bajo carga alta — el hardware compartido (ver limitaciones) hace que una réplica equivalga, en capacidad, al primario que reemplaza. La mejora real aparece al **repartir entre 2 nodos** (paralelismo real), no por el solo hecho de separar lecturas de escrituras.

**H2 — el primario libera CPU a medida que se suman réplicas.**
Se confirma con claridad: el CPU del primario cae de ~0.73–1.60/2 (según la prueba, en base) a ~0.01–0.02/2 en cuanto existe al menos una réplica, en los tres escenarios con réplicas. El primario queda prácticamente dedicado a escrituras y a servir la replicación.

**H3, H4, H5:** no corresponden a este experimento (fase 4).

## Reparto de lecturas entre réplicas

- `carga-base` y `pico` en el escenario r2: reparto prácticamente 50/50 (2615/2614 y 3712/3711).
- `estrés` en r2: reparto desigual, 18291/13110 (~58/42). No se identificó la causa puntual de esta asimetría bajo alta concurrencia (podría estar relacionada con el orden de llegada de peticiones concurrentes al índice rotativo de `ReaderPool`, pero no se verificó); se reporta el dato tal cual, sin inventar una explicación.
- En los tres casos con réplicas, el primario no recibió ninguna lectura (0 en `reads_by_node` para la IP del primario), confirmando que el fallback a primario (`READ_FALLBACK_TO_PRIMARY=false`) no se activó.

## Limitaciones observadas

- **Hardware compartido** (declarado desde la propuesta, §10): todos los nodos — primario, réplicas, API, k6, Prometheus — corren en la misma máquina y compiten por el mismo CPU físico. Esto es consistente con que una sola réplica no mejore la curva bajo estrés: no hay un segundo CPU "libre" real, solo un segundo contenedor con su propio límite de 2 CPUs, pero compitiendo por los mismos núcleos físicos que el resto.
- Un único `check` falló en 34.997 de la corrida r2/estrés (0.0029%); no se aisló la petición ni la causa puntual. No afecta la lectura de los resultados (el `http_req_failed` de k6, que mide específicamente fallos HTTP, fue 0.00% en las 9 corridas).
- El reparto de lecturas no fue exactamente 50/50 en la corrida de estrés con 2 réplicas; se reporta sin atribuir causa.
