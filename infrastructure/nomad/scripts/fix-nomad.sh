#!/bin/bash
# Script to fix Nomad installation on EC2 instances

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Stop services
systemctl stop nomad || true
systemctl stop consul || true

# Fix Nomad configuration
cat > /etc/nomad.d/nomad.hcl <<EOF
datacenter = "${REGION}"
data_dir   = "/opt/nomad/data"
log_level  = "INFO"
bind_addr  = "0.0.0.0"
advertise {
  http = "${LOCAL_IPV4}"
  rpc  = "${LOCAL_IPV4}"
  serf = "${LOCAL_IPV4}"
}

server {
  enabled          = true
  bootstrap_expect = 3
}

client {
  enabled = false
}

ui {
  enabled = true
}
EOF

# Start Nomad
systemctl start nomad

# Wait for Nomad to start
sleep 10

# Check status
nomad server members