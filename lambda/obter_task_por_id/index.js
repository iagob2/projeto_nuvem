const AWS = require('aws-sdk');
const mysql = require('mysql2/promise');

const secretsManager = new AWS.SecretsManager();

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

    // Extrair ID do path parameters
    const taskId = event.pathParameters?.id || event.pathParameters?.taskId;
    
    if (!taskId) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'ID da task é obrigatório' })
      };
    }

    // Buscar task por ID
    const [rows] = await connection.execute(
      'SELECT * FROM tasks WHERE id = ?',
      [taskId]
    );

    await connection.end();

    // Verificar se a task foi encontrada
    if (rows.length === 0) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Task não encontrada' })
      };
    }

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        task: rows[0]
      })
    };

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

