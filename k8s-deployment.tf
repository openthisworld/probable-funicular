provider "kubernetes" {
  host                   = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.cluster.name
}

resource "kubernetes_deployment" "openthisworld_app" {
  metadata {
    name = "openthisworld-app"
  }

  spec {
    replicas = 10

    selector {
      match_labels = {
        app = "openthisworld"
      }
    }

    template {
      metadata {
        labels = {
          app = "openthisworld"
        }
      }

        spec {
        containers {
            image = "openthisworld/probable-funicular:latest"
            name  = "openthisworld"

            ports {
            containerPort = 5000
            }

            livenessProbe {
            httpGet {
                path = "/"
                port = "http"
            }
            initialDelaySeconds = 3
            periodSeconds       = 3
            }

            readinessProbe {
            httpGet {
                path = "/"
                port = "http"
            }
            initialDelaySeconds = 3
            periodSeconds       = 3
            }
        }
        }


    }
  }
}
