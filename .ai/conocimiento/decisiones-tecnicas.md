# Decisiones técnicas

Estado: **Verificado** (probado en esta máquina), **Decidido** (acordado, aún sin probar) o **A verificar**.

| # | Decisión | Estado |
|---|---|---|
| D1 | La separación lectura/escritura vive en el código de la app (dos pools), no en un proxy. Escrituras a la VIP del primario; lecturas con round-robin entre réplicas. Con base única, el pool de lectura apunta al primario. | Decidido |
| D2 | Un contenedor router Linux (alpine + `iproute2` + `iptables`, imagen propia construida de antemano) une las 6 subredes. Política `FORWARD DROP`, `ESTABLISHED,RELATED` permitido y solo las reglas de la propuesta (§2.4). | Decidido |
| D3 | Redes Docker con `driver_opts`: `com.docker.network.bridge.gateway_mode_ipv4: nat-unprotected` y `com.docker.network.bridge.enable_ip_masquerade: "false"`. Gateway de Docker en `.253`, router en `.254`. | Ruteo **verificado**; publicación de puertos y falta de salida a Internet **a verificar en fase 1** |
| D3b | Plan B de D3: `gateway_mode_ipv4: routed` en las redes de datos, y para Grafana y Prometheus una red extra `net-ui` en modo `nat` para publicar sus puertos. | A verificar solo si D3 falla |
| D4 | `net.ipv4.ip_forward=1` y `rp_filter=0` del router se fijan con `sysctls:` en el Compose (no se puede desde el contenedor). | Verificado |
| D5 | Todo nodo apunta su ruta por defecto al router de su subred (`ip route replace default via <subred>.254`). Nodos con `ip` disponible: entrypoint con `NET_ADMIN`. Imágenes sin `ip` (comprobar con `docker run --rm --entrypoint which <img> ip`): sidecar `alpine:3.24.4` con `network_mode: "service:<nodo>"` y `NET_ADMIN` (sidecar que comparte el namespace de red del nodo). Nunca darle `NET_ADMIN` a PostgreSQL. | Decidido |
| D6 | Latencia con `tc netem` en la interfaz del router que da a `net-db-remota`. | Verificado (la herramienta); a probar en fase 4 |
| D7 | VIP de escritura `10.20.1.100:5432`: DNAT en el router hacia el primario activo. El failover cambia el destino del DNAT. La IP de origen se conserva (sin SNAT), así que `pg_hba.conf` puede filtrar por subred. | Decidido |
| D8 | Failover manual por script (`pg_ctl promote` + cambio del DNAT). Sin Patroni ni repmgr. No se reincorpora el primario caído. | Decidido |
| D9 | Puertos publicados al host: Grafana 3000 y Prometheus 9091. **Ninguna base de datos se publica.** | Decidido |
| D10 | Imágenes con versión fija (ver `entorno.md`). Prohibido `latest`. Las imágenes propias (router, app) se construyen antes de la demo; la demo no necesita Internet. | Decidido |
| D11 | Límites fijos por contenedor (`cpus`, `mem_limit`) idénticos en todas las corridas. Valores iniciales en `.env.example`: PostgreSQL 2 CPUs / 3g por nodo, API 4 CPUs, k6 4 CPUs. Se ajustan tras medir. | Decidido |
| D12 | Seed: 10 categorías y ~500.000 productos (`generate_series`), ajustable. Cada corrida arranca desde el mismo estado de datos: definir y documentar cómo se restaura (por ejemplo, dump del seed). | A definir en fase 3 |
| D13 | Secretos solo en `.env` (ignorado por git) con `.env.example` ficticio. La contraseña de Grafana también va en `.env`, nunca hardcodeada en el Compose. | Decidido |
| D14 | k6 envía métricas a Prometheus por remote write (`experimental-prometheus-rw`; Prometheus con `--web.enable-remote-write-receiver`). Confirmar el nombre del output para k6 2.3.0. | A verificar en fase 3 |
| D15 | Fuera de alcance: TLS entre app y base y entre base y réplicas (se declara como trabajo futuro). | Decidido |
| D16 | Monitoreo: 3 `postgres-exporter` (usuario `monitor`), cAdvisor, métricas de la app en `/metrics`. Alertas: `PrimarioCaido`, `ReplicaCaida`, `LagAlto`. Dashboard `DB Scale Lab`. | Decidido |

## Sobre el comportamiento del ruteo entre redes (para el documento)
Se observó que con la red `nat` por defecto el tráfico de tránsito hacia otra subred, enviado al router-contenedor, no llega al router; con `nat-unprotected` o `routed` sí. La tabla `raw` del host estaba vacía y `nf_call_iptables` por bridge valía 0, así que **no se identificó el mecanismo exacto**. En el documento se describe el efecto observado, no una causa.
