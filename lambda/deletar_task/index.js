const AWS = require('aws-sdk');
const mysql = require('mysql2/promise');

const secretsManager = new AWS.SecretsManager();

exports.handler = async (event) => {
  let connection;
  try {
    console.log('Evento recebido:', JSON.stringify(event, null, 2));

    // Recuperar credenciais do Secrets Manager
    const secretResponse = await secretsManager.getSecretValue({
      SecretId: process.env.DB_SECRET_ARN
    }).promise();
    
    const credentials = JSON.parse(secretResponse.SecretString);
    console.log('Credenciais recuperadas do Secrets Manager');

    // Conectar ao RDS
    connection = await mysql.createConnection({
      host: process.env.RDS_ENDPOINT,
      port: parseInt(process.env.RDS_PORT),
      user: credentials.username,
      password: credentials.password,
      database: process.env.DB_NAME || credentials.dbname
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

    // Verificar se a task existe antes de deletar
    const [checkRows] = await connection.execute(
      'SELECT id FROM tasks WHERE id = ?',
      [taskId]
    );

    if (checkRows.length === 0) {
      await connection.end();
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Task não encontrada' })
      };
    }

    // Deletar task
    const [result] = await connection.execute(
      'DELETE FROM tasks WHERE id = ?',
      [taskId]
    );

    await connection.end();

    if (result.affectedRows === 0) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Falha ao deletar task' })
      };
    }

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'Task deletada com sucesso',
        id: parseInt(taskId)
      })
    };

  } catch (error) {
    console.error('Erro:', error);
    if (connection) {
      await connection.end();
    }
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

