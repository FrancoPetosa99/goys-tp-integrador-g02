# Makefile — DB Scale Lab (Fase 5). Orquesta el ciclo de vida completo del
# laboratorio: preflight, los 3 escenarios, pruebas de carga, validación de
# replicación, backup, reset y apagado. Todos los `docker compose` corren
# desde demo/ con --env-file ../.env y "up -d" sin lista de servicios (así
# sube también el router, que no tiene profile). "down" nunca usa "-v": los
# volúmenes de datos quedan intactos.

SHELL := /bin/bash
.DEFAULT_GOAL := help

DEMO_DIR := demo
COMPOSE := docker compose --env-file ../.env
ANSIBLE_DIR := ansible
SCENARIO ?= r2

.PHONY: help preflight up-base up-r1 up-r2 test validar backup reset down

help: ## Lista los targets disponibles
	@echo "DB Scale Lab — targets disponibles:"
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN{FS=":.*## "}{printf "  make %-10s %s\n", $$1, $$2}'
	@echo ""
	@echo "Notas:"
	@echo "  - 'validar' requiere el escenario r2 arriba (ambas réplicas)."
	@echo "  - 'reset' usa SCENARIO (por defecto r2): make reset SCENARIO=base"

preflight: ## Corre ansible/playbooks/01-preflight.yml (Docker, imágenes, puertos, RAM/CPU, ruteo)
	set -a && . ./.env && set +a && ansible-playbook -i $(ANSIBLE_DIR)/inventory/hosts.yml $(ANSIBLE_DIR)/playbooks/01-preflight.yml

up-base: ## Levanta el escenario base (sin réplicas, lecturas al primario)
	cd $(DEMO_DIR) && READ_DB_HOSTS=10.20.1.10 $(COMPOSE) up -d

up-r1: ## Levanta el escenario r1 (una réplica de lectura)
	cd $(DEMO_DIR) && READ_DB_HOSTS=10.30.1.10 READ_FALLBACK_TO_PRIMARY=false $(COMPOSE) --profile r1 up -d

up-r2: ## Levanta el escenario r2 (dos réplicas de lectura)
	cd $(DEMO_DIR) && READ_DB_HOSTS=10.30.1.10,10.31.1.10 READ_FALLBACK_TO_PRIMARY=false $(COMPOSE) --profile r2 up -d

test: ## Sube k6 y corre las 3 pruebas estándar (carga-base, estrés, pico) contra el escenario arriba
	cd $(DEMO_DIR) && $(COMPOSE) --profile carga up -d k6 sc-k6
	cd $(DEMO_DIR) && $(COMPOSE) exec -T k6 k6 run /scripts/carga-base.js
	-cd $(DEMO_DIR) && $(COMPOSE) exec -T k6 k6 run /scripts/estres.js
	-cd $(DEMO_DIR) && $(COMPOSE) exec -T k6 k6 run /scripts/pico.js

validar: ## Corre ansible/playbooks/02-validar-replicacion.yml (requiere escenario r2)
	set -a && . ./.env && set +a && ansible-playbook -i $(ANSIBLE_DIR)/inventory/hosts.yml $(ANSIBLE_DIR)/playbooks/02-validar-replicacion.yml

backup: ## Corre ansible/playbooks/03-backup.yml (dump + configuraciones a backups/, con timestamp)
	set -a && . ./.env && set +a && ansible-playbook -i $(ANSIBLE_DIR)/inventory/hosts.yml $(ANSIBLE_DIR)/playbooks/03-backup.yml

reset: ## Vuelve al estado inicial de datos (seed limpio). SCENARIO=base|r1|r2 (default r2)
	bash $(DEMO_DIR)/scripts/reset-estado.sh $(SCENARIO)

down: ## Baja todos los contenedores del laboratorio (nunca -v: los datos quedan)
	cd $(DEMO_DIR) && $(COMPOSE) --profile r1 --profile r2 --profile carga --profile test-red down
