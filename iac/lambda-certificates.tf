data "archive_file" "lambda_certificates" {
  type        = "zip"
  source_dir  = "${path.module}/../certificates"
  output_path = "${path.module}/bin/certificates.zip"
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