#!/bin/bash
set -eo pipefail

# --- CONFIGURATION ---
MYSQL_ROOT_PASS="StrongRootPass123!"
REPL_USER="repl"
REPL_PASS="StrongReplPass123!"
SERVER_ID=1

echo "========================================="
echo " Configuring Master Node (Rocky Linux 8) "
echo "========================================="

# 1. Install & Enable MySQL if not already installed
if ! systemctl is-active --quiet mysqld; then
    echo "[+] Installing and starting MySQL..."
    dnf install -y mysql-server
    systemctl enable --now mysqld
fi

# 2. Configure GTID-based Binary Logging
echo "[+] Writing Master replication configuration..."
cat <<EOF > /etc/my.cnf.d/replication.cnf
[mysqld]
server-id = ${SERVER_ID}
log_bin = mysql-bin
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
bind-address = 0.0.0.0
EOF

echo "[+] Restarting MySQL to apply changes..."
systemctl restart mysqld

# 3. Secure Root Account (if fresh installation)
mysql -u root <<EOSQL 2>/dev/null || true
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOSQL

MYSQL_CMD="mysql -u root -p${MYSQL_ROOT_PASS}"

# 4. Create Replication User
echo "[+] Creating replication user '${REPL_USER}'..."
${MYSQL_CMD} <<EOSQL
CREATE USER IF NOT EXISTS '${REPL_USER}'@'%' IDENTIFIED BY '${REPL_PASS}';
GRANT REPLICATION SLAVE ON *.* TO '${REPL_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

# 5. Create Dummy Database and Sample Data
echo "[+] Creating dummy database 'app_db' and sample records..."
${MYSQL_CMD} <<EOSQL
CREATE DATABASE IF NOT EXISTS app_db;
USE app_db;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users (username) VALUES ('alice'), ('bob'), ('charlie');
EOSQL

# 6. Fetch Master Status Details
echo ""
echo "=========================================================="
echo " SUCCESS: Master node is configured!"
echo "=========================================================="
echo "Master IP Address: $(hostname -I | awk '{print $1}')"
echo "Replication User:  ${REPL_USER}"
echo "Replication Pass:  ${REPL_PASS}"
echo ""
echo "Current Database Content:"
${MYSQL_CMD} -e "SELECT * FROM app_db.users;"
echo "=========================================================="
