output "api_url" {
  value       = "${aws_apigatewayv2_api.http_api.api_endpoint}/messages"
  description = "The target API URL for your PC Frontend application"
}