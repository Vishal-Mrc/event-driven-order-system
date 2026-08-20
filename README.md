# Event-Driven Order System

A cloud-native, event-driven order processing system built with **Node.js, Express, Google Cloud Pub/Sub, Firestore and Cloud Run**.

The system demonstrates asynchronous messaging, authenticated Pub/Sub push delivery, retry handling, dead-letter queues, containerization, CI/CD, Infrastructure as Code and cloud monitoring.

---

## 🚀 Project Overview

The application accepts orders through a REST API and publishes each order as an event to Google Cloud Pub/Sub.

A separate private Cloud Run service consumes the event and stores the processed order in Firestore.

If processing fails, Pub/Sub automatically retries the message. After five unsuccessful delivery attempts, the message is forwarded to a dead-letter topic for later inspection or recovery.

### Core flow

```text
Client
  ↓
Order API
  ↓
Pub/Sub
  ↓
Authenticated Push Subscription
  ↓
Order Processor
  ↓
Firestore
```

### Failure flow

```text
Order Processor
      ↓
   Processing failure
      ↓
   Pub/Sub retry
      ↓
   Retry
      ↓
   Retry
      ↓
   Retry
      ↓
   Retry
      ↓
Dead-Letter Topic
```

---

# 🏗️ Architecture

## Application Architecture

```text
                         ┌─────────────────┐
                         │     Client      │
                         │ Browser/Postman │
                         └────────┬────────┘
                                  │
                                  │ POST /orders
                                  ▼
                         ┌─────────────────┐
                         │    Order API    │
                         │ Node.js/Express │
                         │    Cloud Run    │
                         └────────┬────────┘
                                  │
                                  │ Publish event
                                  ▼
                         ┌─────────────────┐
                         │     Pub/Sub     │
                         │ orders-created  │
                         └────────┬────────┘
                                  │
                                  │ Authenticated push
                                  ▼
                         ┌─────────────────┐
                         │ Order Processor │
                         │    Cloud Run    │
                         │     Private     │
                         └────────┬────────┘
                                  │
                                  │ Write processed order
                                  ▼
                         ┌─────────────────┐
                         │    Firestore    │
                         │     orders      │
                         └─────────────────┘
```

## Failure Handling

```text
                    Order Processor
                          │
                    processing fails
                          │
                          ▼
                     Pub/Sub retry
                          │
                     max 5 attempts
                          │
                          ▼
               ┌─────────────────────┐
               │ orders-created-dlq  │
               │    Dead-letter      │
               │       Topic         │
               └──────────┬──────────┘
                          │
                          ▼
               orders-created-dlq-sub
```

---

# ☁️ Google Cloud Services

The project uses:

* Google Cloud Run
* Google Cloud Pub/Sub
* Google Cloud Firestore
* Google Artifact Registry
* Google Cloud Monitoring
* Google Cloud IAM

---

# 🧰 Technologies

## Application

* Node.js
* Express
* JavaScript
* REST API

## Event-driven architecture

* Pub/Sub topics
* Pub/Sub subscriptions
* Push delivery
* Retry handling
* Dead-letter queues

## DevOps

* Docker
* Git
* GitHub
* GitHub Actions
* Workload Identity Federation
* Terraform

---

# 📡 Order API

The Order API is responsible for accepting orders and publishing them as Pub/Sub events.

## Endpoints

| Method | Endpoint  | Description                 |
| ------ | --------- | --------------------------- |
| GET    | `/health` | API health check            |
| POST   | `/orders` | Create and publish an order |

### Health check

```text
GET /health
```

Example:

```powershell
Invoke-RestMethod "http://localhost:8080/health"
```

Response:

```json
{
  "status": "healthy",
  "service": "order-api"
}
```

### Create an order

```text
POST /orders
```

Example request:

```json
{
  "customer": "Vishal",
  "items": [
    {
      "product": "Cloud Course",
      "quantity": 1
    }
  ],
  "total": 499
}
```

Example response:

```json
{
  "orderId": "order-1787219601762",
  "customer": "Vishal",
  "items": [
    {
      "product": "Cloud Course",
      "quantity": 1
    }
  ],
  "total": 499,
  "status": "accepted",
  "createdAt": "2026-08-20T09:53:21.762Z",
  "messageId": "20625236442093471"
}
```

The `messageId` confirms that the order was published successfully to Pub/Sub.

---

# 📨 Pub/Sub Architecture

## Main Topic

```text
orders-created
```

The Order API publishes every accepted order to this topic.

## Production Subscription

```text
orders-created-push
```

This subscription uses authenticated HTTPS push delivery to:

```text
https://order-processor-783181616350.us-central1.run.app/pubsub
```

The processor Cloud Run service is private and requires authenticated invocation.

## Dead-Letter Topic

```text
orders-created-dlq
```

Messages that repeatedly fail processing are forwarded here after five delivery attempts.

## Dead-Letter Subscription

```text
orders-created-dlq-sub
```

This subscription allows failed messages to be inspected and potentially recovered.

---

# 🔐 Authenticated Pub/Sub Push

The Order Processor is intentionally deployed as a **private Cloud Run service**.

Pub/Sub sends authenticated push requests using:

```text
order-processor-runtime@gcptraining2121ttt.iam.gserviceaccount.com
```

The runtime service account has permission to invoke the processor.

This creates the following security model:

```text
Public internet
      │
      ▼
Order API
      │
      ▼
Pub/Sub
      │
 authenticated push
      ▼
Private Order Processor
```

The processor is not exposed as a public API.

---

# 🔄 Event Processing

When an order is submitted:

```text
1. Client sends POST /orders
2. Order API validates the request
3. Order API creates an order ID
4. Order API publishes the order to Pub/Sub
5. Pub/Sub pushes the message to the processor
6. Processor decodes the Pub/Sub message
7. Processor writes the order to Firestore
8. Processor returns HTTP 204
9. Pub/Sub considers the message successfully processed
```

The processor stores fields including:

```text
orderId
customer
items
total
status
createdAt
processedAt
processingStatus
```

Example:

```json
{
  "orderId": "order-1787219601762",
  "customer": "Vishal",
  "total": 100,
  "status": "accepted",
  "createdAt": "2026-08-20T09:53:21.762Z",
  "processedAt": "2026-08-20T09:53:22.100Z",
  "processingStatus": "processed"
}
```

---

# ♻️ Retry Handling

Pub/Sub automatically retries messages when the processor does not acknowledge them successfully.

The production subscription is configured with:

```text
Maximum delivery attempts: 5
```

A processing failure results in:

```text
HTTP 500
```

which causes Pub/Sub to retry delivery.

Example:

```text
Attempt 1 → failure
Attempt 2 → failure
Attempt 3 → failure
Attempt 4 → failure
Attempt 5 → failure
              ↓
        Dead-letter topic
```

---

# 💀 Dead-Letter Queue

The dead-letter queue prevents repeatedly failing messages from remaining indefinitely in the normal processing path.

The architecture is:

```text
orders-created
      ↓
orders-created-push
      ↓
Order Processor
      ↓
processing failure
      ↓
5 retries
      ↓
orders-created-dlq
      ↓
orders-created-dlq-sub
```

The DLQ was tested using an intentional processor failure.

The resulting subscription message included:

```text
CloudPubSubDeadLetterSourceDeliveryCount=5
```

This confirmed that the message had reached the configured maximum delivery attempts before being forwarded to the dead-letter path.

---

# 🗄️ Firestore

Processed orders are stored in the existing Firestore `(default)` database.

Collection:

```text
orders
```

Example structure:

```text
orders
├── order-001
│   ├── customer
│   ├── items
│   ├── total
│   ├── status
│   ├── createdAt
│   ├── processedAt
│   └── processingStatus
│
└── order-002
    ├── customer
    ├── items
    ├── total
    ├── status
    ├── createdAt
    ├── processedAt
    └── processingStatus
```

---

# 🐳 Docker

Both services are containerized independently.

## Order API

Dockerfile:

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --omit=dev

COPY . .

ENV PORT=8080

EXPOSE 8080

CMD ["npm", "start"]
```

Build:

```bash
docker build -t order-api:v1 .
```

Run:

```bash
docker run --rm -p 8080:8080 order-api:v1
```

## Order Processor

The processor has its own Dockerfile and container image.

Build:

```bash
docker build -t order-processor:v1 ./order-processor
```

Run:

```bash
docker run --rm -p 8081:8080 order-processor:v1
```

---

# 📦 Artifact Registry

Two Artifact Registry repositories are used:

```text
task-api-repo
```

and:

```text
order-processor-repo
```

The services use separate repositories so their container images can be managed independently.

---

# ☁️ Cloud Run

Two Cloud Run services are deployed.

## Order API

```text
Service:
task-management-api

Region:
us-central1
```

The Order API is publicly accessible because it is the entry point for clients.

## Order Processor

```text
Service:
order-processor

Region:
us-central1
```

The Order Processor is private and receives requests from authenticated Pub/Sub push delivery.

---

# 🔐 IAM & Service Accounts

The application uses separate runtime service accounts.

## Order API

```text
task-api-runtime@gcptraining2121ttt.iam.gserviceaccount.com
```

Permission:

```text
roles/datastore.user
```

## Order Processor

```text
order-processor-runtime@gcptraining2121ttt.iam.gserviceaccount.com
```

Permission:

```text
roles/datastore.user
```

The Order Processor runtime account also has permission to invoke its private Cloud Run service as required for authenticated service interaction.

## Deployment identity

GitHub Actions uses:

```text
github-actions-deployer@gcptraining2121ttt.iam.gserviceaccount.com
```

Deployment permissions and application runtime permissions are deliberately separated.

---

# 🔑 Workload Identity Federation

GitHub Actions authenticates to Google Cloud using Workload Identity Federation rather than storing a long-lived service-account JSON key.

Authentication flow:

```text
GitHub Actions
      │
      ▼
GitHub OIDC
      │
      ▼
Workload Identity Federation
      │
      ▼
github-actions-deployer
      │
      ▼
Google Cloud
```

The provider is restricted to:

```text
Vishal-Mrc/event-driven-order-system
```

This limits which GitHub repository can use the deployment identity.

---

# 🔄 CI/CD

The repository uses GitHub Actions to deploy both Cloud Run services.

The workflow contains two deployment jobs:

```text
deploy-order-api
deploy-order-processor
```

### Order API pipeline

```text
Git push
   ↓
GitHub Actions
   ↓
Authenticate with Workload Identity Federation
   ↓
Docker build
   ↓
Artifact Registry
   ↓
Cloud Run
```

### Order Processor pipeline

```text
Git push
   ↓
GitHub Actions
   ↓
Authenticate with Workload Identity Federation
   ↓
Docker build
   ↓
Artifact Registry
   ↓
Private Cloud Run
```

Container images are tagged using the Git commit SHA.

This provides traceability between:

```text
Git commit
     ↓
Docker image
     ↓
Cloud Run revision
```

---

# 🏗️ Infrastructure as Code

Terraform manages the core infrastructure.

The Terraform configuration is located in:

```text
terraform/
├── main.tf
└── .terraform.lock.hcl
```

Terraform manages:

* Artifact Registry repositories
* Firestore
* Runtime service accounts
* Firestore IAM permissions
* Cloud Run services
* Pub/Sub topics
* Pub/Sub subscriptions
* Dead-letter topic
* Dead-letter subscription
* Pub/Sub IAM permissions

### Terraform workflow

```bash
terraform init
terraform validate
terraform plan
```

Existing infrastructure was imported into Terraform rather than recreated.

The final plan was verified with:

```text
No changes.
Your infrastructure matches the configuration.
```

### Infrastructure / application separation

Terraform manages cloud infrastructure while GitHub Actions manages application image deployment.

```text
Terraform
   ↓
Infrastructure

GitHub Actions
   ↓
Application images + Cloud Run deployment
```

The Cloud Run container image is ignored by Terraform so CI/CD can safely deploy new application versions without Terraform attempting to roll them back.

---

# 📊 Monitoring

Google Cloud Monitoring is used to observe the system.

Monitoring covers:

### Cloud Run

* Request count
* Request latency
* Errors
* Service availability

### Pub/Sub

* Unacknowledged messages
* Subscription backlog
* Dead-letter message activity

### Uptime

The public Order API health endpoint is monitored through an uptime check:

```text
/health
```

Example:

```text
https://task-management-api-783181616350.us-central1.run.app/health
```

### Alerts

The project includes alerting for important operational conditions such as:

* Pub/Sub backlog
* Dead-letter activity
* API availability

The dead-letter alert is particularly important because it indicates that order processing is repeatedly failing.

---

# 🧪 Testing

The project was tested at several levels.

## Local API testing

The Order API was tested with:

```text
GET /health
POST /orders
```

## Pub/Sub testing

The Pub/Sub topic and subscription were tested independently before connecting the services.

## Processor testing

The Order Processor was tested locally using simulated Pub/Sub push messages.

## Docker testing

The processor was run inside Docker and successfully wrote test events to Firestore.

## Production testing

A production order was sent through the live Order API and successfully processed through:

```text
Order API
   ↓
Pub/Sub
   ↓
Cloud Run Processor
   ↓
Firestore
```

## Failure testing

The dead-letter behavior was intentionally tested.

A controlled processor failure generated repeated HTTP 500 responses, and the message was eventually forwarded to the DLQ after five delivery attempts.

This verified that the retry and dead-letter configuration was functioning as expected.

---

# 🛠️ Troubleshooting & Lessons Learned

## Port conflicts during local development

Both services use port `8080` inside their containers.

When running both locally, the Order Processor was mapped to a different host port:

```text
Order API:
localhost:8080 → container:8080

Order Processor:
localhost:8081 → container:8080
```

This allowed both services to run simultaneously.

## Docker authentication

Local Docker containers do not automatically inherit the host machine's Application Default Credentials.

For local testing, credentials were mounted temporarily into the container rather than baked into the Docker image.

Production uses Cloud Run service accounts instead.

## Cloud Run service account permissions

GitHub Actions must have:

```text
roles/iam.serviceAccountUser
```

on the runtime service accounts it deploys with.

Without this permission, Cloud Run deployment fails with:

```text
iam.serviceaccounts.actAs denied
```

## Pub/Sub push security

The processor remains private.

Pub/Sub push requests use an authenticated service account and the Cloud Run service grants the required invoker permission.

---

# 📁 Project Structure

```text
event-driven-order-system/
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
├── order-processor/
│   ├── .dockerignore
│   ├── Dockerfile
│   ├── index.js
│   ├── package.json
│   └── package-lock.json
│
├── terraform/
│   ├── main.tf
│   └── .terraform.lock.hcl
│
├── .dockerignore
├── .gitignore
├── Dockerfile
├── index.js
├── package.json
├── package-lock.json
└── README.md
```

---

# 🚧 Future Improvements

Possible improvements include:

* Add automated unit and integration tests
* Add request schema validation
* Add idempotency protection for duplicate Pub/Sub deliveries
* Add order authentication
* Add structured logging
* Add Pub/Sub message ordering where required
* Add staging and production environments
* Add automated rollback strategies
* Add a DLQ replay/reprocessing tool
* Add OpenAPI/Swagger documentation
* Add more detailed alert notification channels
* Add additional business logic such as payment or inventory events

---

# 🎯 Project Status

| Component                    | Status                |
| ---------------------------- | --------------------- |
| Order API                    | ✅ Complete            |
| Order Processor              | ✅ Complete            |
| REST API                     | ✅ Complete            |
| Firestore                    | ✅ Complete            |
| Pub/Sub                      | ✅ Complete            |
| Authenticated push delivery  | ✅ Complete            |
| Retry handling               | ✅ Complete            |
| Dead-letter queue            | ✅ Complete            |
| Docker                       | ✅ Complete            |
| Artifact Registry            | ✅ Complete            |
| Cloud Run                    | ✅ Complete            |
| IAM                          | ✅ Complete            |
| Workload Identity Federation | ✅ Complete            |
| GitHub Actions CI/CD         | ✅ Complete            |
| Terraform                    | ✅ Complete            |
| Cloud Monitoring             | ✅ Complete            |
| Production testing           | ✅ Complete            |
| Automated unit tests         | 🚧 Future improvement |
| API authentication           | 🚧 Future improvement |
| DLQ replay tooling           | 🚧 Future improvement |

---

# 🎓 What This Project Demonstrates

This project demonstrates practical experience with:

```text
Cloud Run
Pub/Sub
Firestore
Docker
Artifact Registry
IAM
Workload Identity Federation
GitHub Actions
Terraform
Cloud Monitoring
Retry handling
Dead-letter queues
Event-driven architecture
```

More importantly, it demonstrates how these services work together as a complete system rather than as isolated cloud services.

---

# 🔗 Repository

GitHub:

https://github.com/Vishal-Mrc/event-driven-order-system

---

# 👨‍💻 About This Project

This project was built as part of a hands-on Cloud and DevOps portfolio.

The goal was to move beyond simple application deployment and demonstrate how a cloud-native system can handle asynchronous workloads, failures, retries, infrastructure management, automated deployments and monitoring.

The project was designed and tested using Google Cloud services and modern DevOps practices.
