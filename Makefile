# Makefile for AxonOps Cassandra Deployment
SHELL := /bin/bash

# Configuration
CLUSTER ?= prod-001
ANSIBLE_USER ?= ubuntu
ANSIBLE_SSH_KEY ?= ~/.ssh/id_rsa
VAULT_PASSWORD_FILE ?= .vault_pass
EXTRA ?=

# Check if we're using pipenv
PIPENV ?= false
ifeq ($(PIPENV),true)
	PIPENVCMD := pipenv run
else
	PIPENVCMD :=
endif

# Set ansible environment
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_COLLECTIONS_PATH=./

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo -e "$(GREEN)AxonOps Cassandra Ansible Deployment$(NC)"
	@echo -e "$(YELLOW)Usage:$(NC) make [target] CLUSTER=<cluster-name> [EXTRA='ansible-options']"
	@echo ""
	@echo -e "$(YELLOW)Available clusters:$(NC)"
	@ls -1 inventory/ | grep -v '^\.' | sed 's/^/  - /'
	@echo ""
	@echo -e "$(YELLOW)Current cluster:$(NC) $(CLUSTER)"
	@echo ""
	@echo -e "$(YELLOW)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-30s %s\n", $$1, $$2}'
	@echo ""
	@echo -e "$(YELLOW)Examples:$(NC)"
	@echo "  make deploy                   # Deploy to prod-001 (default)"
	@echo "  make deploy CLUSTER=test-001  # Deploy to test-001"
	@echo "  make check-status CLUSTER=prod-001 # Check prod cluster"
	@echo "  make restart-cassandra CLUSTER=test-001 # Restart test cluster"

.PHONY: check-vault
check-vault: ## Check if vault password file exists
	@if [ ! -f "$(VAULT_PASSWORD_FILE)" ]; then \
		echo -e "$(YELLOW)Warning: Vault password file $(VAULT_PASSWORD_FILE) not found$(NC)"; \
		echo "Please create it with your vault password or set VAULT_PASSWORD_FILE"; \
		exit 1; \
	fi

.PHONY: check-inventory
check-inventory: ## Validate inventory file
	@if [ ! -f "inventory/$(CLUSTER)/hosts.yml" ]; then \
		echo -e "$(YELLOW)Error: Inventory file inventory/$(CLUSTER)/hosts.yml not found$(NC)"; \
		echo -e "Available clusters:"; \
		ls -1 inventory/ | grep -v '^\.' | sed 's/^/  - /'; \
		exit 1; \
	fi

.PHONY: list-clusters
list-clusters: ## List available clusters
	@echo -e "$(GREEN)Available clusters:$(NC)"
	@ls -1 inventory/ | grep -v '^\.' | while read cluster; do \
		echo -e "  - $$cluster"; \
		if [ -f "inventory/$$cluster/hosts.yml" ]; then \
			echo "    Nodes: $$(grep -E '^\s+\w+:$$' inventory/$$cluster/hosts.yml | grep -v 'hosts:' | wc -l | tr -d ' ')"; \
		fi; \
	done

.PHONY: install-requirements
install-requirements: ## Install required Ansible collections
	@echo -e "$(GREEN)Installing Ansible requirements...$(NC)"
	@${PIPENVCMD} ansible-galaxy install -r requirements.yml

.PHONY: encrypt-vault
encrypt-vault: ## Encrypt vault file
	@${PIPENVCMD} ansible-vault encrypt group_vars/$(CLUSTER)/all/vault.yml --vault-password-file=$(VAULT_PASSWORD_FILE)

.PHONY: decrypt-vault
decrypt-vault: ## Decrypt vault file
	@${PIPENVCMD} ansible-vault decrypt group_vars/$(CLUSTER)/all/vault.yml --vault-password-file=$(VAULT_PASSWORD_FILE)

.PHONY: edit-vault
edit-vault: check-vault ## Edit vault file
	@${PIPENVCMD} ansible-vault edit group_vars/$(CLUSTER)/all/vault.yml --vault-password-file=$(VAULT_PASSWORD_FILE)

.PHONY: ping
ping: check-inventory ## Ping all hosts
	@echo -e "$(GREEN)Pinging hosts in cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible all -i inventory/$(CLUSTER)/hosts.yml -m ping -u $(ANSIBLE_USER) --private-key=$(ANSIBLE_SSH_KEY) ${EXTRA}

.PHONY: deploy
deploy: check-inventory check-vault ## Deploy Cassandra and AxonOps agents to all nodes
	@echo -e "$(GREEN)Deploying Cassandra and AxonOps agents to cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml site.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		--diff ${EXTRA}

.PHONY: deploy-cassandra
deploy-cassandra: check-inventory check-vault ## Deploy only Cassandra
	@echo -e "$(GREEN)Deploying Cassandra to cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml site.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		--tags cassandra \
		--diff ${EXTRA}

.PHONY: deploy-axonops
deploy-axonops: check-inventory check-vault ## Deploy only AxonOps agents
	@echo -e "$(GREEN)Deploying AxonOps agents to cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml site.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		--tags axonops \
		--diff ${EXTRA}

.PHONY: test-connectivity
test-connectivity: check-inventory check-vault ## Test AxonOps SaaS connectivity
	@echo -e "$(GREEN)Testing AxonOps SaaS connectivity for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/test-axonops-connectivity.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		${EXTRA}

.PHONY: check-status
check-status: check-inventory ## Check Cassandra cluster status
	@echo -e "$(GREEN)Checking Cassandra cluster $(CLUSTER) status...$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/check-cassandra-status.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: check-agents
check-agents: check-inventory ## Check AxonOps agents status
	@echo -e "$(GREEN)Checking AxonOps agents status for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/check-axonops-agents.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: restart-cassandra
restart-cassandra: check-inventory ## Rolling restart of Cassandra nodes
	@echo -e "$(GREEN)Performing rolling restart of Cassandra cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/rolling-restart-cassandra.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: restart-agents
restart-agents: check-inventory ## Rolling restart of AxonOps agents
	@echo -e "$(GREEN)Performing rolling restart of AxonOps agents for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/rolling-restart-agents.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: repair-cluster
repair-cluster: check-inventory ## Run nodetool repair on all nodes sequentially
	@echo -e "$(GREEN)Running repair on all nodes in cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/repair-cluster.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: pre-flight
pre-flight: check-inventory check-vault ## Run pre-flight checks before deployment
	@echo -e "$(GREEN)Running pre-flight checks for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/pre-flight-checks.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		-e cluster_name=$(CLUSTER) \
		${EXTRA}

.PHONY: backup-cluster
backup-cluster: check-inventory ## Backup Cassandra cluster data
	@echo -e "$(GREEN)Creating backup of cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/backup-cluster.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: restore-cluster
restore-cluster: check-inventory ## Restore Cassandra cluster from backup
	@echo -e "$(GREEN)Restoring cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/restore-cluster.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: enable-ssl
enable-ssl: check-inventory check-vault ## Enable SSL/TLS encryption
	@echo -e "$(GREEN)Enabling SSL/TLS for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/enable-ssl.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		${EXTRA}

.PHONY: monitor-health
monitor-health: check-inventory ## Monitor cluster health and generate alerts
	@echo -e "$(GREEN)Monitoring health of cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/monitor-cluster-health.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: tune-performance
tune-performance: check-inventory ## Auto-tune performance based on hardware/workload
	@echo -e "$(GREEN)Tuning performance for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/tune-performance.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: disaster-recovery
disaster-recovery: check-inventory ## Run disaster recovery procedures
	@echo -e "$(GREEN)Running disaster recovery for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/disaster-recovery.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: manage-audit
manage-audit: check-inventory ## Manage Cassandra audit logging
	@echo -e "$(GREEN)Managing audit logging for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/manage-audit-logging.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		${EXTRA}

.PHONY: download-cassandra
download-cassandra: ## Download Cassandra tarball
	@echo -e "$(GREEN)Downloading Cassandra tarball...$(NC)"
	@${PIPENVCMD} ansible-playbook -i localhost, playbooks/operational/download-cassandra.yml \
		--diff ${EXTRA}

.PHONY: validate
validate: check-inventory ## Validate configuration and connectivity
	@echo -e "$(GREEN)Validating configuration for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml playbooks/operational/validate-setup.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		${EXTRA}

.PHONY: dry-run
dry-run: check-inventory check-vault ## Perform a dry run of the deployment
	@echo -e "$(GREEN)Performing dry run for cluster: $(CLUSTER)$(NC)"
	@${PIPENVCMD} ansible-playbook -i inventory/$(CLUSTER)/hosts.yml site.yml \
		-u $(ANSIBLE_USER) \
		--private-key=$(ANSIBLE_SSH_KEY) \
		--vault-password-file=$(VAULT_PASSWORD_FILE) \
		--check --diff ${EXTRA}

.PHONY: clean
clean: ## Clean up downloaded files
	@echo -e "$(GREEN)Cleaning up downloads...$(NC)"
	@rm -rf downloads/*
	@echo "Downloads directory cleaned"