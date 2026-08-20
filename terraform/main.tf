terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "google" {
  project = "gcptraining2121ttt"
  region  = "us-central1"
}

resource "google_artifact_registry_repository" "order_api_repo" {
  location      = "us-central1"
  repository_id = "task-api-repo"
  description   = "Docker images for task management API"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository" "order_processor_repo" {
  location      = "us-central1"
  repository_id = "order-processor-repo"
  description   = "Docker images for order processor"
  format        = "DOCKER"
}

resource "google_firestore_database" "default" {
  name        = "(default)"
  location_id = "us-central1"
  type        = "FIRESTORE_NATIVE"
}

resource "google_service_account" "task_api_runtime" {
  account_id   = "task-api-runtime"
  display_name = "Task Management API Runtime"
}

resource "google_service_account" "order_processor_runtime" {
  account_id   = "order-processor-runtime"
  display_name = "Order Processor Runtime"
}

resource "google_project_iam_member" "task_api_firestore" {
  project = "gcptraining2121ttt"
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.task_api_runtime.email}"
}

resource "google_project_iam_member" "order_processor_firestore" {
  project = "gcptraining2121ttt"
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.order_processor_runtime.email}"
}

resource "google_cloud_run_v2_service" "task_api" {
  name     = "task-management-api"
  location = "us-central1"

  template {
    containers {
      image = "us-central1-docker.pkg.dev/gcptraining2121ttt/task-api-repo/task-management-api:v1"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }

        cpu_idle          = true
        startup_cpu_boost = true
      }
    }

    service_account = google_service_account.task_api_runtime.email
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version
    ]
  }
}

resource "google_cloud_run_v2_service" "order_processor" {
  name     = "order-processor"
  location = "us-central1"

  template {
    containers {
      image = "us-central1-docker.pkg.dev/gcptraining2121ttt/order-processor-repo/order-processor:v3"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }

        cpu_idle          = true
        startup_cpu_boost = true
      }
    }

    service_account = google_service_account.order_processor_runtime.email
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version
    ]
  }
}

resource "google_pubsub_topic" "orders_created" {
  name = "orders-created"
}

resource "google_pubsub_topic" "orders_created_dlq" {
  name = "orders-created-dlq"
}

resource "google_pubsub_subscription" "orders_created_push" {
  name  = "orders-created-push"
  topic = google_pubsub_topic.orders_created.id

  push_config {
    push_endpoint = "https://order-processor-783181616350.us-central1.run.app/pubsub"

    oidc_token {
      service_account_email = google_service_account.order_processor_runtime.email
    }
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.orders_created_dlq.id
    max_delivery_attempts = 5
  }

  ack_deadline_seconds = 10
}

resource "google_pubsub_subscription" "orders_created_dlq" {
  name  = "orders-created-dlq-sub"
  topic = google_pubsub_topic.orders_created_dlq.id
}

resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  project = "gcptraining2121ttt"
  topic   = google_pubsub_topic.orders_created_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-783181616350@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "push_subscriber" {
  subscription = google_pubsub_subscription.orders_created_push.id
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-783181616350@gcp-sa-pubsub.iam.gserviceaccount.com"
}