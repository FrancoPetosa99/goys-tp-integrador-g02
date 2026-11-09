# Propuesta de Proyecto para el TP4 Integrador — GOYS (UTN FR La Plata)

> Propuesta formal del grupo para el Trabajo Práctico Integrador (TP4). Describe la arquitectura del laboratorio, el stack, la cobertura de las tres áreas de la materia, el plan de experimentos y el cronograma.
> **Estado del documento: PROPUESTA. La implementación está pendiente.** Cada componente indica su estado (todos figuran como *Planificado*).

| Dato | Valor |
|---|---|
| **Grupo** | 02 |
| **Integrantes** | Petosa Ayala, Franco · Bresciani, Isabella · Eliseche, Martín · Gutierrez Mora, Agustín · Kalpin, Sofía |
| **Modalidad** | A — Proyecto de Desarrollo |
| **Entrega de la propuesta** | martes 10/11/2026 |
| **Feria de Redes** | martes 17/11/2026 |

---

## 📋 Resumen y Criterios de Selección

| # | Propuesta | Stack Principal | Consumo RAM estimado |
|---|---|---|:---:|
| **1** | **Escalado y alta disponibilidad de PostgreSQL con réplicas de lectura, sobre una red segmentada** | Docker Compose + PostgreSQL 17 + Python (FastAPI) + router Linux + k6 + Prometheus/Grafana + Ansible | ~6-8 GB |

> **Por qué esta propuesta.** Entrega las tres áreas de la materia con un único `docker compose up`, sin depender de Internet (requisito de la estación de la Feria), y produce **resultados medibles y comparables** (curvas de escalado, lag de replicación, tiempo de recuperación) que se pueden mostrar en un dashboard y en el póster.

---

## 🌐 Propuesta: Escalado de base de datos con réplicas de lectura, tolerancia a fallos y efecto de la red

### 1. Concepto y Objetivos

Una base de datos única es, al mismo tiempo, el **techo de rendimiento** y el **punto único de falla** de una aplicación. El proyecto construye un laboratorio que simula una organización con una **sede principal** y una **sede remota**, y mide cómo cambia el comportamiento del sistema cuando se pasa de una base única a un esquema **primario + réplicas**: las escrituras van siempre al nodo primario y las lecturas se reparten entre las réplicas, de modo que el primario se mantiene disponible.

**Objetivos del laboratorio:**

- Construir una **red segmentada** (6 subredes) unida por un **router Linux** que aplica las reglas de acceso entre segmentos.
- Desplegar una **aplicación de prueba en Python** (8 endpoints, 2 tablas relacionadas) que separa lecturas y escrituras en el código mediante **dos pools de conexión**.
- Medir una **línea base** con una única base de datos mediante pruebas de carga, estrés y pico.
- Configurar **replicación en streaming** de PostgreSQL y repetir **exactamente las mismas pruebas** con 1 y 2 réplicas, para obtener una **curva de escalado**.
- Medir el **efecto de la red** sobre la replicación: inyectar latencia en el enlace de la sede remota y observar el lag.
- Demostrar **tolerancia a fallos**: caída de una réplica en plena carga y **failover manual** del primario, midiendo el tiempo de recuperación.
- Mostrar los resultados en un **dashboard** (Prometheus + Grafana) y dejar la evidencia versionada en el repositorio.
- Mantener la demo **reproducible y sin dependencia de Internet**.

> **Alcance y aplicación de prueba.** La carga se genera sobre una aplicación propia y acotada, construida con el único fin de medir. No se usa la API del proyecto final de otra materia porque tiene autenticación, triggers y restricciones que dificultan controlar la mezcla de tráfico, y porque su proporción de escrituras (mayoritaria) no permite ver el efecto de las réplicas de lectura. Esta propuesta formaliza la idea presentada al profesor Emanuel Rodríguez: **medir el escalado de una base de datos con réplicas y comparar resultados**.

---

### 2. Arquitectura

#### 2.1 Diagrama de red

```
 net-clientes 10.50.1.0/24        net-mon 10.40.1.0/24
 +-----------------+              +-------------------------------+
 |  k6 (.10)       |              | prometheus (.20)  grafana (.21)|
 | generador carga |              | pg-exporter-p/1/2 (.31-.33)   |
 +--------+--------+              | cadvisor (.40)                |
          |                       +---------------+---------------+
          |                                       |
          |         +---------------------------+ |
          +-------->|         ROUTER            |<+
                    |  Linux (ip_forward)       |
 net-app 10.10.1.0/24  iptables + tc netem      |
 +--------------+   |  .254 en las 6 subredes   |
 | api (.10)    |<->|  VIP escritura 10.20.1.100|
 | FastAPI      |   +------+-------+-------+----+
 +--------------+          |       |       |
                           |       |       |
        net-db-primaria    |  net-db-local |   net-db-remota
        10.20.1.0/24       |  10.30.1.0/24 |   10.31.1.0/24
        +-------------+    |  +-----------+|   +-------------+
        | pg-primary  |<---+  |pg-replica-1|+   | pg-replica-2|
        |   (.10)     |       |   (.10)    |    |   (.10)     |
        +-------------+       +-----------+     +-------------+
             escrituras          lecturas         lecturas
                                              (enlace con latencia
                                               inyectada: tc netem)
```

*Figura 1: Topología del laboratorio. Las réplicas se conectan al primario a través del router (replicación en streaming).*

#### 2.2 Nodos del laboratorio

| Nodo | Rol | IP principal | Red | Estado |
|---|---|---|---|---|
| `router` | Router entre segmentos, firewall, VIP de escritura, inyector de latencia | `.254` en cada subred | las 6 | Planificado |
| `api` | Aplicación Python (FastAPI) con pool de escritura y pool de lectura | `10.10.1.10` | `net-app` | Planificado |
| `pg-primary` | PostgreSQL 17, nodo primario (escrituras) | `10.20.1.10` | `net-db-primaria` | Planificado |
| `pg-replica-1` | PostgreSQL 17, réplica en la sede principal (lecturas) | `10.30.1.10` | `net-db-local` | Planificado |
| `pg-replica-2` | PostgreSQL 17, réplica en la sede remota (lecturas, con latencia) | `10.31.1.10` | `net-db-remota` | Planificado |
| `k6` | Generador de carga | `10.50.1.10` | `net-clientes` | Planificado |
| `prometheus` | Recolección de métricas y reglas de alerta | `10.40.1.20` | `net-mon` | Planificado |
| `grafana` | Dashboard de resultados | `10.40.1.21` | `net-mon` | Planificado |
| `pg-exporter-p/1/2` | Exporters de PostgreSQL (uno por nodo) | `10.40.1.31` / `.32` / `.33` | `net-mon` | Planificado |
| `cadvisor` | Uso de CPU y memoria por contenedor | `10.40.1.40` | `net-mon` | Planificado |

#### 2.3 Redes definidas en `demo/docker-compose.yml`

| Red | Subnet | Gateway Docker | Propósito |
|---|---|---|---|
| `net-clientes` | `10.50.1.0/24` | `.253` | Clientes externos (k6) |
| `net-app` | `10.10.1.0/24` | `.253` | Aplicación |
| `net-db-primaria` | `10.20.1.0/24` | `.253` | Nodo primario |
| `net-db-local` | `10.30.1.0/24` | `.253` | Réplica de la sede principal |
| `net-db-remota` | `10.31.1.0/24` | `.253` | Réplica de la sede remota |
| `net-mon` | `10.40.1.0/24` | `.253` | Monitoreo |

> **Decisiones de diseño (a validar en la implementación):**
> - El gateway de Docker se fija en `.253` para reservar `.254` al router.
> - Las redes se declaran con `com.docker.network.bridge.enable_ip_masquerade: "false"`: no hay NAT ni salida a Internet. Se elige este mecanismo en lugar de `internal: true` porque este último puede bloquear el ruteo L3 entre redes Docker (experiencia documentada por el grupo modelo del TP anterior).
> - Cada contenedor de un segmento agrega una ruta hacia las demás subredes vía `.254` en su `entrypoint` (requiere `NET_ADMIN`), de modo que **todo el tráfico entre segmentos pasa por el router**.

#### 2.4 Router y política de acceso (firewall)

El router es un contenedor Linux con `net.ipv4.ip_forward=1`, `iptables` y `tc`. La política es **deny por defecto** (`FORWARD DROP`) con `ESTABLISHED,RELATED` permitido y solo estas reglas de entrada:

| Origen | Destino | Puerto | Motivo |
|---|---|---|---|
| `net-clientes` (k6) | `api` | 8000/tcp | Tráfico de prueba hacia la API |
| `net-clientes` (k6) | `prometheus` | 9090/tcp | Envío de métricas de k6 (remote write) |
| `api` | `pg-primary` (vía VIP), `pg-replica-1`, `pg-replica-2` | 5432/tcp | Escrituras y lecturas |
| `pg-replica-1`, `pg-replica-2` | `pg-primary` | 5432/tcp | Replicación en streaming |
| `net-mon` (exporters) | los 3 nodos PostgreSQL | 5432/tcp | Métricas de base de datos |
| `net-mon` (prometheus) | `api` | 8000/tcp | Métricas de la aplicación (`/metrics`) |

Todo lo demás se descarta. En particular, **las redes de base de datos no pueden iniciar conexiones hacia la aplicación ni hacia los clientes**, y los clientes no pueden alcanzar ninguna base de datos.

**VIP de escritura:** la aplicación escribe contra `10.20.1.100:5432`, una dirección virtual del router que hace **DNAT** al nodo primario activo. Esto permite el *failover* sin tocar la aplicación: el script de promoción cambia el destino del DNAT hacia la réplica promovida (§3.4).

#### 2.5 PostgreSQL y replicación

| Parámetro | Valor |
|---|---|
| Versión | PostgreSQL 17 (imagen oficial) |
| Replicación | Streaming física, **asincrónica**, réplicas en `hot_standby` (aceptan solo lecturas) |
| Alta de réplicas | `pg_basebackup -R` desde el primario |
| Escenarios | Perfiles de Compose: base única, 1 réplica, 2 réplicas |
| Recursos | Límites fijos por contenedor (`cpus`, `mem_limit`) para que cada nodo tenga el mismo presupuesto en todas las pruebas |
| Datos semilla | ~500.000 productos y ~10 categorías (a ajustar según el hardware) |

**Modelo de datos (2 tablas relacionadas):**

| Tabla | Campos principales | Relación |
|---|---|---|
| `categories` | `id`, `name` (único), `description`, `created_at` | — |
| `products` | `id`, `category_id`, `name`, `price`, `stock`, `created_at`, `updated_at` | `category_id` → `categories.id` |

Índices: PK de ambas, `products(category_id, price)` para el filtro del listado.

#### 2.6 Aplicación de prueba (Python)

- **Stack:** FastAPI con varios *workers* (gunicorn + uvicorn) y pool de conexiones psycopg.
- **Separación lectura/escritura en el código:** dos pools. El **pool de escritura** apunta a la VIP del primario; el **pool de lectura** reparte (round-robin) entre las réplicas disponibles. Con una sola base, el pool de lectura apunta al primario.
- **Detección de fallos de réplica:** si una réplica falla o supera un tiempo de espera, se la marca como no disponible y se reintenta la lectura en otra réplica (o en el primario si no quedan réplicas).
- **Consistencia read-after-write:** `GET /products/{id}` puede ir con *fallback* al primario si la réplica todavía no tiene la fila (bandera `READ_FALLBACK_TO_PRIMARY`, activable para las pruebas de lag).
- **Configuración por variables de entorno**, sin secretos en el código.
- `GET /health` y `GET /metrics` (Prometheus) para observabilidad. No cuentan dentro de los 8 endpoints de negocio.

#### 2.7 Endpoints de negocio

| # | Endpoint | Tipo | Pool | Rol en las pruebas |
|---|---|---|---|---|
| 1 | `POST /categories` | Escritura | Primario | Alta simple |
| 2 | `GET /categories` | Lectura pesada | Réplicas | Listado con cantidad de productos por categoría (agregación + join) |
| 3 | `GET /categories/{id}` | Lectura liviana | Réplicas | Búsqueda por clave primaria |
| 4 | `PUT /categories/{id}` | Escritura | Primario | Edición |
| 5 | `POST /products` | Escritura | Primario | Alta con clave foránea a categoría |
| 6 | `GET /products` | Lectura media | Réplicas | Filtro por categoría y rango de precio, con paginación |
| 7 | `GET /products/{id}` | Lectura liviana | Réplicas | Búsqueda por PK con join a la categoría |
| 8 | `PUT /products/{id}` | Escritura | Primario | Edición de precio y stock |

> No se incluye `DELETE`: borrar durante una prueba de estrés complica los datos semilla y no aporta a lo que se mide.

#### 2.8 Monitoreo y observabilidad (Prometheus + Grafana)

| Fuente | Métricas | Para qué |
|---|---|---|
| **k6** (remote write) | Peticiones por segundo, latencia p50/p95/p99, tasa de errores, usuarios virtuales | Resultado de cada prueba |
| **postgres_exporter** (×3) | Lag de replicación, conexiones, transacciones por segundo, estado de cada nodo | Salud de la replicación |
| **cAdvisor** | CPU y memoria por contenedor | **CPU del primario** con y sin réplicas |
| **API** (`/metrics`) | Estado de los pools, réplicas marcadas como no disponibles | Comportamiento de la aplicación |

- **Dashboard** "DB Scale Lab", provisionado automáticamente: comparación entre escenarios, lag de replicación en el tiempo y estado de los nodos.
- **Alertas:** `PrimarioCaido`, `ReplicaCaida` y `LagAlto`.

---

### 3. Experimentos y plan de pruebas

**Mezcla de tráfico (idéntica en todas las pruebas): 90% lecturas / 10% escrituras.**

| Endpoint | Peso |
|---|:---:|
| `GET /products` (filtro + paginación) | 40% |
| `GET /products/{id}` | 30% |
| `GET /categories/{id}` | 10% |
| `GET /categories` (agregación) | 10% |
| `POST /products` | 5% |
| `PUT /products/{id}` | 4% |
| `PUT /categories/{id}` | 0,5% |
| `POST /categories` | 0,5% |

#### 3.1 Experimento 1 — Curva de escalado (0, 1 y 2 réplicas)

Tres pruebas k6, **repetidas sin cambios** con 0, 1 y 2 réplicas (9 corridas):

| Prueba | Descripción | Duración aprox. |
|---|---|:---:|
| Carga base | Usuarios virtuales constantes, comportamiento normal | ~5 min |
| Estrés escalonado | La carga sube por etapas hasta que la latencia o los errores se disparan: busca el **punto de quiebre** | ~8 min |
| Pico (*spike*) | Salto brusco de carga y vuelta a lo normal: mide la **recuperación** | ~3 min |

**Métricas comparadas:** peticiones por segundo máximas sostenidas, latencia p50/p95/p99, tasa de errores y CPU del primario.

#### 3.2 Experimento 2 — Caída de una réplica en plena carga

Durante la prueba de estrés se detiene una réplica (`docker stop pg-replica-2`). Se mide el impacto en latencia y errores, cuánto tarda la aplicación en dejar de enviarle lecturas y que el servicio **no se interrumpe** mientras quede otro nodo que atienda lecturas.

#### 3.3 Experimento 3 — Efecto de la red sobre la replicación

Se inyecta latencia en el enlace de la sede remota con `tc netem` (por ejemplo 0, 20, 50 y 100 ms) y se mide el **lag de replicación** de `pg-replica-2` (`pg_stat_replication`) con carga de escritura constante. Se agrega una **prueba corta de read-after-write** (escribir y leer inmediatamente) con y sin `READ_FALLBACK_TO_PRIMARY`, para mostrar el costo de leer datos desactualizados.

#### 3.4 Experimento 4 — Failover manual del primario

1. Se aplica carga de lectura y escritura.
2. Se detiene el primario (`docker stop pg-primary`).
3. Un script promueve la réplica local (`pg_ctl promote`) y actualiza el DNAT de la VIP hacia ella.
4. Se mide el **tiempo de recuperación** (desde la caída hasta la primera escritura exitosa) y los errores durante ese lapso.

> El failover es **manual y por script, no automático**. No se usan herramientas tipo Patroni o repmgr (ver §8).

#### 3.5 Hipótesis a contrastar

| # | Hipótesis | Cómo se valida |
|---|---|---|
| H1 | Con 90% de lecturas, agregar réplicas aumenta el máximo de peticiones sostenidas y baja p95/p99 | Experimento 1 |
| H2 | El primario libera CPU a medida que se suman réplicas | Experimento 1 (cAdvisor) |
| H3 | El lag de replicación crece con la latencia del enlace | Experimento 3 |
| H4 | La caída de una réplica no interrumpe el servicio | Experimento 2 |
| H5 | El failover manual restaura las escrituras en un tiempo acotado y medible | Experimento 4 |

Si los datos **no** respaldan una hipótesis, se informa tal cual y se analiza la causa (ver limitaciones en §8).

---

### 4. Cobertura de las 3 Áreas de la Materia

| Área | Qué cubre en este TP | Estado |
|---|---|---|
| 🔌 **Redes** | 6 subredes unidas por un router Linux, ruteo L3 entre segmentos, VIP con DNAT, firewall por segmento, latencia inyectada con `tc netem`, replicación sobre la red segmentada | Planificado |
| ⚙️ **Operación (Gestión)** | Despliegue reproducible con Docker Compose (perfiles por escenario), automatización con Ansible, monitoreo con Prometheus + Grafana, pruebas de carga con k6, runbook de failover | Planificado |
| 🛡️ **Seguridad** | Segmentación de red con política deny por defecto, usuarios de base de datos con mínimo privilegio, `pg_hba.conf` restrictivo, secretos fuera del repositorio | Planificado |

> **Seguridad (no opcional).** Se demuestra con pruebas concretas de lo permitido y lo bloqueado (ver §6 y §3 del documento final).

---

### 5. Automatización (Ansible)

Versión mínima, con playbooks numerados y sus salidas guardadas como evidencia en `capturas/7-automatizacionAnsible/`:

| Playbook | Función |
|---|---|
| `01-preflight.yml` | Verifica Docker, versiones, puertos libres y recursos disponibles |
| `02-validar-replicacion.yml` | Confirma que las réplicas están en `streaming`, mide el lag y valida los permisos de cada usuario |
| `03-backup.yml` | Respalda configuraciones y hace un volcado de la base en `backups/` |

---

### 6. Seguridad

| Control | Implementación | Prueba que lo demuestra |
|---|---|---|
| **Segmentación de red** | Router con `FORWARD DROP` y reglas explícitas (§2.4) | Desde `k6`, intentar conectar a `5432` de cualquier base falla |
| **Mínimo privilegio en la base** | `app_writer` (SELECT/INSERT/UPDATE sobre las tablas), `app_reader` (solo SELECT), `replicator` (solo REPLICATION), `monitor` (rol `pg_monitor`) | Con `app_reader`, un `INSERT` falla; con `monitor`, no se puede leer el contenido de las tablas |
| **Acceso restringido** | `pg_hba.conf` solo acepta usuarios y subredes esperados, con `scram-sha-256` | Una conexión desde una subred no autorizada es rechazada |
| **Sin salida a Internet** | `enable_ip_masquerade: "false"` y sin ruta externa | Un `curl` externo desde cualquier contenedor falla |
| **Secretos fuera del repo** | `.env` ignorado por git, con `.env.example` de muestra | Revisión del repositorio |

> **Fuera de alcance (trabajo futuro):** cifrado TLS entre la aplicación y la base de datos, y entre la base y sus réplicas.

---

### 7. Stack Tecnológico

| Capa | Tecnología | Rol en el TP |
|---|---|---|
| Orquestación | Docker Compose (perfiles) | Levanta cada escenario con un comando |
| Ruteo y firewall | Linux (`ip_forward`, `iptables`) | Router entre segmentos, política de acceso, VIP con DNAT |
| Emulación de red | `tc netem` | Latencia en el enlace de la sede remota |
| Base de datos | PostgreSQL 17 | Primario y réplicas con streaming |
| Aplicación | Python, FastAPI, psycopg | App de prueba con dos pools |
| Carga | k6 | Escenarios de carga, estrés y pico |
| Monitoreo | Prometheus, Grafana, postgres_exporter, cAdvisor | Dashboard y alertas |
| Automatización | Ansible | Preflight, validación y backups |

---

### 8. Riesgos y Limitaciones

| Riesgo / limitación | Impacto | Mitigación |
|---|---|---|
| **Todos los nodos comparten el mismo hardware** (CPU, disco y memoria de la laptop) | Las réplicas compiten con el primario por los mismos recursos, así que la mejora puede ser menor que en un entorno con servidores separados | Límites fijos de CPU y memoria por contenedor; se documenta como limitación y se interpretan los resultados con ese contexto |
| La aplicación Python se satura antes que la base | El cuello de botella medido no sería el de la base | Varios workers y verificación en las métricas de que la CPU de la app no es el límite |
| El ruteo entre redes Docker puede comportarse distinto según el host (WSL2 vs. Linux) | La demo funcionaría en una laptop y no en la otra | Probar el escenario completo en ambas laptops antes del ensayo |
| Replicación asincrónica | Una lectura inmediata tras una escritura puede ver datos viejos | Medirlo (Experimento 3) y ofrecer `READ_FALLBACK_TO_PRIMARY` |
| Failover manual | No hay promoción automática ni reincorporación del primario caído | Se documenta en el runbook; herramientas de HA automática quedan como trabajo futuro |
| Sin TLS entre aplicación y base | Tráfico sin cifrar dentro del laboratorio | Aislamiento por segmentación; se declara como mejora futura |
| Tiempo (9 días hasta la Feria) | No llegar a todos los experimentos | Núcleo que no se recorta: red segmentada con router, base única vs. réplicas con dashboard y seguridad mínima. Si el tiempo aprieta se recortan, en este orden: backup (`03-backup.yml`), failover en vivo (se muestra con capturas del dashboard), Experimento 3 reducido a dos latencias y prueba de pico |

---

### 9. Referencias

- PostgreSQL Global Development Group. (2024). *PostgreSQL 17 Documentation — High Availability, Load Balancing, and Replication*. https://www.postgresql.org/docs/17/high-availability.html
- Grafana Labs. *k6 documentation*. https://grafana.com/docs/k6/latest/
- Prometheus Authors. *Prometheus documentation*. https://prometheus.io/docs/
- Prometheus Community. *postgres_exporter*. https://github.com/prometheus-community/postgres_exporter
- Linux man-pages. *tc-netem(8)*. https://man7.org/linux/man-pages/man8/tc-netem.8.html
- Ramírez, S. *FastAPI documentation*. https://fastapi.tiangolo.com/

---

## 📌 Notas Finales

- El laboratorio **no depende de Internet**: todas las imágenes se descargan de antemano y no hay salida desde las redes del laboratorio.
- La **separación de lecturas y escrituras vive en el código de la aplicación** (dos pools), no en un proxy: es más simple de explicar y de defender.
- Los resultados se comparan **entre escenarios idénticos en carga y recursos**, y las limitaciones del entorno (hardware compartido) se declaran de forma explícita.
- Todo componente descrito aquí figura como *Planificado*: el documento final y el póster reflejarán únicamente lo efectivamente implementado y medido.
