resource "aws_api_gateway_rest_api" "certificates_api" {
  name        = "RecursosAPI"
  description = "API para gestión de certificados y registros"
}

# --- Configuración para Certificados ---
resource "aws_api_gateway_resource" "certificates_resource" {
  rest_api_id = aws_api_gateway_rest_api.certificates_api.id
  parent_id   = aws_api_gateway_rest_api.certificates_api.root_resource_id
  path_part   = "certificados"
}

resource "aws_api_gateway_method" "certificates_post" {
  rest_api_id   = aws_api_gateway_rest_api.certificates_api.id
  resource_id   = aws_api_gateway_resource.certificates_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "certificates_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.certificates_api.id
  resource_id             = aws_api_gateway_resource.certificates_resource.id
  http_method             = aws_api_gateway_method.certificates_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.certificates.invoke_arn
}

# --- Configuración para Registros ---
resource "aws_api_gateway_resource" "registrations_resource" {
  rest_api_id = aws_api_gateway_rest_api.certificates_api.id
  parent_id   = aws_api_gateway_rest_api.certificates_api.root_resource_id
  path_part   = "registros"
}

resource "aws_api_gateway_method" "registrations_post" {
  rest_api_id   = aws_api_gateway_rest_api.certificates_api.id
  resource_id   = aws_api_gateway_resource.registrations_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "registrations_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.certificates_api.id
  resource_id             = aws_api_gateway_resource.registrations_resource.id
  http_method             = aws_api_gateway_method.registrations_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.registrations.invoke_arn
}

# --- Despliegue del API ---
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.certificates_api.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.certificates_resource.id,
      aws_api_gateway_method.certificates_post.id,
      aws_api_gateway_integration.certificates_lambda.id,
      aws_api_gateway_resource.registrations_resource.id,
      aws_api_gateway_method.registrations_post.id,
      aws_api_gateway_integration.registrations_lambda.id
    ]))
  }
}

# --- Stage separado ---
resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.certificates_api.id
  deployment_id = aws_api_gateway_deployment.deployment.id
}

# --- Permisos para Lambda ---
resource "aws_lambda_permission" "apigw_certificates" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.certificates.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.certificates_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_registrations" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.registrations.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.certificates_api.execution_arn}/*/*"
}

output "api_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}
