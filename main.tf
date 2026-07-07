# 1. Secured DynamoDB Storage (Data at Rest)
resource "aws_dynamodb_table" "messages" {
  name         = "secure-widget-messages"
  billing_mode = "PAY_PER_REQUEST" # No fixed costs
  hash_key     = "partner_id"
  range_key    = "timestamp"

  attribute {
    name = "partner_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # GRC Requirement: Enforce Server-Side Encryption using AWS Managed KMS Key
  server_side_encryption {
    enabled = true
  }
}

# 2. Package Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function.zip"
}

# 3. Least-Privilege IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "widget-lambda-secure-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Explicitly scope policy to allow ONLY write/query actions on our specific table
resource "aws_iam_role_policy" "dynamodb_read_write" {
  name = "widget-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.messages.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 4. Lambda Function Definition
resource "aws_lambda_function" "widget_backend" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "secure-widget-backend-api"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.messages.name
    }
  }
}

# 5. Amazon API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "http_api" {
  name          = "secure-widget-gateway"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_integration" "lambda_int" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.widget_backend.invoke_arn
  
  # Forces API Gateway to talk to Lambda using modern payload structures
  payload_format_version = "2.0" 
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /messages"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_int.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Clear and explicit permission for API Gateway to trigger your Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.widget_backend.function_name
  principal     = "apigateway.amazonaws.com"
  
  # Scopes invocation right across any execution route coming from this API ID
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}