# Entorno verificado (máquina de desarrollo y demo principal)

Relevado en solo lectura el 9/11/2026. Todo lo de abajo está **verificado**, salvo lo marcado.

## Sistema
- WSL2 (`6.18.33.2-microsoft-standard-WSL2`), 16 CPUs, ~18 GiB de RAM, 5 GiB de swap, ~939 GB de disco libre.
- Sin `.wslconfig` (sin límites explícitos).
- El agente **no tiene sudo**.
- Git 2.53.0. Remoto `origin` por HTTPS, sin `credential.helper`. Identidad global: `MartinEliseche <tinchoeliseche@gmail.com>`. Existe un par de claves SSH sin uso en este remoto.
- Desde la Fase 1, cada fase se trabaja en su propia rama (creada desde `main`, pusheada a `origin`) que se mergea a `main` al cerrarla.

## Docker
- Docker Engine 29.9.2 nativo en WSL2 (no Docker Desktop), Compose v5.6.1, cgroup v2, storage `overlayfs`.
- `iptables v1.8.11 (nf_tables)`. Host: `FORWARD` con política DROP, `br_netfilter` activo (`bridge-nf-call-iptables=1`), tabla `raw` vacía. No existe `/etc/docker/daemon.json`.
- Hay un stack ajeno: `goys-vuln-lab` (no tocar).

## Imágenes con versión fija (ya descargadas)
| Imagen | Tag |
|---|---|
| alpine | `3.24.4` |
| postgres | `17.11` |
| python | `3.12.16-slim` |
| grafana/k6 | `2.3.0` |
| prom/prometheus | `v3.16.0` |
| grafana/grafana | `13.3.0` |
| prometheuscommunity/postgres-exporter | `v0.20.1` |
| gcr.io/cadvisor/cadvisor | `v0.55.1` |

## Puertos del host
- Libres: 3000, 8000, 9090, 9091.
- **5432 ocupado** por un PostgreSQL nativo de WSL. No se publica ninguna base al host, así que no hay conflicto.

## Herramientas del host
- `make` 4.4.1 y `python3` 3.14.4 instalados (la app corre en contenedor, la versión del host no importa).
- **Sin `pip`, `ansible` ni `k6`** en el host. k6 corre en contenedor. Ansible lo instala una persona (`sudo apt install -y ansible`) antes de la fase 5.

## Resultados de las pruebas de red
| Prueba | Resultado |
|---|---|
| `tc qdisc ... netem delay` con solo `NET_ADMIN` | Funciona (imagen alpine con `iproute2`). |
| `sysctl -w net.ipv4.ip_forward=1` dentro del contenedor | **Falla** (`Read-only file system`). Se fija con `sysctls:` en el Compose. |
| `iptables` FORWARD y DNAT (tabla nat) dentro del contenedor | Funciona con `NET_ADMIN`. |
| Ruteo entre dos redes vía contenedor router, red `nat` por defecto | **Falla** (100% de pérdida; el paquete no llega al router). |
| Ídem con `gateway_mode_ipv4=nat-unprotected` | Funciona. |
| Ídem con `nat-unprotected` + `enable_ip_masquerade=false` | Funciona. |
| Ídem con `gateway_mode_ipv4=routed` | Funciona. |
| `iptables -A FORWARD -j DROP` dentro del router (con la variante que funciona) | Corta el tráfico; al quitarla vuelve. El firewall del router tiene control real. |
| cAdvisor | Corre y reporta CPU por contenedor. |
| Publicación de puertos (`ports: "3000:80"`) en una red con `nat-unprotected` + `enable_ip_masquerade=false` | Funciona: `nc -zv -w2 localhost 3000` responde (fase 1, A1.8). |
| Salida a Internet desde nodos en esas redes | **No hay**: `ping -c1 -W2 1.1.1.1` falla desde `t-clientes`, `t-db` y el propio router (fase 1, A1.6). |

## Pendiente de verificar
- Que la laptop Linux del grupo se comporte igual (versión de Docker, `br_netfilter`).
