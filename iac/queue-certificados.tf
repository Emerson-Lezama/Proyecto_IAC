resource "aws_sqs_queue" "email_queue" {
  name                     = "email-queue-certificados"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 345600
}

output "email_queue_url" {
  value = aws_sqs_queue.email_queue.url
}

output "email_queue_arn" {
  value = aws_sqs_queue.email_queue.arn
}
