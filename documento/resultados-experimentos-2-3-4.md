# Experimentos 2, 3 y 4 — Tolerancia a fallos y efecto de la red (Fase 4)

Resultados tal como se midieron. Datos crudos en `k6-results/` (carpeta local, ignorada por git): `experimento-2-3-4.log` (bitácora completa, con horarios en epoch ms y hora local), `experimento2-carga-base.summary.txt`, `experimento3-lag-*ms.summary.txt`, `experimento3-intensivo-*ms.summary.txt`, `raw-*ms-fallback-*.summary.txt`, `failover-writes-v3.log`.

## Método general

- Cada experimento arrancó desde el mismo estado inicial (`demo/scripts/reset-estado.sh r2`).
- Límites de recursos por contenedor sin cambios respecto a `.env.example` (D11).
- Antes de escribir los resultados finales se corrigieron dos errores de procedimiento propios, declarados en cada sección correspondiente: no son parte del comportamiento del sistema, sino de cómo se operó el laboratorio durante la medición.

---

## Experimento 2 — Caída de una réplica en plena carga

**Procedimiento:** con `carga-base.js` corriendo (20 VUs constantes, mezcla 90/10), se ejecutó `demo/scripts/corte-replica.sh replica2 stop` en plena corrida, y luego `... replica2 start` para restaurarla.

### Resultado de la corrida de k6 durante el corte y la restauración

| Métrica | Valor |
|---|---:|
| `http_reqs` | 5800 (19.28 req/s) |
| `http_req_failed` | **0.00%** (0 de 5800) |
| `checks` | 100% exitosos (5800/5800) |
| `http_req_duration` avg / p90 / p95 / **max** | 34.84 ms / 200.21 ms / 232.06 ms / **3 s** |

El único pico de latencia (3 s, un solo request) coincide exactamente con `DB_GET_TIMEOUT_SECONDS=3` (ver "Hallazgos de implementación" más abajo): es el único request que alcanzó a intentar conectarse a la réplica recién caída antes de que la app la marcara como no sana.

**Interpretación (no medición):** al cortar la réplica 2 se observan picos de latencia p95 de 3 a 4 s en los primeros segundos de carga, antes de que la app termine de marcar la réplica como caída — coherente con `DB_CONNECT_TIMEOUT_SECONDS=2` y `DB_GET_TIMEOUT_SECONDS=3` (un intento de conexión fallido más el reintento en el siguiente host puede acercarse a esa ventana). Una vez marcada como caída, las lecturas van todas a `10.30.1.10` y la latencia vuelve a lo normal. Evidencia de este comportamiento: `capturas/6-replicaCaidaDashboard/6-replicaCaidaDashboard-parte1.png` (picos de latencia en curso) y `6-replicaCaidaDashboard-parte2.png` (estado ya estabilizado, con la réplica marcada como caída).

### Detección y reincorporación (app)

- `api_reads_by_node_total`: la tasa de lecturas a `10.31.1.10` (réplica caída) cae a **0.0 req/s** inmediatamente después del corte; `10.30.1.10` (la otra réplica) absorbe el total (**18.2 req/s**, el resto del throughput de la prueba).
- `api_reader_host_healthy{host="10.31.1.10"}` pasa de 1 a 0 tras 3 fallos consecutivos de conexión (umbral `_FAIL_THRESHOLD`), y vuelve a 1 solo (reintento periódico cada `READER_RECHECK_INTERVAL_SECONDS=5`), sin reiniciar la API ni el script.
- El servicio **no se interrumpió** en ningún momento: `http_req_failed=0.00%` durante todo el corte y la restauración.

### Alerta `ReplicaCaida`

Pasa a `pending` ~16 s después del corte y a `firing` ~32 s después; vuelve a `inactive` en menos de 8 s tras restaurar la réplica.

**H4 (la caída de una réplica no interrumpe el servicio): se confirma.**

---

## Experimento 3 — Efecto de la red sobre la replicación

### 3.1 Latencia real agregada (netem)

`demo/scripts/netem.sh` agrega el delay en la interfaz del router hacia `net-db-remota` (detectada en runtime por la IP `10.31.1.254`). El nombre de esa interfaz **varía entre levantadas** del entorno (se observó `eth2` en una corrida y `eth4` en otra): el orden en que Docker crea las interfaces del router no es estable, así que `netem.sh` nunca la busca por nombre fijo, siempre por IP. netem actúa solo en el sentido **router → pg-replica-2** (egress de esa interfaz). Medido con `ping` real desde el router:

| Delay configurado | RTT medido (avg) |
|---:|---:|
| 0 ms | 0.164 ms |
| 50 ms | 50.383 ms |

El RTT medido es aproximadamente igual al delay configurado (no el doble): confirma que netem solo afecta un sentido del tráfico, tal como está documentado en D6.

### 3.2 Lag de replicación vs. latencia

**Elección de métrica.** `postgres-exporter` v0.20.1 expone por defecto `pg_replication_lag_seconds` (calculado en la réplica contra `pg_last_xact_replay_timestamp()`): esta métrica **crece también cuando no hay escrituras nuevas** porque mide tiempo desde la última transacción replicada, no lag de red. Para esta medición se usó en cambio `pg_stat_replication_pg_wal_lsn_diff`, que el mismo exporter expone contra el **primario** (`pg-exporter-p`, vía `pg_stat_replication`): bytes de WAL todavía no confirmados por cada réplica. Esta métrica se mantiene precisa sin escrituras porque el standby manda feedback periódico, no solo al replicar WAL nuevo.

**Primer intento (mezcla estándar 90/10, `carga-base.js`): resultado nulo.** Con la carga de escritura de `carga-base.js` (~1-2 escrituras/s), `pg_stat_replication_pg_wal_lsn_diff` se mantuvo en **0 bytes** en los cuatro niveles de latencia probados (0/20/50/100 ms), incluso tomando el máximo sobre una ventana de 90 s. El volumen de escritura de la mezcla estándar del laboratorio es demasiado bajo para generar un backlog de WAL medible, incluso a 100 ms de latencia inyectada. **Se reporta este resultado nulo tal cual**, sin forzar una conclusión que los datos no muestran.

**Segundo intento (`escritura-intensiva.js`, ~800 escrituras/s, fuera de la mezcla 90/10 estándar — ver decisión nueva en `decisiones-tecnicas.md`):**

| Latencia | WAL sin aplicar — réplica 1 (sin latencia agregada) | WAL sin aplicar — réplica 2 (con latencia agregada) |
|---:|---:|---:|
| 0 ms | 182.712 bytes | 182.712 bytes |
| 20 ms | 10.352 bytes | 16.760 bytes (~1.6×) |
| 50 ms | 32.920 bytes | 418.944 bytes (~12.7×) |
| 100 ms | 328 bytes | 113.904 bytes (~347×) |

En **todos** los niveles ≥20 ms, la réplica con latencia agregada acumuló más WAL sin aplicar que la réplica sin latencia — confirma que netem sí afecta la replicación. La magnitud absoluta **no sigue una progresión limpia** (50 ms dio más lag que 100 ms): se atribuye a hardware compartido (Postgres compite por CPU/disco con 50 VUs de k6 más el resto del stack) y a que `max_over_time` sobre una ventana de 25-40 s depende de cuándo cae el scrape de Prometheus (cada 15 s) relativo al inicio/fin de cada corrida corta. No se afirma una relación cuantitativa limpia que los datos no respaldan.

**Nota sobre la captura final** (`capturas/5-lagVsLatencia/5-lagVsLatencia.png`): corresponde a dos corridas de `escritura-intensiva.js` de 45 s, separadas por 45 s de pausa. A 0 ms se ve un pico transitorio de arranque en **ambas** réplicas (hasta ~17 KiB) que no persiste; a 100 ms se ve un lag **sostenido** solo en `10.31.1.10` (hasta ~31 KiB) mientras `10.30.1.10` se mantiene en 1-3 KiB durante toda la corrida. El throughput de las dos corridas fue comparable (835 req/s a 0 ms, 826 req/s a 100 ms), con 0 errores HTTP en ambas — la diferencia de lag no viene de una diferencia de carga entre las dos corridas.

**H3 (el lag de replicación crece con la latencia del enlace): se confirma de forma cualitativa (la réplica con latencia siempre lagea más que la que no la tiene) pero no de forma cuantitativa limpia (la magnitud no escala monótonamente con el delay configurado).**

### 3.3 Read-after-write

**Primer intento: inválido por error de operación.** Las primeras 4 corridas (0/100 ms × `READ_FALLBACK_TO_PRIMARY` true/false) se hicieron recreando la API sin pasar `READ_DB_HOSTS` junto con `READ_FALLBACK_TO_PRIMARY`: la variable volvió al valor por defecto de base única (`10.20.1.10`), así que **todas las lecturas fueron al primario** y el resultado (100% frescas) no medía nada real. Se repitieron las 4 corridas pasando ambas variables explícitamente.

**Resultado correcto** (`demo/k6/read-after-write.js`: 20 altas+ediciones, 5 lecturas concurrentes — `http.batch` — inmediatamente después de cada escritura; 100 lecturas por corrida y por caso):

| Latencia | `READ_FALLBACK_TO_PRIMARY` | Ausentes (404 tras alta) | Viejas (precio anterior tras edición) | Frescas |
|---:|:---:|---:|---:|---:|
| 0 ms | false | 3 | 3 | 97 |
| 0 ms | true | 0 | 12 | 88 |
| 100 ms | false | 6 | 22 | 78 |
| 100 ms | true | 0 | 14 | 86 |

**Hallazgo principal:** `READ_FALLBACK_TO_PRIMARY=true` elimina por completo las lecturas **ausentes** (0 en ambos niveles de latencia, contra 3-6 sin el flag), pero **no reduce las lecturas viejas** (12-14 con el flag, del mismo orden que 3-22 sin él). La causa es de diseño: el fallback en `GET /products/{id}` (`app/src/routers/products.py`) solo reintenta contra el primario cuando la réplica devuelve **cero filas** (404); si la réplica ya tiene la fila pero con el precio anterior, la consulta es "exitosa" desde el punto de vista de la app, que no tiene ninguna forma de saber que el valor está desactualizado.

A 100 ms sin fallback, tanto ausentes como viejas aumentan respecto a 0 ms (6 vs. 3, 22 vs. 3), consistente con una ventana de carrera más amplia. El caso "0 ms con fallback=true" dio más viejas que "0 ms sin fallback" (12 vs. 3): con muestras de 100 lecturas esto puede ser ruido; no se identificó ni se afirma una causa verificada para esa inversión puntual.

**Corrida adicional, 100 ms / `fallback=false`:** 15 ausentes, 8 viejas, 92 frescas (sobre 115 lecturas). En esa misma corrida, `http_req_failed` fue 6,25% (15 de 240): por default, k6 considera fallida toda respuesta fuera del rango 200-399, así que cada 404 cuenta como `http_req_failed`. En `demo/k6/read-after-write.js` (líneas 71-72), el contador `read_after_write_absent_total` solo suma cuando la respuesta es 404, así que las 15 lecturas ausentes son exactamente 15 respuestas 404 y explican el `http_req_failed` de 6,25% de esta corrida. Es la consecuencia esperada del diseño de la prueba (leer un dato que todavía no llegó da 404, y k6 lo cuenta como fallo), no un error de la app.

**H5 no aplica a este experimento** (es de failover); no corresponde a este punto.

---

## Experimento 4 — Failover manual del primario

**Procedimiento:** `docker stop pg-primary` con un cliente escribiendo en bucle (`PUT /products/1`, un intento nuevo apenas termina el anterior, timeout 3 s por intento), seguido de `demo/scripts/promote-replica-1.sh`.

### Primer intento: bug real encontrado y corregido

`promote-replica-1.sh` fallaba con `pg_ctl: cannot be run as root`: `docker compose exec` sin `-u` corre como `root` en la imagen oficial de `postgres` (el entrypoint oficial arranca como root y baja privilegios recién para el proceso del servidor), y `pg_ctl` se niega a ejecutarse como root. Se corrigió agregando `-u postgres` al `exec`. Esta primera corrida (con la corrección hecha en medio) midió 132.847 ms de punta a punta, **no representativo** porque incluye el tiempo que tardó el debugging, no el procedimiento real.

### Corrida limpia (con el script ya corregido)

| Marca | Epoch (ms) |
|---|---:|
| `docker stop pg-primary` | 1794419304059 |
| `promote-replica-1.sh` arranca | 1794419305024 |
| `pg-replica-1` promovida (`pg_ctl promote` + espera) | 1794419308042 |
| VIP repuntada (DNAT) | 1794419308456 |
| **Primera escritura exitosa** | **1794419306867** |

**Tiempo total medido (`docker stop` → primera escritura exitosa): 2,8 s.**

`promote-replica-1.sh` en sí mismo tardó 2,1-3,4 s en las 3 corridas (consistente). Una corrida anterior (durante el debugging, con el entorno ya en un estado distinto) mostró un gap de 24,5 s entre "DNAT listo" y "primera escritura exitosa": ese componente depende de si el pool de conexiones de la API tenía conexiones abiertas hacia el primario viejo en el momento exacto de la caída — si las tenía, `psycopg_pool` tarda en descartarlas y abrir conexiones nuevas hacia el destino nuevo de la VIP; si no, la recuperación es casi inmediata. El tiempo de promoción de PostgreSQL en sí (`pg_ctl promote`) fue siempre sub-3 s en las 3 corridas.

**Limitación metodológica declarada:** el cliente de escritura no es un proceso persistente (cada intento es un `docker exec` nuevo con un intérprete Python corto); el timestamp registrado es el de antes de lanzar ese `exec`, no el de la conexión TCP real. Puede haber uno o dos segundos de sesgo por el overhead de arrancar el `exec` bajo carga.

### Consecuencias verificadas de D8 (no reincorporación del primario caído)

- `pg_stat_replication` consultado en el **nuevo** primario (`pg-replica-1`, ahora `10.30.1.10`) muestra **0 filas**: `pg-replica-2` nunca se reconectó al nuevo primario. Sigue intentando (sin éxito) contra el primario original, que está caído.
- El dashboard, vía `pg_replication_is_replica`, refleja el cambio de rol automáticamente: `pg-exporter-1` pasa de 1 (réplica) a 0 (primario) apenas se promueve, sin que nadie edite el dashboard.
- `PrimarioCaido` pasa a `firing` (el exporter dedicado al primario original, `pg-exporter-p`, sigue apuntando a la IP vieja, que está caída).

**Restauración al estado inicial:** `reset-estado.sh r2` (recrea primario y réplicas desde cero) **más** `docker compose restart router` (reaplica `firewall.sh`, que tiene el DNAT hardcodeado hacia el primario original — revierte la VIP sin tocar el archivo) **más** recrear `api` (el pool de conexiones de la API no recupera solo tras el restart del router en un tiempo razonable; se verificó que un `docker compose up -d --force-recreate api sc-api` sí la deja sana de inmediato).

**H5 (el failover manual restaura las escrituras en un tiempo acotado y medible): se confirma — 2,8 s en la corrida limpia, dominado por `promote-replica-1.sh` (2-3,5 s) más un componente variable de reconexión del pool de la app.**

---

## Hallazgos de implementación (no eran parte de las hipótesis, pero afectan la lectura de los resultados)

1. **Bug de timeout de conexión (app, `app/src/config.py`/`db.py`).** Sin `connect_timeout` en la conninfo ni un timeout corto a nivel pool, un host de lectura inalcanzable (contenedor parado, sin RST ni ICMP) colgaba cada intento de conexión hasta ~30 s (el default de `psycopg_pool`), bloqueando el worker de gunicorn que atendía ese request — verificado en el Experimento 2: con 20 VUs de carga, esto dejó a la API "unhealthy" y sin responder a Prometheus. Se corrigió agregando `connect_timeout=2` a la conninfo y `timeout=3` a nivel pool (`DB_CONNECT_TIMEOUT_SECONDS`, `DB_GET_TIMEOUT_SECONDS`, nuevas variables de entorno). Con el fix, el peor caso por request es 3 s (verificado: es exactamente el `max` de latencia en el Experimento 2), no 30 s.
2. **Namespace de red de los sidecars (D5).** Si se para/arranca el nodo principal de un par sidecar (`pg-primary`+`sc-pg-primary`, `prometheus`+`sc-prometheus`) **sin** tocar el sidecar, el namespace de red se puede reconstruir al reiniciar el nodo principal y la ruta hacia el router (D5) no se reaplica — el nodo queda "Up" pero sin poder alcanzar otras subredes. Pasó dos veces durante esta fase (al verificar `PrimarioCaido` y al recargar `alerts.yml` reiniciando solo `prometheus`), diagnosticado con `ip route` dentro del sidecar y corregido reiniciando el sidecar también. Los scripts de esta fase (`corte-replica.sh`, `promote-replica-1.sh`) siempre operan sobre el nodo **y** su sidecar juntos; un reinicio manual de un nodo con sidecar durante la demo tiene que incluir el sidecar.
3. **Recreación de `api` sin pasar todas las variables de escenario.** `docker compose up -d --force-recreate api` sin pasar `READ_DB_HOSTS` (o sin pasar `READ_FALLBACK_TO_PRIMARY` junto con él) hace que esa variable vuelva al valor de `.env` (el de base única), no al del escenario activo. Pasó una vez durante el Experimento 3 (read-after-write) e invalidó 4 corridas, que se repitieron.

## Limitaciones declaradas

- **Hardware compartido** (ya declarado desde la propuesta): todos los nodos compiten por el mismo CPU físico. Explica la falta de progresión limpia en el lag medido en el Experimento 3.
- **Failover manual y sin TLS**: sin cambios respecto a lo ya declarado (D8, D15).
- El cliente de medición del Experimento 4 no es un proceso persistente (ver nota metodológica arriba): el número de 2,8 s puede tener hasta 1-2 s de sesgo por el overhead de `docker exec`.
- La prueba de lag del Experimento 3 usó `escritura-intensiva.js` (~800 escrituras/s), fuera de la mezcla 90/10 estándar del laboratorio, porque esa mezcla no genera suficiente volumen de escritura para que el lag sea medible — se declara explícitamente como una desviación puntual, documentada en `decisiones-tecnicas.md`.
