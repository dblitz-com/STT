job "test-health" {
  datacenters = ["us-west-2"]
  type        = "service"

  group "health" {
    count = 1

    network {
      port "http" {
        static = 8000
        to     = 80
      }
    }

    service {
      name = "test-health"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:alpine"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}