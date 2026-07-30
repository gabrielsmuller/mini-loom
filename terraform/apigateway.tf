# API Gateway HTTP API — the public front door to the Lambda.
#
# CORS is handled by FastAPI (CORSMiddleware) inside the app, so we do NOT set
# CORS here — configuring it in both places would send duplicate headers and
# browsers would reject them.

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project}-api"
  protocol_type = "HTTP"
}

# Proxy every request straight to the Lambda; FastAPI does its own routing.
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

# "ANY /{proxy+}" catches every path except the root; the second route adds "/".
resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "root" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# The $default stage, with THROTTLING — our abuse/cost guardrail. Requests over
# the rate get a cheap 429 instead of invoking the Lambda.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 20 # steady-state requests/second
    throttling_burst_limit = 40 # short burst allowance
  }
}

# Allow API Gateway to invoke the Lambda.
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

output "api_url" {
  description = "Base URL of the deployed backend API (set as VITE_API_URL)."
  value       = aws_apigatewayv2_stage.default.invoke_url
}
