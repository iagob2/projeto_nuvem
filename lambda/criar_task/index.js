const AWS = require('aws-sdk');
const mysql = require('mysql2/promise');

const secretsManager = new AWS.SecretsManager();
const s3 = new AWS.S3();

exports.handler = async (event) => {
  try {
    console.log('Evento recebido:', JSON.stringify(event, null, 2));

    // Recuperar credenciais do Secrets Manager
    const secretResponse = await secretsManager.getSecretValue({
      SecretId: process.env.DB_SECRET_ARN
    }).promise();
    
    const credentials = JSON.parse(secretResponse.SecretString);
    console.log('Credenciais recuperadas do Secrets Manager');

    // Conectar ao RDS
    const connection = await mysql.createConnection({
      host: process.env.RDS_ENDPOINT,
      port: parseInt(process.env.RDS_PORT),
      user: credentials.username,
      password: credentials.password,
      database: credentials.dbname
    });
    console.log('Conectado ao RDS MySQL');

    // Processar evento do API Gateway
    const body = JSON.parse(event.body || '{}');
    const httpMethod = event.httpMethod || event.requestContext?.http?.method || 'POST';

    let response;

    switch (httpMethod) {
      case 'POST':
        // Criar nova task
        if (!body.title) {
          return {
            statusCode: 400,
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Campo "title" é obrigatório' })
          };
        }

        const [result] = await connection.execute(
          'INSERT INTO tasks (title, description, status, created_at) VALUES (?, ?, ?, NOW())',
          [body.title, body.description || null, body.status || 'pending']
        );

        response = {
          statusCode: 201,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify({
            message: 'Task criada com sucesso',
            id: result.insertId,
            title: body.title
          })
        };
        break;

      case 'GET':
        // Listar tasks
        const [rows] = await connection.execute(
          'SELECT * FROM tasks ORDER BY created_at DESC LIMIT 100'
        );

        response = {
          statusCode: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify({
            tasks: rows,
            count: rows.length
          })
        };
        break;

      default:
        response = {
          statusCode: 405,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          },
          body: JSON.stringify({ error: 'Método não permitido' })
        };
    }

    await connection.end();

    // Exemplo: Escrever CSV no S3 (opcional)
    if (process.env.CSV_BUCKET_NAME && httpMethod === 'GET') {
      try {
        const csvContent = 'id,title,description,status,created_at\n' +
          rows.map(row => 
            `${row.id},${row.title || ''},${row.description || ''},${row.status || ''},${row.created_at || ''}`
          ).join('\n');

        await s3.putObject({
          Bucket: process.env.CSV_BUCKET_NAME,
          Key: `data/tasks_${Date.now()}.csv`,
          Body: csvContent,
          ContentType: 'text/csv'
        }).promise();

        console.log('CSV salvo no S3');
      } catch (s3Error) {
        console.error('Erro ao salvar CSV no S3:', s3Error);
        // Não falha a requisição se o S3 falhar
      }
    }

    return response;

  } catch (error) {
    console.error('Erro:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: error.message,
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
      })
    };
  }
};

