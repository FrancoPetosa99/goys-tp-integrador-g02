# Resumen del proceso (resultado de la entrevista de definición)

## 1. Objetivo
Medir cómo escala una base de datos al pasar de una única instancia de PostgreSQL a un esquema primario + réplicas de lectura, sobre una red segmentada con router Linux, y mostrar los resultados en un dashboard. Integra Redes, Operación y Seguridad (la seguridad es obligatoria). Modalidad A del TP4 de GOYS.

## 2. Usuarios
- Los 5 integrantes: Martín Eliseche, Franco Petosa Ayala, Isabella Bresciani, Agustín Gutierrez Mora, Sofía Kalpin.
- Docentes evaluadores: Emanuel Rodríguez y Osvaldo Falabella.
- Público de la Feria de Redes (martes 17/11/2026).

## 3. Flujo
1. Fases 0 a 6 (ver `plan/fases.md`). Una por vez.
2. El agente construye y verifica; al cerrar la fase indica qué sube cada persona.
3. Cada persona commitea sus archivos en la **rama de la fase actual** (ya creada y pusheada a `origin`) con su identidad y hace push.
4. Cuando están los 5 commits pusheados, se pasa a la fase siguiente.

## 4. Inputs
Propuesta formal, hallazgos del entorno (`conocimiento/entorno.md`) y las convenciones técnicas del proyecto (`plan/fases.md`).

## 5. Outputs
Repo con: `app/` (FastAPI), `demo/` (Compose, router, postgres, k6, prometheus, grafana, scripts), `ansible/`, `capturas/`, `diagramas/`, `documento/` (PDF + runbook), `poster/` (A1), `progreso.md`, `README.md`.

## 6. Reglas principales
- 90% lecturas / 10% escrituras, igual en todas las pruebas.
- Escrituras al primario vía VIP; lecturas a las réplicas (separación en el código, dos pools).
- Demo reproducible y **sin Internet** en la Feria. Todo en Docker Compose, en WSL2 y en la laptop Linux.
- Seguridad mínima: segmentación deny por defecto, usuarios con mínimo privilegio, `pg_hba.conf` restrictivo, secretos fuera del repo. TLS queda como trabajo futuro.
- Los agentes nunca commitean.

## 7. Excepciones y casos límite
- Hardware compartido: primario y réplicas compiten por la misma laptop (declararlo como limitación).
- Replicación asincrónica: lecturas con datos viejos (medirlo y ofrecer `READ_FALLBACK_TO_PRIMARY`).
- Failover manual por script, sin Patroni ni repmgr.
- Si el ruteo entre redes difiere entre WSL2 y la laptop Linux, se resuelve y se documenta.
- Plan de recortes si falta tiempo: backup, failover en vivo (se muestra con capturas), Experimento 3 reducido a 0 y 50 ms, prueba de pico.
- El núcleo que no se recorta: red segmentada con router, base única vs réplicas con dashboard, seguridad mínima.

## 8. Criterios de calidad
- Cada criterio de aceptación verificado con comandos reales.
- Resultados comparables: mismos recursos por contenedor y mismo estado inicial de datos en cada corrida.
- La CPU de la app no es el cuello de botella (verificarlo en las métricas).
- Todo reproducible con un comando; imágenes con versión fija; sin secretos en el repo.
- Cada integrante puede explicar sus archivos en la defensa.

## 9. Riesgos y ambigüedades pendientes
- Publicación de puertos (Grafana/Prometheus) con `nat-unprotected` + `enable_ip_masquerade=false`: a verificar en la fase 1.
- Cómo aplicar rutas en imágenes sin `ip`: sidecar o entrypoint (ver `decisiones-tecnicas.md`).
- Cómo volver al mismo estado inicial de datos entre corridas.
- Comportamiento de Docker en la laptop Linux (versión distinta): verificar en preflight.
- Mecanismo exacto por el que `nat` bloquea el tránsito: **no identificado** (no afirmarlo en el documento).

## 10. Siguiente acción
Ejecutar la Fase 0 y detenerse.
