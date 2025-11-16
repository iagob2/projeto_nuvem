# IAM Role para Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-role"
  }
}

# Policy básica para Lambda executar em VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# CloudWatch Log Group para Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# Policy Document para Lambda (princípio de menor privilégio)
data "aws_iam_policy_document" "lambda_policy" {
  # CloudWatch Logs
  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/lambda/*"
    ]
  }

  # S3 - Acesso ao bucket CSV
  statement {
    sid    = "S3CSVBucket"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.csv_bucket.arn}/*"
    ]
  }

  statement {
    sid    = "S3CSVListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.csv_bucket.arn
    ]
  }

  # Secrets Manager - Acesso APENAS LEITURA ao secret do RDS
  # IMPORTANTE: Apenas permissões de leitura (GetSecretValue, DescribeSecret)
  # As Lambdas NÃO podem modificar ou criar secrets - apenas ler
  statement {
    sid    = "SecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",    # Ler o valor do secret
      "secretsmanager:DescribeSecret"     # Obter metadados do secret
      # NÃO incluir: PutSecretValue, CreateSecret, DeleteSecret, etc.
    ]
    resources = [
      aws_secretsmanager_secret.rds_credentials.arn
    ]
  }
}

# Policy IAM para Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.project_name}-lambda-policy"
  description = "Policy para Lambda acessar S3, Secrets Manager e CloudWatch Logs"
  policy      = data.aws_iam_policy_document.lambda_policy.json

  tags = {
    Name = "${var.project_name}-lambda-policy"
  }
}

# Anexar policy à role Lambda
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# CloudWatch Log Group para Lambda CriarTask
resource "aws_cloudwatch_log_group" "criar_task" {
  name              = "/aws/lambda/CriarTask"
  retention_in_days = 7

  tags = {
    Name = "criar-task-logs"
  }
}

# Função Lambda CriarTask
resource "aws_lambda_function" "criar_task" {
  function_name = "CriarTask"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda.arn
  filename      = "../build/criar_task.zip"  # Empacote seu código antes do apply
  source_code_hash = filebase64sha256("../build/criar_task.zip")

  timeout     = 30
  memory_size = 256

  # VPC config para acessar RDS
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      ENVIRONMENT      = var.environment
      DB_SECRET_ARN    = aws_secretsmanager_secret.rds_credentials.arn
      RDS_ENDPOINT     = aws_db_instance.tasks_db.address
      RDS_PORT         = tostring(aws_db_instance.tasks_db.port)
      DB_NAME          = var.db_name
      CSV_BUCKET_NAME  = aws_s3_bucket.csv_bucket.id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy_attachment.lambda_policy,
    aws_cloudwatch_log_group.criar_task
  ]

  tags = {
    Name = "CriarTask"
  }
}

# Exemplo de função Lambda adicional (comentada)
# resource "aws_lambda_function" "listar_tasks" {
#   function_name = "ListarTasks"
#   handler       = "index.handler"
#   runtime       = "nodejs18.x"
#   role          = aws_iam_role.lambda.arn
#   filename      = "build/listar_tasks.zip"
#   source_code_hash = filebase64sha256("build/listar_tasks.zip")
#
#   timeout     = 30
#   memory_size = 256
#
#   vpc_config {
#     subnet_ids         = aws_subnet.private[*].id
#     security_group_ids = [aws_security_group.lambda.id]
#   }
#
#   environment {
#     variables = {
#       ENVIRONMENT      = var.environment
#       DB_SECRET_ARN    = aws_secretsmanager_secret.rds_credentials.arn
#       RDS_ENDPOINT     = aws_db_instance.tasks_db.address
#       RDS_PORT         = tostring(aws_db_instance.tasks_db.port)
#       DB_NAME          = var.db_name
#     }
#   }
#
#   depends_on = [
#     aws_iam_role_policy_attachment.lambda_vpc,
#     aws_iam_role_policy_attachment.lambda_policy,
#     aws_cloudwatch_log_group.lambda
#   ]
#
#   tags = {
#     Name = "ListarTasks"
#   }
# }
#
# Exemplo de código Node.js para Lambda CriarTask (index.js):
# const AWS = require('aws-sdk');
# const mysql = require('mysql2/promise');
#
# const secretsManager = new AWS.SecretsManager();
# const s3 = new AWS.S3();
#
# exports.handler = async (event) => {
#   try {
#     // Recuperar credenciais do Secrets Manager
#     const secretResponse = await secretsManager.getSecretValue({
#       SecretId: process.env.DB_SECRET_ARN
#     }).promise();
#     
#     const credentials = JSON.parse(secretResponse.SecretString);
#     
#     // Conectar ao RDS
#     const connection = await mysql.createConnection({
#       host: process.env.RDS_ENDPOINT,
#       port: parseInt(process.env.RDS_PORT),
#       user: credentials.username,
#       password: credentials.password,
#       database: credentials.dbname
#     });
#     
#     // Processar evento do API Gateway
#     const body = JSON.parse(event.body || '{}');
#     
#     // Exemplo: Inserir task no banco
#     // const [result] = await connection.execute(
#     //   'INSERT INTO tasks (title, description) VALUES (?, ?)',
#     //   [body.title, body.description]
#     // );
#     
#     // Exemplo: Escrever CSV no S3
#     // const csvContent = 'id,title,description\n1,Task 1,Description 1';
#     // await s3.putObject({
#     //   Bucket: process.env.CSV_BUCKET_NAME,
#     //   Key: `data/tasks_${Date.now()}.csv`,
#     //   Body: csvContent,
#     //   ContentType: 'text/csv'
#     // }).promise();
#     
#     await connection.end();
#     
#     return {
#       statusCode: 200,
#       headers: {
#         'Content-Type': 'application/json',
#         'Access-Control-Allow-Origin': '*'
#       },
#       body: JSON.stringify({ message: 'Task criada com sucesso' })
#     };
#   } catch (error) {
#     console.error('Erro:', error);
#     return {
#       statusCode: 500,
#       headers: {
#         'Content-Type': 'application/json',
#         'Access-Control-Allow-Origin': '*'
#       },
#       body: JSON.stringify({ error: error.message })
#     };
#   }
# };
#
# Nota: Instale as dependências antes de empacotar:
# npm install aws-sdk mysql2
# zip -r criar_task.zip index.js node_modules/

# Lambda Layer (opcional)
# resource "aws_lambda_layer_version" "example" {
#   filename   = "layer.zip"
#   layer_name = "${var.project_name}-layer"
#
#   compatible_runtimes = ["python3.11"]
# }

