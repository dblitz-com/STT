job "test-api" {
  datacenters = ["us-west-2"]
  type        = "service"

  group "api" {
    count = 1

    network {
      port "http" {
        static = 8000
        to     = 80
      }
    }

    service {
      name = "test-api"
      port = "http"

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
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