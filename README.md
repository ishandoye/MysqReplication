import os

readme_content = """# MySQL Master-Slave Replication on Rocky Linux 8

A complete, automated solution for configuring MySQL 8 (GTID-based) Master-Slave (Primary-Replica) replication on Rocky Linux 8 using shell scripts.

---

## 📋 Features

- **GTID-Based Replication**: Automated Global Transaction Identifier configuration for reliable transaction tracking and failover.
- **Automated Setup**: Two standalone bash scripts handle package installation, configuration tuning, user creation, network checks, and replication bootstrapping.
- **Sample Seed Data**: Creates a dummy database (`app_db`) and table (`users`) on the Master to immediately test sync on the Replica.
- **Auto Health Checks**: The replica script validates network connectivity to port 3306 and checks `Slave_IO_Running` / `Slave_SQL_Running` status upon completion.

---

## 🛠️ Prerequisites

- **2 x Rocky Linux 8 Instances** (Master and Slave).
- **SUDO / Root Access** on both nodes.
- **Network Connectivity**: Ensure Firewall / Security Groups allow TCP port `3306` between the two nodes.

---

## 🚀 Quick Start Guide

### Step 1: Configure the Master Node

1. Copy `setup_master.sh` to your Master server.
2. Make the script executable and run it as root:

```bash
chmod +x setup_master.sh
sudo ./setup_master.sh

Note the Master IP Address printed in the success output.
```

### Step 2: Configure the Replica (Slave) Node

1. Copy setup_replica.sh to your Replica server.
2. Run the script as root, passing the Master IP Address as an argument:

```bash

chmod +x setup_replica.sh
sudo ./setup_replica.sh <MASTER_IP>
```
