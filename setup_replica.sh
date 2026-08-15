#!/bin/bash
set -eo pipefail

# --- CONFIGURATION ---
MASTER_IP="$1"
MYSQL_ROOT_PASS="StrongRootPass123!"
REPL_USER="repl"
REPL_PASS="StrongReplPass123!"
SERVER_ID=2

if [ -z "${MASTER_IP}" ]; then
    echo "ERROR: Please provide the Master IP address."
    echo "Usage: sudo ./setup_replica.sh <MASTER_IP>"
    exit 1
fi

echo "=========================================="
echo " Configuring Replica Node (Rocky Linux 8) "
echo " Target Master: ${MASTER_IP}              "
echo "=========================================="

# 1. Install & Enable MySQL if not already installed
if ! systemctl is-active --quiet mysqld; then
    echo "[+] Installing and starting MySQL..."
    dnf install -y mysql-server
    systemctl enable --now mysqld
fi

# 2. Configure GTID Replica Mode
echo "[+] Writing Replica replication configuration..."
cat <<EOF > /etc/my.cnf.d/replication.cnf
[mysqld]
server-id = ${SERVER_ID}
log_bin = mysql-bin
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
read_only = ON
EOF

echo "[+] Restarting MySQL to apply changes..."
systemctl restart mysqld

# 3. Secure Root Account
mysql -u root <<EOSQL 2>/dev/null || true
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
FLUSH PRIVILEGES;
EOSQL

MYSQL_CMD="mysql -u root -p${MYSQL_ROOT_PASS}"

# 4. Verify Connectivity to Master Port 3306
echo "[+] Checking connection to Master (${MASTER_IP}:3306)..."
until nc -z -v -w5 "${MASTER_IP}" 3306 2>/dev/null; do
    echo "    Waiting for Master MySQL network port..."
    sleep 3
done

# 5. Point Replica to Master using GTID Auto-Positioning
echo "[+] Configuring replication connection..."
${MYSQL_CMD} <<EOSQL
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='${MASTER_IP}',
  MASTER_USER='${REPL_USER}',
  MASTER_PASSWORD='${REPL_PASS}',
  MASTER_AUTO_POSITION=1;
START SLAVE;
EOSQL

# 6. Verify Replica Status
echo "[+] Verifying replication thread status..."
sleep 2

IO_RUNNING=$(${MYSQL_CMD} -e "SHOW SLAVE STATUS\G" | grep "Slave_IO_Running:" | awk '{print $2}')
SQL_RUNNING=$(${MYSQL_CMD} -e "SHOW SLAVE STATUS\G" | grep "Slave_SQL_Running:" | awk '{print $2}')

echo ""
echo "=========================================================="
echo " Replica Configuration Summary:"
echo " Slave_IO_Running:  ${IO_RUNNING}"
echo " Slave_SQL_Running: ${SQL_RUNNING}"
echo "=========================================================="

if [ "${IO_RUNNING}" == "Yes" ] && [ "${SQL_RUNNING}" == "Yes" ]; then
    echo "SUCCESS: Replication is active!"
    echo "Replicated dummy database contents:"
    ${MYSQL_CMD} -e "SELECT * FROM app_db.users;" 2>/dev/null || echo "Data synchronizing..."
else
    echo "WARNING: Replication failed to start properly."
    echo "Check error logs with: mysql -u root -p${MYSQL_ROOT_PASS} -e 'SHOW SLAVE STATUS\G'"
fi
