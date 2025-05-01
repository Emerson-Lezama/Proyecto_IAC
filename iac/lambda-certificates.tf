data "archive_file" "lambda_certificates" {
  type        = "zip"
  source_dir  = "${path.module}/../certificates"
  output_path = "${path.module}/bin/certificates.zip"
}

resource "aws_iam_role" "lambda_certificates_exec_role" {
  name = "certificates_exec_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Política mejorada para logs
resource "aws_iam_policy" "certificates_logs_policy" {
  name        = "certificates_logs_policy"
  description = "Permisos para CloudWatch Logs"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect   = "Allow",
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

# Adjuntar políticas al rol
resource "aws_iam_role_policy_attachment" "certificates_logs" {
  role       = aws_iam_role.lambda_certificates_exec_role.name
  policy_arn = aws_iam_policy.certificates_logs_policy.arn
}

resource "aws_lambda_function" "certificates" {
  function_name    = "certificates"
  handler          = "index.handler"
  runtime          = "nodejs16.x" 
  role             = aws_iam_role.lambda_certificates_exec_role.arn
  filename         = data.archive_file.lambda_certificates.output_path
  source_code_hash = data.archive_file.lambda_certificates.output_base64sha256
  
  environment {
    variables = {
      CERTIFICATES_TABLE = aws_dynamodb_table.certificates_table.name 
      LOG_LEVEL          = "INFO"
    }
  }
}