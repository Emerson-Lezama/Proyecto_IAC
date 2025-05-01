# Tabla para Certificados
resource "aws_dynamodb_table" "certificates_table" {
  name         = "Certificates"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "certificateId"
  
  attribute {
    name = "certificateId"
    type = "S"  # String
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "expirationDate"
    type = "N"  # Number (timestamp)
  }

  # Índice global secundario para búsquedas por usuario
  global_secondary_index {
    name            = "UserIdIndex"
    hash_key        = "userId"
    range_key       = "expirationDate"
    projection_type = "ALL"  # Incluye todos los atributos
    read_capacity   = 1
    write_capacity  = 1
  }

  # Índice global secundario para búsquedas por estado
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "expirationDate"
    projection_type = "INCLUDE"
    non_key_attributes = ["certificateId", "userId"]
  }

  # Encriptación en reposo
  server_side_encryption {
    enabled = true  # Usa el KMS por defecto de AWS
  }

  # Configuración de TTL (opcional)
  ttl {
    attribute_name = "expirationDate"
    enabled        = true
  }

  tags = {
    Environment = "production"
    Project     = "certificates-system"
  }
}

# Tabla para Registros de Usuarios
resource "aws_dynamodb_table" "registrations_table" {
  name         = "Registrations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "email"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "accountType"
    type = "S"
  }

  # Índice global secundario para búsquedas por email
  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  # Índice para búsquedas por tipo de cuenta
  global_secondary_index {
    name            = "AccountTypeIndex"
    hash_key        = "accountType"
    range_key       = "email"
    projection_type = "KEYS_ONLY"
  }

  # Encriptación con clave KMS personalizada (opcional)
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn  # Necesitas definir este recurso KMS
  }

  # Configuración de backup automático
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = "production"
    Project     = "registrations-system"
  }
}

# Política de IAM para acceso a Certificados
resource "aws_iam_policy" "certificates_dynamodb_policy" {
  name        = "CertificatesDynamoDBPolicy"
  description = "Permisos para la tabla de Certificados"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "FullAccessToCertificatesTable",
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ],
        Resource = [
          aws_dynamodb_table.certificates_table.arn,
          "${aws_dynamodb_table.certificates_table.arn}/index/*"
        ]
      },
      {
        Sid    = "DescribeTable",
        Effect = "Allow",
        Action = "dynamodb:DescribeTable",
        Resource = aws_dynamodb_table.certificates_table.arn
      }
    ]
  })
}

# Política de IAM para acceso a Registros
resource "aws_iam_policy" "registrations_dynamodb_policy" {
  name        = "RegistrationsDynamoDBPolicy"
  description = "Permisos para la tabla de Registros"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "FullAccessToRegistrationsTable",
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        Resource = [
          aws_dynamodb_table.registrations_table.arn,
          "${aws_dynamodb_table.registrations_table.arn}/index/*"
        ]
      },
      {
        Sid    = "ConditionalAccess",
        Effect = "Allow",
        Action = "dynamodb:Query",
        Resource = "${aws_dynamodb_table.registrations_table.arn}/index/EmailIndex",
        Condition = {
          "ForAllValues:StringEquals" = {
            "dynamodb:LeadingKeys" = ["${data.aws_caller_identity.current.user_id}"]
          }
        }
      }
    ]
  })
}

# Clave KMS para encriptación (opcional)
resource "aws_kms_key" "dynamodb_key" {
  description             = "KMS key for DynamoDB encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_policy.json
}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# Asignación de políticas a los roles Lambda
resource "aws_iam_role_policy_attachment" "certificates_dynamodb" {
  role       = aws_iam_role.lambda_certificates_exec_role.name
  policy_arn = aws_iam_policy.certificates_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "registrations_dynamodb" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = aws_iam_policy.registrations_dynamodb_policy.arn
}

# Outputs útiles
output "certificates_table_arn" {
  value = aws_dynamodb_table.certificates_table.arn
}

output "registrations_table_name" {
  value = aws_dynamodb_table.registrations_table.name
}

output "dynamodb_kms_key_arn" {
  value = aws_kms_key.dynamodb_key.arn
}