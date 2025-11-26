# API Gateway REST API
resource "aws_api_gateway_rest_api" "tasks_api" {
  name        = "${var.project_name}-tasks-api"
  description = "API Gateway para gerenciamento de tasks"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name = "${var.project_name}-tasks-api"
  }
}

# ========================================
# Recurso: /tasks
# ========================================
resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  parent_id   = aws_api_gateway_rest_api.tasks_api.root_resource_id
  path_part   = "tasks"
}

# Recurso: /tasks/{id}
resource "aws_api_gateway_resource" "tasks_id" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  parent_id   = aws_api_gateway_resource.tasks.id
  path_part   = "{id}"
}

# Recurso: /save
resource "aws_api_gateway_resource" "save" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  parent_id   = aws_api_gateway_rest_api.tasks_api.root_resource_id
  path_part   = "save"
}

# ========================================
# Métodos HTTP
# ========================================

# POST /tasks -> CriarTask
resource "aws_api_gateway_method" "tasks_post" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "POST"
  authorization = "NONE"
}

# GET /tasks -> ListarTasks
resource "aws_api_gateway_method" "tasks_get" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "GET"
  authorization = "NONE"
}

# GET /tasks/{id} -> ObterTaskPorId
resource "aws_api_gateway_method" "tasks_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.tasks_id.id
  http_method   = "GET"
  authorization = "NONE"
}

# PUT /tasks/{id} -> AtualizarTask
resource "aws_api_gateway_method" "tasks_id_put" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.tasks_id.id
  http_method   = "PUT"
  authorization = "NONE"
}

# DELETE /tasks/{id} -> DeletarTask
resource "aws_api_gateway_method" "tasks_id_delete" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.tasks_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

# GET /save -> SalvarCSV
resource "aws_api_gateway_method" "save_get" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.save.id
  http_method   = "GET"
  authorization = "NONE"
}

# OPTIONS para CORS em /tasks
resource "aws_api_gateway_method" "tasks_options" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONS para CORS em /tasks/{id}
resource "aws_api_gateway_method" "tasks_id_options" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.tasks_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# OPTIONS para CORS em /save
resource "aws_api_gateway_method" "save_options" {
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  resource_id   = aws_api_gateway_resource.save.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ========================================
# Integrações Lambda
# ========================================

# Integração POST /tasks -> CriarTask
resource "aws_api_gateway_integration" "tasks_post" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.tasks_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.criar_task.invoke_arn
}

# Integração GET /tasks -> ListarTasks
resource "aws_api_gateway_integration" "tasks_get" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.tasks_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.listar_tasks.invoke_arn
}

# Integração GET /tasks/{id} -> ObterTaskPorId
resource "aws_api_gateway_integration" "tasks_id_get" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks_id.id
  http_method = aws_api_gateway_method.tasks_id_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.obter_task_por_id.invoke_arn
}

# Integração PUT /tasks/{id} -> AtualizarTask
resource "aws_api_gateway_integration" "tasks_id_put" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks_id.id
  http_method = aws_api_gateway_method.tasks_id_put.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.atualizar_task.invoke_arn
}

# Integração DELETE /tasks/{id} -> DeletarTask
resource "aws_api_gateway_integration" "tasks_id_delete" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks_id.id
  http_method = aws_api_gateway_method.tasks_id_delete.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.deletar_task.invoke_arn
}

# Integração GET /save -> SalvarCSV
resource "aws_api_gateway_integration" "save_get" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.save.id
  http_method = aws_api_gateway_method.save_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.salvar_csv.invoke_arn
}

# Integrações OPTIONS para CORS (MOCK)
resource "aws_api_gateway_integration" "tasks_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.tasks_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "tasks_id_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks_id.id
  http_method = aws_api_gateway_method.tasks_id_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "save_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.save.id
  http_method = aws_api_gateway_method.save_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# ========================================
# Method Responses para CORS
# ========================================

resource "aws_api_gateway_method_response" "tasks_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.tasks_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "tasks_id_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks_id.id
  http_method = aws_api_gateway_method.tasks_id_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "save_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.save.id
  http_method = aws_api_gateway_method.save_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# ========================================
# Integration Responses para CORS
# ========================================

resource "aws_api_gateway_integration_response" "tasks_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.tasks_options.http_method
  status_code = aws_api_gateway_method_response.tasks_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.tasks_options]
}

resource "aws_api_gateway_integration_response" "tasks_id_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.tasks_id.id
  http_method = aws_api_gateway_method.tasks_id_options.http_method
  status_code = aws_api_gateway_method_response.tasks_id_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.tasks_id_options]
}

resource "aws_api_gateway_integration_response" "save_options" {
  rest_api_id = aws_api_gateway_rest_api.tasks_api.id
  resource_id = aws_api_gateway_resource.save.id
  http_method = aws_api_gateway_method.save_options.http_method
  status_code = aws_api_gateway_method_response.save_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_integration.save_options]
}

# ========================================
# Permissões Lambda para API Gateway
# ========================================

resource "aws_lambda_permission" "apigw_invoke_criar_task" {
  statement_id  = "AllowAPIGatewayInvokeCriarTask"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.criar_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tasks_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_listar_tasks" {
  statement_id  = "AllowAPIGatewayInvokeListarTasks"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.listar_tasks.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tasks_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_obter_task_por_id" {
  statement_id  = "AllowAPIGatewayInvokeObterTaskPorId"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.obter_task_por_id.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tasks_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_salvar_csv" {
  statement_id  = "AllowAPIGatewayInvokeSalvarCSV"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.salvar_csv.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tasks_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_atualizar_task" {
  statement_id  = "AllowAPIGatewayInvokeAtualizarTask"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.atualizar_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tasks_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_deletar_task" {
  statement_id  = "AllowAPIGatewayInvokeDeletarTask"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.deletar_task.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.tasks_api.execution_arn}/*/*"
}

# ========================================
# Deployment e Stage
# ========================================

resource "aws_api_gateway_deployment" "tasks_api" {
  depends_on = [
    aws_api_gateway_integration.tasks_post,
    aws_api_gateway_integration.tasks_get,
    aws_api_gateway_integration.tasks_id_get,
    aws_api_gateway_integration.tasks_id_put,
    aws_api_gateway_integration.tasks_id_delete,
    aws_api_gateway_integration.save_get,
    aws_api_gateway_integration.tasks_options,
    aws_api_gateway_integration.tasks_id_options,
    aws_api_gateway_integration.save_options,
  ]

  rest_api_id = aws_api_gateway_rest_api.tasks_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.tasks.id,
      aws_api_gateway_resource.tasks_id.id,
      aws_api_gateway_resource.save.id,
      aws_api_gateway_method.tasks_post.id,
      aws_api_gateway_method.tasks_get.id,
      aws_api_gateway_method.tasks_id_get.id,
      aws_api_gateway_method.tasks_id_put.id,
      aws_api_gateway_method.tasks_id_delete.id,
      aws_api_gateway_method.save_get.id,
      aws_api_gateway_integration.tasks_post.id,
      aws_api_gateway_integration.tasks_get.id,
      aws_api_gateway_integration.tasks_id_get.id,
      aws_api_gateway_integration.tasks_id_put.id,
      aws_api_gateway_integration.tasks_id_delete.id,
      aws_api_gateway_integration.save_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "tasks_api" {
  deployment_id = aws_api_gateway_deployment.tasks_api.id
  rest_api_id   = aws_api_gateway_rest_api.tasks_api.id
  stage_name    = var.environment

  tags = {
    Name = "${var.project_name}-tasks-api-${var.environment}"
  }
}

# CloudWatch Log Group para API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-tasks-api"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-api-gateway-logs"
  }
}

# Output com a URL da API
output "api_gateway_url" {
  description = "URL base do API Gateway"
  value       = "${aws_api_gateway_stage.tasks_api.invoke_url}"
}

output "api_gateway_endpoints" {
  description = "Endpoints disponíveis na API"
  value = {
    create_task    = "${aws_api_gateway_stage.tasks_api.invoke_url}/tasks"
    list_tasks     = "${aws_api_gateway_stage.tasks_api.invoke_url}/tasks"
    get_task_by_id = "${aws_api_gateway_stage.tasks_api.invoke_url}/tasks/{id}"
    update_task    = "${aws_api_gateway_stage.tasks_api.invoke_url}/tasks/{id}"
    delete_task    = "${aws_api_gateway_stage.tasks_api.invoke_url}/tasks/{id}"
    save_csv       = "${aws_api_gateway_stage.tasks_api.invoke_url}/save"
  }
}
