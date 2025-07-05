#!/bin/bash
set -e

# Update system
yum update -y
yum install -y wget curl unzip jq docker awscli

# Configure Docker
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# Install Nomad
NOMAD_VERSION="1.7.2"
cd /tmp
wget https://releases.hashicorp.com/nomad/$${NOMAD_VERSION}/nomad_$${NOMAD_VERSION}_linux_amd64.zip
unzip nomad_$${NOMAD_VERSION}_linux_amd64.zip
mv nomad /usr/local/bin/
chmod +x /usr/local/bin/nomad

%{ if consul_enabled }
# Install Consul
CONSUL_VERSION="1.17.0"
wget https://releases.hashicorp.com/consul/$${CONSUL_VERSION}/consul_$${CONSUL_VERSION}_linux_amd64.zip
unzip consul_$${CONSUL_VERSION}_linux_amd64.zip
mv consul /usr/local/bin/
chmod +x /usr/local/bin/consul
%{ endif }

%{ if vault_enabled }
# Install Vault
VAULT_VERSION="1.15.4"
wget https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip
unzip vault_$${VAULT_VERSION}_linux_amd64.zip
mv vault /usr/local/bin/
chmod +x /usr/local/bin/vault
%{ endif }

# Create nomad user
useradd --system --home /etc/nomad.d --shell /bin/false nomad

# Create directories
mkdir -p /opt/nomad/data
mkdir -p /etc/nomad.d
chown -R nomad:nomad /opt/nomad
chown -R nomad:nomad /etc/nomad.d

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Generate gossip encryption key (for first server)
GOSSIP_KEY=$(nomad operator keygen)

# Store gossip key in SSM Parameter Store
aws ssm put-parameter \
  --region ${region} \
  --name "/${cluster_name}/nomad/gossip-key" \
  --value "$GOSSIP_KEY" \
  --type "SecureString" \
  --overwrite || echo "Key already exists"

# Retrieve gossip key
GOSSIP_KEY=$(aws ssm get-parameter \
  --region ${region} \
  --name "/${cluster_name}/nomad/gossip-key" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

# Configure Nomad Server
cat > /etc/nomad.d/nomad.hcl <<EOF
datacenter = "${region}"
data_dir   = "/opt/nomad/data"
log_level  = "INFO"
node_name  = "$INSTANCE_ID"
bind_addr  = "$LOCAL_IPV4"

server {
  enabled          = true
  bootstrap_expect = ${server_count}
  encrypt          = "$GOSSIP_KEY"
  
  # Server join configuration
  server_join {
    retry_join = ["provider=aws tag_key=Name tag_value=${cluster_name}-server region=${region}"]
  }
}

%{ if consul_enabled }
consul {
  address = "127.0.0.1:8500"
  server_service_name = "nomad"
  client_service_name = "nomad-client"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
}
%{ endif }

%{ if vault_enabled }
vault {
  enabled = true
  address = "${vault_address}"
}
%{ endif }

# UI configuration
ui_config {
  enabled = true
  
  consul {
    ui_url = "http://127.0.0.1:8500/ui"
  }
  
  %{ if vault_enabled }
  vault {
    ui_url = "${vault_address}/ui"
  }
  %{ endif }
}

# ACL configuration
acl {
  enabled = true
}

# Telemetry
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

# Plugin directory
plugin_dir = "/opt/nomad/plugins"

# Client configuration for scheduling workloads
client {
  enabled = false
}
EOF

%{ if consul_enabled }
# Configure Consul
mkdir -p /opt/consul/data
mkdir -p /etc/consul.d
chown -R consul:consul /opt/consul || useradd --system --home /etc/consul.d --shell /bin/false consul && chown -R consul:consul /opt/consul
chown -R consul:consul /etc/consul.d

# Generate Consul gossip key
CONSUL_GOSSIP_KEY=$(consul keygen)
aws ssm put-parameter \
  --region ${region} \
  --name "/${cluster_name}/consul/gossip-key" \
  --value "$CONSUL_GOSSIP_KEY" \
  --type "SecureString" \
  --overwrite || echo "Consul key already exists"

CONSUL_GOSSIP_KEY=$(aws ssm get-parameter \
  --region ${region} \
  --name "/${cluster_name}/consul/gossip-key" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

cat > /etc/consul.d/consul.hcl <<EOF
datacenter = "${region}"
data_dir = "/opt/consul/data"
log_level = "INFO"
node_name = "$INSTANCE_ID"
server = true
bootstrap_expect = ${server_count}
ui_config {
  enabled = true
}
bind_addr = "$LOCAL_IPV4"
client_addr = "0.0.0.0"
retry_join = ["provider=aws tag_key=Name tag_value=${cluster_name}-server region=${region}"]
encrypt = "$CONSUL_GOSSIP_KEY"
ca_file = "/etc/consul.d/consul-agent-ca.pem"
cert_file = "/etc/consul.d/consul-agent.pem"
key_file = "/etc/consul.d/consul-agent-key.pem"
verify_incoming = true
verify_outgoing = true
verify_server_hostname = true
acl = {
  enabled = true
  default_policy = "allow"
  enable_token_persistence = true
}
connect {
  enabled = true
}
ports {
  grpc = 8502
}
EOF

# Create Consul systemd service
cat > /etc/systemd/system/consul.service <<EOF
[Unit]
Description=Consul
Documentation=https://www.consul.io/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/consul.d/consul.hcl

[Service]
Type=notify
User=consul
Group=consul
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d/
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul
systemctl start consul
%{ endif }

# Create Nomad systemd service
cat > /etc/systemd/system/nomad.service <<EOF
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Requires=network-online.target
After=network-online.target
%{ if consul_enabled }
Wants=consul.service
After=consul.service
%{ endif }

[Service]
Type=notify
User=nomad
Group=nomad
ExecStart=/usr/local/bin/nomad agent -config=/etc/nomad.d/nomad.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Nomad
systemctl enable nomad
systemctl start nomad

# Install monitoring agents
%{ if enable_monitoring }
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "metrics": {
    "namespace": "Nomad/Server",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nomad.log",
            "log_group_name": "/${cluster_name}/nomad-server",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s
%{ endif }

# Setup log rotation
cat > /etc/logrotate.d/nomad <<EOF
/var/log/nomad.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 nomad nomad
    postrotate
        systemctl reload nomad
    endscript
}
EOF

echo "Nomad server setup complete"