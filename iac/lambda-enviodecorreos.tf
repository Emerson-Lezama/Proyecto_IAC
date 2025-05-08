resource "aws_iam_role" "lambda_send_email_exec_role" {
  name = "lambda_send_email_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "archive_file" "lambda_send_email" {
  type        = "zip"
  source_dir  = "${path.module}/../envio"
  output_path = "${path.module}/bin/envio.zip"
}

resource "aws_lambda_function" "send_email" {
  function_name    = "send_email"
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  role             = aws_iam_role.lambda_send_email_exec_role.arn
  filename         = data.archive_file.lambda_send_email.output_path
  source_code_hash = data.archive_file.lambda_send_email.output_base64sha256

  environment {
    variables = {
      SES_EMAIL_IDENTITY = "juanvaleriano97@gmail.com"  
      LOG_LEVEL          = "INFO"
      SQS_QUEUE_URL      = aws_sqs_queue.email_queue.url
    }
  }
}

resource "aws_iam_policy" "send_email_logs_policy" {
  name        = "send_email_logs_policy"
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

resource "aws_iam_policy" "send_email_ses_policy" {
  name = "send_email_ses_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["ses:SendEmail", "ses:SendRawEmail"],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "send_email_logs_attach" {
  role       = aws_iam_role.lambda_send_email_exec_role.name
  policy_arn = aws_iam_policy.send_email_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "send_email_ses_attach" {
  role       = aws_iam_role.lambda_send_email_exec_role.name
  policy_arn = aws_iam_policy.send_email_ses_policy.arn
}