
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
