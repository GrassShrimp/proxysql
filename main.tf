resource "kubernetes_config_map" "mysql_example_sql" {
  metadata {
    name = "mysqlsampledatabase.sql"
    namespace = "default"
  }

  data = {
    "mysqlsampledatabase.sql" = file("${path.module}/mysqlsampledatabase.sql")
  }
}

resource "kubernetes_stateful_set" "mysql" {
  metadata {
    name      = "mysql"
    namespace = "default"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        volume {
          name = "example-sql"

          config_map {
            name = kubernetes_config_map.mysql_example_sql.metadata[0].name

            items {
              key  = "mysqlsampledatabase.sql"
              path = "mysqlsampledatabase.sql"
            }
          }
        }

        container {
          name  = "mysql"
          image = "mysql:5.7"

          port {
            name           = "mysql"
            container_port = 3306
          }

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = "root"
          }

          env {
            name  = "MYSQL_DATABASE"
            value = "classicmodels"
          }

          env {
            name  = "MYSQL_USER"
            value = "demo"
          }

          env {
            name  = "MYSQL_PASSWORD"
            value = "demo"
          }

          volume_mount {
            name       = "mysql"
            mount_path = "/var/lib/mysql"
          }

          volume_mount {
            name       = "example-sql"
            mount_path = "/docker-entrypoint-initdb.d"
          }
        }

        termination_grace_period_seconds = 10
      }
    }

    volume_claim_template {
      metadata {
        name = "mysql"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "10Gi"
          }
        }

        storage_class_name = "hostpath"
      }
    }

    service_name = "mysql"
  }
}

resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql"
    namespace = "default"
  }

  spec {
    port {
      name        = "mysql"
      protocol    = "TCP"
      port        = 3306
      target_port = kubernetes_stateful_set.mysql.spec[0].template[0].spec[0].container[0].port[0].name
    }

    selector = {
      app = kubernetes_stateful_set.mysql.spec[0].template[0].metadata[0].labels.app
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service" "proxysql" {
  metadata {
    name      = "proxysql"
    namespace = "default"
  }

  spec {
    port {
      name        = "mysql"
      protocol    = "TCP"
      port        = 6033
      target_port = "mysql"
    }

    port {
      name        = "restful"
      protocol    = "TCP"
      port        = 6070
      target_port = "restful"
    }

    selector = {
      app = "proxysql"
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_service" "proxysql-admin" {
  metadata {
    name      = "proxysql-admin"
    namespace = "default"
  }

  spec {
    port {
      name        = "admin"
      protocol    = "TCP"
      port        = 6032
      target_port = "admin"
    }

    selector = {
      app = "proxysql"
    }

    cluster_ip = "None"
    type       = "ClusterIP"
  }
}

resource "kubernetes_config_map" "proxysql" {
  metadata {
    name = "proxysql.cnf"
    namespace = "default"
  }

  data = {
    "proxysql.cnf" = file("${path.module}/proxysql.cnf")
  }
}

resource "kubernetes_stateful_set" "proxysql" {
  metadata {
    name      = "proxysql"
    namespace = "default"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "proxysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "proxysql"
        }
      }

      spec {
        volume {
          name = "proxysql-cnf"

          config_map {
            name = kubernetes_config_map.proxysql.metadata[0].name

            items {
              key  = "proxysql.cnf"
              path = "proxysql.cnf"
            }
          }
        }

        container {
          name  = "proxysql"
          image = "proxysql/proxysql:2.1.0"

          port {
            name           = kubernetes_service.proxysql-admin.spec[0].port[0].target_port
            container_port = 6032
          }

          port {
            name           = kubernetes_service.proxysql.spec[0].port[0].target_port
            container_port = 6033
          }

          port {
            name           = kubernetes_service.proxysql.spec[0].port[1].target_port
            container_port = 6070
          }

          volume_mount {
            name       = "proxysql-cnf"
            mount_path = "/etc/proxysql.cnf"
            sub_path   = "proxysql.cnf"
          }
        }

        termination_grace_period_seconds = 10
      }
    }

    service_name = "proxysql"
  }
}