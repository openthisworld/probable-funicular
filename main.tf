resource "aws_eks_cluster" "example" {
  name     = "example-cluster"
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids = [aws_subnet.example_subnet1.id, aws_subnet.example_subnet2.id]
    security_group_ids = [aws_security_group.example_sg.id]
  }

}

resource "aws_iam_role" "eks" {
  name = "example-eks"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "kubernetes_deployment" "example" {
  metadata {
    name = "example-deployment"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        App = "example-app"
      }
    }

    template {
      metadata {
        labels = {
          App = "example-app"
        }
      }

      spec {
        container {
          image = "openthisworld/probable-funicular:latest"
          name  = "example"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}
