# Empaquetado del código Lambda
data "archive_file" "lambda_registrations" {
  type        = "zip"
  source_dir  = "${path.module}/../registrations"
  output_path = "${path.module}/bin/registrations.zip"
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_logs_policy"
  description = "Permisos básicos para CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "registrations" {
  function_name    = "registrations"
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  role             = aws_iam_role.lambda_registrations_exec_role.arn
  filename         = data.archive_file.lambda_registrations.output_path
  source_code_hash = data.archive_file.lambda_registrations.output_base64sha256
  
  environment {
    variables = {
      REGISTRATIONS_TABLE = aws_dynamodb_table.registrations_table.name
    }
  }
}