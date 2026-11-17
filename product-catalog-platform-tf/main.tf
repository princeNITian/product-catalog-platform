
# ------------------------------------------------
# DynamoDB
# ------------------------------------------------

resource "aws_dynamodb_table" "products" {
  name         = "${var.project_name}-products"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "productId"

  attribute {
    name = "productId"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}

# ------------------------------------------------
# Package Lambda application
# ------------------------------------------------

data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/../dist"
  output_path = "${path.module}/product-catalog.zip"
}

# ------------------------------------------------
# IAM Role
# ------------------------------------------------

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "lambda.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

# CloudWatch logging permissions

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = aws_iam_role.lambda_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB permissions

resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.project_name}-dynamodb-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem"
      ]

      Resource = aws_dynamodb_table.products.arn
    }]
  })
}

# ------------------------------------------------
# CloudWatch Log Groups
# ------------------------------------------------

resource "aws_cloudwatch_log_group" "create_product" {
  name              = "/aws/lambda/${var.project_name}-create-product"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "get_product" {
  name              = "/aws/lambda/${var.project_name}-get-product"
  retention_in_days = 7
}

# ------------------------------------------------
# Lambda: Create Product
# ------------------------------------------------

resource "aws_lambda_function" "create_product" {
  function_name = "${var.project_name}-create-product"

  role    = aws_iam_role.lambda_role.arn
  runtime = "nodejs22.x"
  handler = "create-product.handler"

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      PRODUCTS_TABLE = aws_dynamodb_table.products.name
      VALKEY_HOST    = aws_elasticache_serverless_cache.valkey.endpoint[0].address
      VALKEY_PORT    = tostring(aws_elasticache_serverless_cache.valkey.endpoint[0].port)
      VALKEY_TLS     = "true"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy.dynamodb_access,
    aws_cloudwatch_log_group.create_product,
    aws_iam_role_policy_attachment.lambda_vpc_access
  ]

  vpc_config {
    subnet_ids = aws_subnet.private[*].id

    security_group_ids = [
      aws_security_group.lambda.id
    ]
  }
}

# ------------------------------------------------
# Lambda: Get Product
# ------------------------------------------------

resource "aws_lambda_function" "get_product" {
  function_name = "${var.project_name}-get-product"

  role    = aws_iam_role.lambda_role.arn
  runtime = "nodejs22.x"
  handler = "get-product.handler"

  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      PRODUCTS_TABLE = aws_dynamodb_table.products.name
      VALKEY_HOST    = aws_elasticache_serverless_cache.valkey.endpoint[0].address
      VALKEY_PORT    = tostring(aws_elasticache_serverless_cache.valkey.endpoint[0].port)
      VALKEY_TLS     = "true"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy.dynamodb_access,
    aws_cloudwatch_log_group.get_product,
    aws_iam_role_policy_attachment.lambda_vpc_access
  ]

  vpc_config {
    subnet_ids = aws_subnet.private[*].id

    security_group_ids = [
      aws_security_group.lambda.id
    ]
  }
}

# ------------------------------------------------
# API Gateway HTTP API
# ------------------------------------------------

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

# ------------------------------------------------
# API Integrations
# ------------------------------------------------

resource "aws_apigatewayv2_integration" "create_product" {
  api_id = aws_apigatewayv2_api.api.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.create_product.invoke_arn

  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "get_product" {
  api_id = aws_apigatewayv2_api.api.id

  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.get_product.invoke_arn

  payload_format_version = "2.0"
}

# ------------------------------------------------
# API Routes
# ------------------------------------------------

resource "aws_apigatewayv2_route" "create_product" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /products"

  target = "integrations/${aws_apigatewayv2_integration.create_product.id}"
}

resource "aws_apigatewayv2_route" "get_product" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /products/{productId}"

  target = "integrations/${aws_apigatewayv2_integration.get_product.id}"
}

# ------------------------------------------------
# API Stage
# ------------------------------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# ------------------------------------------------
# Allow API Gateway to invoke Lambda
# ------------------------------------------------

resource "aws_lambda_permission" "create_product" {
  statement_id  = "AllowApiGatewayCreateProduct"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_product.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get_product" {
  statement_id  = "AllowApiGatewayGetProduct"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_product.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role = aws_iam_role.lambda_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}