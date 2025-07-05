job "gengine-rest-api" {
  datacenters = ["us-west-2"]
  type        = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "api" {
    count = 1

    network {
      port "http" {
        static = 8000
        to     = 8000
      }
    }


    task "gengine-api" {
      driver = "docker"

      config {
        image = "549574275832.dkr.ecr.us-west-2.amazonaws.com/gengine-rest-api:amd64"
        ports = ["http"]
        auth_soft_fail = true
      }

      resources {
        cpu    = 500
        memory = 512
      }

      env {
        ENVIRONMENT = "development"
        LOG_LEVEL   = "INFO"
      }
    }
  }
}