# Product Catalog API — AWS Serverless + Valkey

A hands-on serverless backend project built with **Node.js 22, TypeScript, AWS Lambda, API Gateway, DynamoDB, Amazon ElastiCache Serverless (Valkey), and Terraform**.

The project implements a product create/read API and a cache-aside read path. DynamoDB is the source of truth; Valkey is used to cache product reads for five minutes.

> **Implementation status:** The create and get endpoints are deployed and tested. The Valkey cache-miss, cache-hit, and TTL-expiration scenarios have been verified. Product update/delete endpoints, authentication, CI/CD, and production monitoring are not implemented yet.

## Architecture

```text
                         Public HTTPS
                              |
                              v
                    API Gateway HTTP API
                       /             \
              POST /products    GET /products/{productId}
                    |                    |
                    v                    v
             Create Lambda          Get Lambda
                    |                    |
                    |              Cache-aside read
                    |                    |
                    |              +-----+------+
                    |              |            |
                    |              v            v
                    |           Valkey       DynamoDB
                    |          (ElastiCache)  (source of truth)
                    |              |            |
                    |          Cache hit     Cache miss
                    |              |            |
                    |              |<-- populate cache
                    |              |
                    +--------------+------------+

        Lambda functions run in private VPC subnets.
        DynamoDB Gateway Endpoint and CloudWatch Logs
        Interface Endpoint provide private service access.
```

### AWS resources provisioned by Terraform

- **API Gateway HTTP API** with `POST /products` and `GET /products/{productId}` routes.
- **Two AWS Lambda functions** using the Node.js 22 runtime.
- **DynamoDB** table using on-demand (`PAY_PER_REQUEST`) billing.
- **ElastiCache Serverless for Valkey**.
- **VPC** with two private subnets across two Availability Zones.
- **Security groups** controlling Lambda-to-Valkey and Lambda-to-endpoint traffic.
- **DynamoDB Gateway VPC endpoint** associated with the private route table.
- **CloudWatch Logs Interface VPC endpoint** with private DNS.
- **IAM execution role and policies** for Lambda logging, VPC networking, and DynamoDB access.
- **CloudWatch log groups** with seven-day retention.

The project currently has no NAT Gateway or Internet Gateway. The DynamoDB gateway endpoint and CloudWatch Logs interface endpoint provide the service connectivity needed by the deployed functions.

## Technology stack

| Area | Technology |
|---|---|
| Language | TypeScript |
| Runtime | Node.js 22 |
| Compute | AWS Lambda |
| API | Amazon API Gateway HTTP API |
| Primary data store | Amazon DynamoDB |
| Cache | Amazon ElastiCache Serverless for Valkey |
| Cache client | `redis` (Node.js Redis client) |
| Infrastructure as code | Terraform |
| Build | esbuild |
| Region | `ap-south-1` (Mumbai) |

## Repository layout

Keep application code and infrastructure in separate sibling directories:

```text
.
├── product-catalog-platform/       # Application
│   ├── src/
│   │   ├── cache/
│   │   │   ├── valkey.client.ts
│   │   │   └── product-cache.ts
│   │   ├── handlers/
│   │   │   ├── create-product.ts
│   │   │   └── get-product.ts
│   │   ├── repositories/
│   │   │   └── product.repository.ts
│   │   ├── services/
│   │   │   └── product.service.ts
│   │   └── types/
│   │       └── product.ts
│   ├── tests/
│   ├── package.json
│   └── tsconfig.json
│
└── product-catalog-tf/              # Terraform infrastructure
    ├── providers.tf
    ├── variables.tf
    ├── main.tf
    ├── networking.tf
    ├── elasticache.tf
    ├── outputs.tf
    └── .gitignore
```

Terraform packages the built application from `../product-catalog-platform/dist` into a deployment ZIP and deploys that package to both Lambda functions.

## API

Retrieve the deployed API endpoint from Terraform:

```bash
cd product-catalog-tf
terraform output -raw api_endpoint
```

### 1. Create a product

**Request**

```http
POST /products
Content-Type: application/json
```

Example:

```bash
API_URL="$(cd ../product-catalog-tf && terraform output -raw api_endpoint)"

curl -X POST "$API_URL/products" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Wireless Mouse",
    "category": "Electronics",
    "price": 799,
    "stock": 100
  }'
```

The service validates the input, generates a product ID, and stores the product in DynamoDB.

Example response shape:

```json
{
  "productId": "<generated-product-id>",
  "name": "Wireless Mouse",
  "category": "Electronics",
  "price": 799,
  "stock": 100,
  "createdAt": "<ISO-8601-timestamp>"
}
```

The exact generated ID and timestamp will differ for each request.

### 2. Get a product

```http
GET /products/{productId}
```

```bash
PRODUCT_ID="<product-id-from-create-response>"

curl "$API_URL/products/$PRODUCT_ID"
```

Possible outcomes:

- `200 OK` — product found.
- `404 Not Found` — product does not exist.
- `400 Bad Request` — invalid or missing product ID.
- `500 Internal Server Error` — unexpected server-side failure.

## Cache implementation

The GET operation uses the **cache-aside** pattern.

1. The service checks Valkey for `product:{productId}`.
2. If the key exists, the cached product is returned.
3. If the key is absent, the service reads the product from DynamoDB.
4. If DynamoDB returns a product, the service stores it in Valkey.
5. The cache entry expires automatically after **300 seconds (5 minutes)**.

```text
GET product
    |
    v
Look up product:{productId} in Valkey
    |
    +---- Cache hit ----> Return cached product
    |
    +---- Cache miss ---> Read from DynamoDB
                              |
                              v
                       Product found?
                         /       \
                       Yes        No
                        |          |
                  Set Valkey      Return 404
                  with 300s TTL
                        |
                        v
                   Return product
```

### Cache resilience

The service is designed to **fail open** for cache read/write errors:

- If a Valkey read fails, the service logs the error and attempts to read from DynamoDB.
- If a Valkey write fails, the service logs the error but still returns the DynamoDB result.
- DynamoDB remains the source of truth.

The Valkey client uses TLS and a cluster-aware client connection suitable for the ElastiCache Serverless Valkey deployment. The Lambda execution environment can reuse the connection across warm invocations.

### Verified cache scenarios

| Scenario | Expected behaviour | Status |
|---|---|---|
| First GET after product creation | Cache miss; read DynamoDB; populate Valkey | Verified |
| Second GET | Cache hit; return cached product | Verified |
| GET after five-minute TTL | Cache miss; fetch and repopulate | Verified |

Cache invalidation after product updates is a planned next milestone. There is currently no update endpoint, so stale-cache invalidation for writes has not yet been implemented.

## Local development

### Prerequisites

Install and configure:

- Node.js 22 and npm
- AWS CLI with credentials authorized for the target AWS account
- Terraform CLI (version 1.5 or later)
- An AWS account with permission to create the resources described above

Confirm the CLI configuration:

```bash
node --version
npm --version
aws --version
terraform version
aws sts get-caller-identity
aws configure get region
```

The configured deployment region is `ap-south-1`.

### Install application dependencies

```bash
cd product-catalog-platform
npm install
```

The application uses the AWS SDK v3 DynamoDB clients and the `redis` package.

### Type-check and build

Run from `product-catalog-platform/`:

```bash
npm run typecheck
npm run build
```

The build output is written to `dist/`. Terraform uses this directory as the Lambda deployment package source.

### Deploy infrastructure and application

Run the following from `product-catalog-tf/`:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

Review the plan carefully before applying. Then deploy:

```bash
terraform apply
```

Terraform creates or updates the AWS resources and packages the application build for Lambda.

Useful outputs:

```bash
terraform output
terraform output -raw api_endpoint
terraform output -raw products_table_name
terraform output -raw create_lambda_name
terraform output -raw get_lambda_name
terraform output -raw valkey_endpoint
terraform output -raw valkey_port
terraform output -raw valkey_status
```

Rebuild the application and run `terraform apply` again whenever you change Lambda application code.

## Observability and troubleshooting

### Follow the GET Lambda logs

```bash
aws logs tail /aws/lambda/product-catalog-get-product \
  --since 10m \
  --follow
```

The service logs cache events such as:

```text
CACHE HIT: <product-id>
CACHE MISS: <product-id>
CACHE POPULATED: <product-id>
```

It also logs cache read/write failures and falls back to DynamoDB for cache errors.

### Check Lambda deployment status

```bash
aws lambda get-function-configuration \
  --function-name product-catalog-get-product \
  --query "{State:State,LastUpdateStatus:LastUpdateStatus,Environment:Environment.Variables,VpcConfig:VpcConfig}" \
  --output json
```

### Check Valkey status

```bash
aws elasticache describe-serverless-caches \
  --serverless-cache-name product-catalog-valkey \
  --query "ServerlessCaches[0].{Name:ServerlessCacheName,Engine:Engine,Status:Status,Endpoint:Endpoint,SubnetIds:SubnetIds}" \
  --output json
```

## Security notes

This is a learning project, not yet a production-ready public API.

- The API currently has no authentication or authorization.
- Do not put AWS credentials, secrets, Terraform state, or generated deployment ZIPs in source control.
- Lambda functions run in private subnets and access Valkey through security-group rules.
- Valkey connections use TLS.
- IAM permissions should remain least-privilege and be reviewed as the application grows.
- Add request throttling, authentication, input-size limits, alarms, and appropriate data protection before production use.

## Cost considerations

Some resources incur ongoing charges even when the API receives no traffic. In particular:

- ElastiCache Serverless Valkey incurs charges based on storage and ECPU usage.
- The CloudWatch Logs interface VPC endpoint incurs hourly and data-processing charges.
- DynamoDB on-demand billing, Lambda, API Gateway, and CloudWatch Logs have usage-based charges.

The Valkey usage limits configured in Terraform are service usage caps, **not a guaranteed fixed monthly bill limit**. Check current AWS pricing for `ap-south-1` and review Cost Explorer/Billing before leaving the environment running.

If you have finished experimenting and no longer need the environment, Terraform can remove the resources it manages:

```bash
cd product-catalog-tf
terraform plan -destroy
```

Review the destruction plan carefully. If it is expected and you are ready to remove the environment:

```bash
terraform destroy
```

This removes the deployed infrastructure. Do not run it if you want to keep the API or its data. Back up any data you need before destroying resources.

## Planned next milestones

- Add `PUT /products/{productId}` and invalidate the corresponding Valkey key after a successful DynamoDB update.
- Add `DELETE /products/{productId}` with cache invalidation.
- Add negative caching for missing product IDs.
- Improve cache stampede protection and Redis client lifecycle/reconnection handling.
- Test fail-open behaviour when Valkey is unavailable.
- Measure cache-hit ratio and compare DynamoDB-only versus cached request latency.
- Add CloudWatch metrics, dashboards, and alarms.
- Add authentication/authorization and API throttling.
- Add CI/CD and improve Terraform state management for team use.

---

**Core learning outcomes so far:** serverless API design, DynamoDB persistence, Lambda IAM execution roles, VPC networking, private service endpoints, security groups, Terraform-based infrastructure provisioning, Valkey cluster-aware connectivity, TLS, cache-aside, TTL expiration, and cache failure fallback.
