
output "api_endpoint" {
  description = "Product Catalog API endpoint"
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "products_table_name" {
  value = aws_dynamodb_table.products.name
}

output "create_lambda_name" {
  value = aws_lambda_function.create_product.function_name
}

output "get_lambda_name" {
  value = aws_lambda_function.get_product.function_name
}

output "valkey_endpoint" {
  description = "Valkey cache endpoint"
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].address
}

output "valkey_port" {
  description = "Valkey cache port"
  value       = aws_elasticache_serverless_cache.valkey.endpoint[0].port
}

output "valkey_status" {
  description = "Valkey cache status"
  value       = aws_elasticache_serverless_cache.valkey.status
}
