# Troubleshooting Guide

This guide provides solutions for common issues when deploying and operating Cassandra with AxonOps using this Ansible project.

## Setup for Troubleshooting Commands

To simplify the ansible commands in this guide, you can set the inventory as an environment variable:

```bash
# For production cluster
export ANSIBLE_INVENTORY=inventory/prod-001/hosts.yml

# For test cluster  
export ANSIBLE_INVENTORY=inventory/test-001/hosts.yml
```

Alternatively, use the `-i` flag with each ansible command or use the provided Makefile targets where available.

## Table of Contents

- [Pre-deployment Issues](#pre-deployment-issues)
- [Cassandra Issues](#cassandra-issues)
- [AxonOps Agent Issues](#axonops-agent-issues)
- [Network and Connectivity](#network-and-connectivity)
- [Performance Issues](#performance-issues)
- [SSL/TLS Issues](#ssltls-issues)
- [Backup and Restore Issues](#backup-and-restore-issues)
- [Useful Commands](#useful-commands)

## Pre-deployment Issues

### Issue: Pre-flight checks fail

**Symptoms:**
```
TASK [Assert OS check] *********************************************************
fatal: [node1]: FAILED! => {"msg": "This playbook requires Ubuntu 22.04 or later"}
```

**Solution:**
- Ensure all target nodes are running Ubuntu 22.04 or later
- Verify with: `ansible all -m setup -a "filter=ansible_distribution*"`

### Issue: Vault file not found

**Symptoms:**
```
ERROR! Attempting to decrypt but no vault secrets found
```

**Solution:**
1. Create vault password file:
   ```bash
   echo "your-secure-password" > .vault_pass
   chmod 600 .vault_pass
   ```

2. Create and encrypt vault file:
   ```bash
   cp group_vars/prod-001/all/vault.yml.example group_vars/prod-001/all/vault.yml
   ansible-vault encrypt group_vars/prod-001/all/vault.yml --vault-password-file=.vault_pass
   ```

### Issue: Cannot connect to target nodes

**Symptoms:**
```
fatal: [node1]: UNREACHABLE! => {"msg": "Failed to connect to the host via ssh"}
```

**Solution:**
1. Verify SSH connectivity:
   ```bash
   ssh -i ~/.ssh/id_rsa ubuntu@<node-ip>
   ```

2. Check SSH key permissions:
   ```bash
   chmod 600 ~/.ssh/id_rsa
   ```

3. Verify inventory file has correct IPs and SSH user

## Cassandra Issues

### Issue: Cassandra won't start

**Symptoms:**
- Service fails to start
- No process listening on port 9042

**Diagnosis:**
```bash
# Check service status
make check-status CLUSTER=prod-001

# Check logs directly
ansible cassandra -m shell -a "journalctl -u cassandra -n 100 --no-pager"

# Check system log
ansible cassandra -m shell -a "tail -100 /var/log/cassandra/system.log"
```

**Common Causes and Solutions:**

1. **Insufficient memory:**
   ```bash
   # Check available memory
   ansible cassandra -m shell -a "free -h"
   
   # Solution: Reduce heap size in group_vars/<cluster>/all/cassandra.yml
   java_heap_size: 4G  # Reduce from 8G
   ```

2. **Port already in use:**
   ```bash
   # Check port usage
   ansible cassandra -m shell -a "ss -tlnp | grep -E '7000|9042'"
   
   # Solution: Stop conflicting service or change Cassandra ports
   ```

3. **Incorrect configuration:**
   ```bash
   # Validate configuration
   ansible cassandra -m shell -a "/opt/cassandra/bin/cassandra -f -D" -b
   ```

4. **Data corruption:**
   ```bash
   # Clear data and restart (WARNING: Data loss!)
   ansible cassandra -m shell -a "systemctl stop cassandra" -b
   ansible cassandra -m shell -a "rm -rf /var/lib/cassandra/data/*" -b
   ansible cassandra -m shell -a "rm -rf /var/lib/cassandra/commitlog/*" -b
   ansible cassandra -m shell -a "rm -rf /var/lib/cassandra/saved_caches/*" -b
   ansible cassandra -m shell -a "systemctl start cassandra" -b
   ```

### Issue: Node won't join cluster

**Symptoms:**
```
ERROR [main] 2024-01-15 12:00:00,000 CassandraDaemon.java:123 - Exception encountered during startup
java.lang.RuntimeException: Unable to gossip with any peers
```

**Solution:**
1. Check seed configuration:
   ```bash
   ansible cassandra -m shell -a "grep -A2 'seed_provider:' /etc/cassandra/cassandra.yaml"
   ```

2. Verify network connectivity between nodes:
   ```bash
   ansible cassandra -m shell -a "nc -zv <seed-ip> 7000"
   ```

3. Check cluster name matches:
   ```bash
   ansible cassandra -m shell -a "grep 'cluster_name:' /etc/cassandra/cassandra.yaml"
   ```

4. Clear gossip state (if node was previously in different cluster):
   ```bash
   ansible failing-node -m shell -a "systemctl stop cassandra" -b
   ansible failing-node -m shell -a "rm -rf /var/lib/cassandra/data/system" -b
   ansible failing-node -m shell -a "systemctl start cassandra" -b
   ```

### Issue: Authentication failures

**Symptoms:**
```
com.datastax.driver.core.exceptions.AuthenticationException: Authentication error
```

**Solution:**
1. Verify authentication is configured correctly:
   ```bash
   ansible cassandra -m shell -a "grep authenticator /etc/cassandra/cassandra.yaml"
   ```

2. Reset default credentials:
   ```bash
   # Connect with default credentials
   /opt/cassandra/bin/cqlsh -u cassandra -p cassandra <node-ip>
   
   # Create new superuser
   CREATE USER admin WITH PASSWORD 'new_password' SUPERUSER;
   
   # Change cassandra password
   ALTER USER cassandra WITH PASSWORD 'new_password';
   ```

## AxonOps Agent Issues

### Issue: Agent won't start

**Symptoms:**
- Agent service fails
- No connection to AxonOps SaaS

**Diagnosis:**
```bash
# Check agent status
make check-agents CLUSTER=prod-001

# Check agent logs
ansible cassandra -m shell -a "tail -50 /var/log/axonops/axon-agent.log"

# Test connectivity
make test-connectivity CLUSTER=prod-001
```

**Solutions:**

1. **Invalid API key:**
   ```bash
   # Verify API key in vault
   make edit-vault CLUSTER=prod-001
   
   # Update and re-deploy
   make deploy-axonops CLUSTER=prod-001
   ```

2. **Network connectivity issues:**
   ```bash
   # Test HTTPS connectivity
   ansible cassandra -m shell -a "curl -I https://agents.axonops.cloud"
   
   # Check firewall rules
   ansible cassandra -m shell -a "ufw status" -b
   ```

3. **Permission issues:**
   ```bash
   # Fix ownership
   ansible cassandra -m shell -a "chown -R axonops:axonops /var/log/axonops" -b
   ansible cassandra -m shell -a "chown -R axonops:axonops /etc/axonops" -b
   ```

### Issue: Agent not reporting metrics

**Symptoms:**
- Agent running but no data in AxonOps dashboard

**Solution:**
1. Verify Cassandra JMX is accessible:
   ```bash
   ansible cassandra -m shell -a "netstat -tlnp | grep 7199" -b
   ```

2. Check agent configuration:
   ```bash
   ansible cassandra -m shell -a "cat /etc/axonops/axon-agent.yml"
   ```

3. Restart agent:
   ```bash
   make restart-agents CLUSTER=prod-001
   ```

## Network and Connectivity

### Issue: Nodes can't communicate

**Symptoms:**
- Gossip failures
- Streaming failures
- Request timeouts

**Diagnosis:**
```bash
# Check network connectivity matrix
for source in node1 node2 node3; do
  for dest in node1 node2 node3; do
    echo "Testing $source -> $dest"
    ansible $source -m shell -a "nc -zv $dest 7000"
  done
done
```

**Solution:**
1. Check firewall rules:
   ```bash
   # Required ports
   # 7000 - Storage port (inter-node)
   # 7001 - SSL storage port
   # 7199 - JMX
   # 9042 - Native transport
   # 9160 - Thrift (if enabled)
   
   # Add firewall rules
   ansible cassandra -m shell -a "ufw allow from any to any port 7000,7001,7199,9042,9160 proto tcp" -b
   ```

2. Verify network interfaces:
   ```bash
   ansible cassandra -m shell -a "ip addr show"
   ansible cassandra -m shell -a "grep -E 'listen_address|broadcast_address' /etc/cassandra/cassandra.yaml"
   ```

## Performance Issues

### Issue: High CPU usage

**Diagnosis:**
```bash
# Check CPU usage
ansible cassandra -m shell -a "top -bn1 | head -20"

# Check compaction activity
ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool compactionstats"

# Check thread pools
ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool tpstats"
```

**Solutions:**
1. Tune compaction:
   ```bash
   # Reduce compaction throughput
   ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool setcompactionthroughput 16"
   
   # Or use performance tuning playbook
   make tune-performance CLUSTER=prod-001 -e workload_profile=read_heavy
   ```

2. Check for large partitions:
   ```bash
   ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool tablehistograms <keyspace> <table>"
   ```

### Issue: High memory usage

**Diagnosis:**
```bash
# Check heap usage
ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool info | grep Heap"

# Check for memory leaks
ansible cassandra -m shell -a "jstat -gcutil $(pgrep -f cassandra) 1000 5"
```

**Solutions:**
1. Trigger GC:
   ```bash
   ansible cassandra -m shell -a "jcmd $(pgrep -f cassandra) GC.run"
   ```

2. Reduce cache sizes:
   ```bash
   ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool setcachecapacity 100 100 100"
   ```

### Issue: Slow queries

**Diagnosis:**
```bash
# Enable slow query log
ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool setlogginglevel ROOT DEBUG"

# Check slow queries
ansible cassandra -m shell -a "grep 'slow' /var/log/cassandra/debug.log | tail -20"

# Get query trace
cqlsh> TRACING ON;
cqlsh> SELECT * FROM keyspace.table WHERE id = 123;
```

**Solutions:**
1. Add indexes where appropriate
2. Review data model
3. Increase read concurrency:
   ```bash
   ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool setconcurrentreaders 64"
   ```

## SSL/TLS Issues

### Issue: SSL handshake failures

**Symptoms:**
```
javax.net.ssl.SSLHandshakeException: Received fatal alert: certificate_unknown
```

**Solution:**
1. Verify certificates:
   ```bash
   # Check keystore
   ansible cassandra -m shell -a "keytool -list -keystore /etc/cassandra/ssl/keystore.p12 -storepass cassandra"
   
   # Check certificate dates
   ansible cassandra -m shell -a "keytool -list -v -keystore /etc/cassandra/ssl/keystore.p12 -storepass cassandra | grep Valid"
   ```

2. Regenerate certificates if expired:
   ```bash
   # Remove old certificates
   ansible cassandra -m shell -a "rm -rf /etc/cassandra/ssl/*" -b
   
   # Re-run SSL configuration
   make enable-ssl CLUSTER=prod-001
   ```

3. Ensure all nodes have correct truststore:
   ```bash
   # Compare truststore across nodes
   ansible cassandra -m shell -a "md5sum /etc/cassandra/ssl/truststore.p12"
   ```

## Backup and Restore Issues

### Issue: Backup fails with "No space left"

**Solution:**
1. Check available space:
   ```bash
   ansible cassandra -m shell -a "df -h /var/backups"
   ```

2. Clean old backups:
   ```bash
   ansible cassandra -m shell -a "find /var/backups/cassandra -type d -mtime +7 -exec rm -rf {} +" -b
   ```

3. Change backup location:
   ```bash
   make backup-cluster CLUSTER=prod-001 -e cassandra_backup_dir=/mnt/backups
   ```

### Issue: Restore fails

**Common causes:**
1. Schema mismatch - restore schema first
2. Incorrect file permissions - ensure cassandra user owns files
3. Incompatible versions - check Cassandra versions match

**Solution:**
```bash
# Restore with verification disabled
make restore-cluster CLUSTER=prod-001 -e verify_restore=false

# Restore specific keyspaces only
make restore-cluster CLUSTER=prod-001 -e "cassandra_restore_keyspaces=['keyspace1','keyspace2']"
```

## Useful Commands

### Health Checks
```bash
# Full cluster health check
make monitor-health CLUSTER=prod-001

# Quick status check
ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool status"

# Check specific node
ansible node1 -m shell -a "/opt/cassandra/bin/nodetool info"
```

### Emergency Procedures
```bash
# Drain node before maintenance
ansible node1 -m shell -a "/opt/cassandra/bin/nodetool drain" -b

# Force stop Cassandra
ansible node1 -m shell -a "systemctl kill -s KILL cassandra" -b

# Bootstrap node back
ansible node1 -m shell -a "systemctl start cassandra" -b

# Remove node from cluster
ansible remaining-nodes -m shell -a "/opt/cassandra/bin/nodetool removenode <node-id>"
```

### Data Recovery
```bash
# Scrub corrupted SSTables
ansible affected-node -m shell -a "/opt/cassandra/bin/nodetool scrub <keyspace> <table>"

# Rebuild from other DC
ansible affected-node -m shell -a "/opt/cassandra/bin/nodetool rebuild <source-dc>"

# Force repair
ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool repair -full"
```

## Getting Help

1. Check logs:
   - Cassandra: `/var/log/cassandra/system.log`
   - AxonOps: `/var/log/axonops/axon-agent.log`
   - System: `journalctl -u cassandra`

2. Enable debug logging:
   ```bash
   ansible cassandra -m shell -a "/opt/cassandra/bin/nodetool setlogginglevel org.apache.cassandra DEBUG"
   ```

3. Community resources:
   - [Apache Cassandra Documentation](https://cassandra.apache.org/doc/latest/)
   - [AxonOps Documentation](https://docs.axonops.com)
   - [DataStax Academy](https://academy.datastax.com)

4. File an issue:
   - Include output from `make pre-flight`
   - Include relevant log excerpts
   - Include your inventory and group_vars (sanitized)