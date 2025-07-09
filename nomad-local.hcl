datacenter = "dc1"
data_dir = "/tmp/nomad-data"

# Bind to localhost for dev
bind_addr = "127.0.0.1"

advertise {
  http = "127.0.0.1"
  rpc = "127.0.0.1"
  serf = "127.0.0.1"
}

# Enable dev mode but with proper CPU detection
server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true
  
  # Fix CPU detection - let Nomad auto-detect instead of limiting to 28 MHz
  # Based on Context7 research: M4 has 4 performance cores @ 4GHz + 6 efficiency cores @ 2GHz
  # Total: (4 * 4000) + (6 * 2000) = 28000 MHz
  cpu_total_compute = 28000
}

ui {
  enabled = true
  bind_addr = "127.0.0.1"
  port = 4646
}

log_level = "INFO"