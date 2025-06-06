# AxonOps Cassandra Example Ansible

An example Ansible project for deploying Apache Cassandra 5.0.4 with AxonOps agents connecting to AxonOps SaaS service. This project supports managing multiple Cassandra clusters with different configurations and topologies.

## Overview

This project provides a complete Ansible automation solution for:
- Managing multiple Cassandra clusters with different topologies
- Installing Apache Cassandra 5.0.4 across multiple datacenters
- Configuring Cassandra with production-ready settings
- Installing and configuring AxonOps agents for monitoring
- Connecting agents to AxonOps SaaS (agents.axonops.cloud)
- Operational playbooks for maintenance tasks

## Supported Clusters

### Production Cluster (prod-001)
- **Total Nodes**: 9
- **Datacenters**: 2
- **DC1**: 6 nodes (3 racks, 2 nodes per rack)
- **DC2**: 3 nodes (3 racks, 1 node per rack)
- **Authentication**: Enabled (PasswordAuthenticator)
- **Heap Size**: 8GB

### Test Cluster (test-001)
- **Total Nodes**: 3
- **Datacenters**: 1
- **DC1**: 3 nodes (3 racks, 1 node per rack)
- **Authentication**: Disabled (AllowAllAuthenticator)
- **Heap Size**: 4GB

### Common Configuration
- **OS**: Ubuntu 24 LTS only
- **Java**: Azul Zulu OpenJDK 17
- **Cassandra Version**: 5.0.4

## Features

- **Idempotent playbooks** - Safe to run multiple times
- **Production-ready configurations** - Includes all recommended kernel tunings
- **Multi-datacenter setup** - Using GossipingPropertyFileSnitch
- **Security** - Authentication enabled with default cassandra/cassandra credentials
- **Monitoring** - AxonOps agents pre-configured for SaaS connection
- **Operational tasks** - Rolling restarts, repairs, status checks

## Prerequisites

1. **Ansible Control Node**:
   - Ansible 2.12 or higher
   - Python 3.8+
   - SSH access to all target nodes

2. **Target Nodes**:
   - Ubuntu 24 LTS
   - SSH access with sudo privileges
   - Network connectivity between all nodes
   - Outbound HTTPS access to:
     - agents.axonops.cloud (port 443)
     - packages.axonops.com
     - repos.azul.com
     - dlcdn.apache.org

3. **AxonOps Account**:
   - Active AxonOps SaaS account
   - API key from AxonOps dashboard
   - Organization name

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/axonops-cassandra-example-ansible.git
cd axonops-cassandra-example-ansible
```

### 2. List Available Clusters

```bash
make list-clusters
```

### 3. Configure Inventory

Choose your cluster and edit the inventory:

For production cluster:
```bash
vi inventory/prod-001/hosts.yml
```

For test cluster:
```bash
vi inventory/test-001/hosts.yml
```

Update with your server details:
```yaml
cassandra-dc1-rack1-node1:
  ansible_host: 10.0.1.11  # Replace with your IP
  cassandra_rack: rack1
  cassandra_dc: dc1
  ssd_device: /dev/nvme1n1  # Your SSD device
```

### 4. Set Up Ansible Vault

Create vault password file:
```bash
echo "your-secure-vault-password" > .vault_pass
chmod 600 .vault_pass
```

Copy and configure vault file for your cluster:
```bash
# For production
cp group_vars/prod-001/all/vault.yml.example group_vars/prod-001/all/vault.yml
ansible-vault encrypt group_vars/prod-001/all/vault.yml --vault-password-file=.vault_pass

# For test
cp group_vars/test-001/all/vault.yml.example group_vars/test-001/all/vault.yml
ansible-vault encrypt group_vars/test-001/all/vault.yml --vault-password-file=.vault_pass
```

Edit the vault file:
```bash
make edit-vault CLUSTER=prod-001  # or test-001
```

Add your AxonOps credentials:
```yaml
vault_axonops_api_key: "your-api-key-here"
vault_axonops_org: "your-organization-name"
```

### 5. Install Ansible Requirements

```bash
make install-requirements
```

### 6. Download Cassandra

```bash
make download-cassandra
```

### 7. Run Pre-flight Checks (Recommended)

```bash
make pre-flight CLUSTER=prod-001  # or test-001
```

### 8. Deploy Everything

Deploy to default cluster (prod-001):
```bash
make deploy
```

Deploy to specific cluster:
```bash
make deploy CLUSTER=test-001
```

Or deploy components separately:
```bash
make deploy-cassandra CLUSTER=prod-001   # Install only Cassandra
make deploy-axonops CLUSTER=test-001     # Install only AxonOps agents
```

## Configuration

### Cluster-Specific Variables

Each cluster has its own configuration in `group_vars/<cluster-name>/all/cassandra.yml`:

```yaml
# Example: group_vars/prod-001/all/cassandra.yml
cassandra_cluster_name: "Production Cluster 001"
cassandra_authenticator: PasswordAuthenticator
cassandra_authorizer: CassandraAuthorizer
java_heap_size: 8G

# Example: group_vars/test-001/all/cassandra.yml
cassandra_cluster_name: "Test Cluster 001"
cassandra_authenticator: AllowAllAuthenticator
cassandra_authorizer: AllowAllAuthorizer
java_heap_size: 4G
```

### Per-Node Configuration

Create host-specific variables in `host_vars/<cluster-name>/<hostname>.yml`:

```yaml
# Example: host_vars/prod-001/cassandra-dc1-rack1-node1.yml
ssd_device: /dev/nvme2n1  # Different SSD device
cassandra_listen_interface: eth1  # Different network interface
```

### Adding a New Cluster

1. Create inventory directory:
   ```bash
   mkdir inventory/dev-001
   ```

2. Create inventory file `inventory/dev-001/hosts.yml`

3. Create group variables:
   ```bash
   mkdir -p group_vars/dev-001/{all,dc1}
   cp group_vars/test-001/all/cassandra.yml group_vars/dev-001/all/cassandra.yml
   cp group_vars/test-001/all/java.yml group_vars/dev-001/all/java.yml
   cp group_vars/test-001/all/linux.yml group_vars/dev-001/all/linux.yml
   cp group_vars/test-001/all/vault.yml.example group_vars/dev-001/all/vault.yml.example
   # Edit as needed
   ```

4. Deploy:
   ```bash
   make deploy CLUSTER=dev-001
   ```

## Operational Playbooks

All operational commands work with the CLUSTER parameter:

### Check Cluster Status

```bash
make check-status                    # Check prod-001 (default)
make check-status CLUSTER=test-001   # Check test-001
```

### Test AxonOps Connectivity

```bash
make test-connectivity CLUSTER=prod-001
```

### Rolling Restart

Restart Cassandra nodes one at a time:
```bash
make restart-cassandra CLUSTER=prod-001
```

Restart AxonOps agents:
```bash
make restart-agents CLUSTER=test-001
```

### Run Repairs

Sequential repair of all nodes:
```bash
make repair-cluster CLUSTER=prod-001
```

### Validate Setup

Complete validation of the deployment:
```bash
make validate CLUSTER=test-001
```

## Makefile Targets

Run `make help` to see all available targets:

### Deployment
- `pre-flight` - Run pre-flight checks before deployment
- `deploy` - Deploy Cassandra and AxonOps to all nodes
- `deploy-cassandra` - Deploy only Cassandra
- `deploy-axonops` - Deploy only AxonOps agents
- `dry-run` - Perform a dry run

### Operations
- `check-status` - Check Cassandra cluster status
- `check-agents` - Check AxonOps agents status
- `test-connectivity` - Test AxonOps SaaS connectivity
- `monitor-health` - Monitor cluster health and generate alerts
- `validate` - Validate complete setup

### Maintenance
- `restart-cassandra` - Rolling restart of Cassandra
- `restart-agents` - Rolling restart of agents
- `repair-cluster` - Run nodetool repair on all nodes
- `tune-performance` - Auto-tune performance based on hardware/workload
- `enable-ssl` - Enable SSL/TLS encryption (safe migration)

### Backup & Recovery
- `backup-cluster` - Create cluster backup
- `restore-cluster` - Restore from backup

### Examples with Options

```bash
# Deploy to specific datacenter
make deploy EXTRA='--limit=dc1'

# Deploy with verbose output
make deploy EXTRA='-v'

# Dry run with diff
make dry-run

# Custom SSH key
make deploy ANSIBLE_SSH_KEY=~/.ssh/custom_key
```

## Directory Structure

```
.
├── Makefile                    # Build automation with cluster support
├── inventory/
│   ├── prod-001/              # Production cluster
│   │   └── hosts.yml          # 9-node multi-DC inventory
│   └── test-001/              # Test cluster
│       └── hosts.yml          # 3-node single-DC inventory
├── group_vars/
│   ├── prod-001/              # Production cluster variables
│   │   ├── all/
│   │   │   ├── main.yml      # Prod cluster settings
│   │   │   └── vault.yml     # Encrypted prod secrets
│   │   ├── dc1/main.yml      # Prod DC1 specific
│   │   └── dc2/main.yml      # Prod DC2 specific
│   └── test-001/              # Test cluster variables
│       ├── all/
│       │   ├── main.yml      # Test cluster settings
│       │   └── vault.yml     # Encrypted test secrets
│       └── dc1/main.yml      # Test DC1 specific
├── host_vars/                 # Node-specific overrides
│   ├── prod-001/
│   └── test-001/
├── roles/
│   ├── cassandra/            # Cassandra installation role
│   │   ├── tasks/
│   │   ├── templates/
│   │   ├── handlers/
│   │   └── defaults/
│   └── axonops-agent/        # AxonOps agent role
│       ├── tasks/
│       ├── templates/
│       └── handlers/
├── playbooks/
│   └── operational/          # Maintenance playbooks
└── downloads/                # Downloaded tarballs
    └── .gitkeep
```

## Kernel Tunings Applied

The playbooks apply extensive kernel tunings for optimal Cassandra performance:

- **Network**: TCP keepalive, buffer sizes
- **Memory**: Swappiness, memory mapping limits
- **Storage**: SSD optimizations, readahead settings
- **CPU**: Performance governor
- **Limits**: File descriptors, processes, memory locking

See `roles/cassandra/tasks/system-prep.yml` for full details.

## Security Considerations

1. **Ansible Vault**: Always encrypt sensitive data
2. **SSH Keys**: Use key-based authentication
3. **Cassandra Auth**: Change default passwords after deployment
4. **Network**: Ensure proper firewall rules between nodes
5. **AxonOps**: API keys should be kept secure

## New Features

### SSL/TLS Encryption
Enable secure inter-node and client encryption:
```bash
# Enable SSL with safe migration (no downtime)
make enable-ssl CLUSTER=prod-001

# Custom encryption settings
make enable-ssl CLUSTER=prod-001 -e "ssl_internode_encryption=dc enable_client_encryption=true"
```

### Automated Backups
Create and manage cluster backups:
```bash
# Create full backup
make backup-cluster CLUSTER=prod-001

# Create incremental backup
make backup-cluster CLUSTER=prod-001 -e snapshot_type=incremental

# Restore from backup
make restore-cluster CLUSTER=prod-001
```

### Performance Tuning
Automatically tune Cassandra based on hardware and workload:
```bash
# Auto-tune based on hardware
make tune-performance CLUSTER=prod-001

# Apply specific workload profile
make tune-performance CLUSTER=prod-001 -e workload_profile=read_heavy
```

### Health Monitoring
Monitor cluster health with configurable thresholds:
```bash
# Run health checks
make monitor-health CLUSTER=prod-001

# Monitor with custom thresholds
make monitor-health CLUSTER=prod-001 -e "thresholds={'heap_usage_percent': 90}"
```

## Troubleshooting

See the comprehensive [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide for detailed solutions to common issues.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly with `make dry-run`
4. Submit a pull request

## License

Apache License 2.0 - See LICENSE file

## Support

- AxonOps Documentation: https://docs.axonops.com
- Apache Cassandra: https://cassandra.apache.org/doc/latest/
- Issues: https://github.com/your-org/axonops-cassandra-example-ansible/issues