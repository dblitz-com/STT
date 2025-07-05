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

# Create nomad user
useradd --system --home /etc/nomad.d --shell /bin/false nomad

# Create directories
mkdir -p /opt/nomad/data
mkdir -p /etc/nomad.d
mkdir -p /opt/nomad/plugins
chown -R nomad:nomad /opt/nomad
chown -R nomad:nomad /etc/nomad.d

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Get gossip key from SSM
GOSSIP_KEY=$(aws ssm get-parameter \
  --region ${region} \
  --name "/${cluster_name}/nomad/gossip-key" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

# Configure Nomad Client
cat > /etc/nomad.d/nomad.hcl <<EOF
datacenter = "${region}"
data_dir   = "/opt/nomad/data"
log_level  = "INFO"
node_name  = "$INSTANCE_ID"
bind_addr  = "$LOCAL_IPV4"

client {
  enabled = true
  
  # Server addresses for client to connect
  servers = ["provider=aws tag_key=Name tag_value=${cluster_name}-server region=${region}"]
  
  # Node metadata
  meta {
    "instance_type" = "$(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
    "availability_zone" = "$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
    "instance_id" = "$INSTANCE_ID"
  }
  
  # Host volumes for workspace persistence
  host_volume "workspace" {
    path      = "/opt/nomad/workspace"
    read_only = false
  }
  
  # Resource configuration
  reserved {
    cpu    = 500
    memory = 512
  }
  
  # Network configuration
  network_interface = "eth0"
  
  # Options for different drivers
  options {
    "driver.allowlist" = "docker,exec,java"
    "docker.privileged.enabled" = "true"
    "docker.volumes.enabled" = "true"
  }
}

server {
  enabled = false
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

# ACL configuration
acl {
  enabled = true
}
EOF

%{ if consul_enabled }
# Configure Consul Client
mkdir -p /opt/consul/data
mkdir -p /etc/consul.d
useradd --system --home /etc/consul.d --shell /bin/false consul || true
chown -R consul:consul /opt/consul
chown -R consul:consul /etc/consul.d

# Get Consul gossip key
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
server = false
bind_addr = "$LOCAL_IPV4"
client_addr = "0.0.0.0"
retry_join = ["provider=aws tag_key=Name tag_value=${cluster_name}-server region=${region}"]
encrypt = "$CONSUL_GOSSIP_KEY"
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

# Install CSI plugins
%{ if enable_csi_drivers }
# Install EBS CSI Plugin
mkdir -p /opt/nomad/plugins
wget https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/v1.25.0/aws-ebs-csi-driver.zip
unzip aws-ebs-csi-driver.zip -d /opt/nomad/plugins/
chmod +x /opt/nomad/plugins/aws-ebs-csi-driver

# Install EFS CSI Plugin
wget https://github.com/kubernetes-sigs/aws-efs-csi-driver/releases/download/v1.7.1/aws-efs-csi-driver.zip
unzip aws-efs-csi-driver.zip -d /opt/nomad/plugins/
chmod +x /opt/nomad/plugins/aws-efs-csi-driver
%{ endif }

# Create workspace directory
mkdir -p /opt/nomad/workspace
chown -R nomad:nomad /opt/nomad/workspace

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

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

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
    "namespace": "Nomad/Client",
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
      },
      "docker": {
        "measurement": [
          "docker_container_cpu",
          "docker_container_mem"
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
            "log_group_name": "/${cluster_name}/nomad-client",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/opt/nomad/data/alloc/*/alloc/logs/*.std*",
            "log_group_name": "/${cluster_name}/nomad-tasks",
            "log_stream_name": "{instance_id}",
            "multi_line_start_pattern": "^[0-9]{4}-[0-9]{2}-[0-9]{2}"
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

# Install Prometheus Node Exporter
useradd --no-create-home --shell /bin/false node_exporter || true
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create Node Exporter systemd service
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl enable node_exporter
systemctl start node_exporter

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

# Optimize system for container workloads
echo 'net.bridge.bridge-nf-call-iptables = 1' >> /etc/sysctl.conf
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

echo "Nomad client setup complete"