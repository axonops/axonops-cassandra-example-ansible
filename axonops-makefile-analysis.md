# AxonOps Makefile Analysis - Ansible Command Patterns

## Overview
The AxonOps config-automation repository uses a well-structured Makefile to manage ansible-playbook executions with consistent patterns and environment-aware configurations.

## Key Makefile Structure

### 1. Makefile Configuration
```makefile
.ONESHELL:
.SHELL := /bin/bash
.PHONY: common
.EXPORT_ALL_VARIABLES:
CURRENT_FOLDER=$(shell basename "$$(pwd)")
# Bug running on OSX
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
UNAME=$(shell uname -s)
ANSIBLE_COLLECTIONS_PATH=./
```

### 2. Pipenv Support Pattern
```makefile
# Default to use pipenv unless disabled
PIPENV ?= false
ifeq ($(PIPENV),true)
PIPENVCMD=pipenv run
else
PIPENVCMD=
endif
```

### 3. Environment Check Pattern
```makefile
check-env:
	@echo $(ANSIBLE_COLLECTIONS_PATH)
	@if [ ! "$(AXONOPS_ORG)" ]; then echo "$(BOLD)$(RED)AXONOPS_ORG is not set$(RESET)"; exit 1;fi
```

### 4. Ansible-Playbook Command Pattern
The consistent pattern used across all targets:
```makefile
target-name: check-env ## Description
	@${PIPENVCMD} ansible-playbook [OPTIONS] -i localhost, playbook.yml --diff ${EXTRA}
```

## Ansible Command Patterns

### Basic Pattern
```bash
ansible-playbook -i localhost, <playbook>.yml --diff ${EXTRA}
```

### With Verbose Output
```bash
ansible-playbook -v -i localhost, <playbook>.yml --diff ${EXTRA}
```

### Key Components:
1. **Inventory**: Always uses `-i localhost,` (note the comma after localhost)
2. **Diff Flag**: `--diff` to show changes
3. **Extra Variables**: `${EXTRA}` allows passing additional parameters
4. **Pipenv Support**: `${PIPENVCMD}` prefix for optional pipenv execution

## Target Examples

### 1. Alert Endpoints
```makefile
endpoints: check-env ## Create alert endpoints and integrations
	@${PIPENVCMD} ansible-playbook -i localhost, setup_alert_endpoints.yml --diff ${EXTRA}
```

### 2. Alert Routes (with verbose)
```makefile
routes: check-env ## Create alert routes
	@${PIPENVCMD} ansible-playbook -v -i localhost, setup_alert_routes.yml --diff ${EXTRA}
```

### 3. Metrics Alerts (with verbose)
```makefile
metrics-alerts: check-env ## Create alerts based on metrics
	@${PIPENVCMD} ansible-playbook -v -i localhost, setup_metrics_alerts.yml --diff ${EXTRA}
```

### 4. Log Alerts
```makefile
log-alerts: check-env ## Create alerts based on logs
	@${PIPENVCMD} ansible-playbook -i localhost, setup_log_alerts.yml --diff ${EXTRA}
```

### 5. Service Checks
```makefile
service-checks: check-env ## Create alerts for TCP and shell connections
	@${PIPENVCMD} ansible-playbook -i localhost, setup_service_checks.yml --diff ${EXTRA}
```

### 6. Backups
```makefile
backups: check-env ## Create backup
	@${PIPENVCMD} ansible-playbook -i localhost, setup_backups.yml --diff ${EXTRA}
```

### 7. Commitlog Archive
```makefile
commitlog: check-env ## Create commitlog archive
	@${PIPENVCMD} ansible-playbook -i localhost, setup_commitlogs_archive.yml --diff ${EXTRA}
```

## Additional Features

### Help Target
```makefile
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
```

### Validation Target
```makefile
validate: ## Validate YAML config
	@${PIPENVCMD} python validate_yaml.py
```

### Pre-commit Check
```makefile
check: ## run pre-commit tests
	@${PIPENVCMD} pre-commit run --all-files
```

## Key Patterns to Adopt

1. **Consistent Target Structure**: All ansible targets follow the pattern `target: check-env`
2. **Environment Validation**: Always check required environment variables before execution
3. **Flexible Execution**: Support for both direct and pipenv-wrapped execution
4. **Extra Parameters**: Allow passing additional ansible-playbook options via `${EXTRA}`
5. **Localhost Inventory**: Use `-i localhost,` for local execution
6. **Change Visibility**: Always use `--diff` flag to show what changes will be made
7. **Self-Documenting**: Use `## Description` comments for help generation
8. **Selective Verbosity**: Add `-v` flag only where detailed output is typically needed

## Usage Examples

```bash
# Basic execution
make endpoints

# With extra ansible variables
make metrics-alerts EXTRA="-e some_var=value"

# With pipenv
make backups PIPENV=true

# Pass multiple extra options
make routes EXTRA="-e var1=value1 -e var2=value2 --check"
```