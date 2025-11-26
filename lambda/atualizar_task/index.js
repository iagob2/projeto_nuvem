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

    // Processar body do evento
    const body = JSON.parse(event.body || '{}');

    // Verificar se a task existe
    const [checkRows] = await connection.execute(
      'SELECT * FROM tasks WHERE id = ?',
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

    // Preparar campos para atualização (apenas os que foram enviados)
    const updateFields = [];
    const updateValues = [];

    if (body.title !== undefined) {
      updateFields.push('title = ?');
      updateValues.push(body.title);
    }

    if (body.description !== undefined) {
      updateFields.push('description = ?');
      updateValues.push(body.description);
    }

    if (body.status !== undefined) {
      updateFields.push('status = ?');
      updateValues.push(body.status);
    }

    // Sempre atualizar updated_at
    updateFields.push('updated_at = NOW()');

    if (updateFields.length === 1) {
      // Apenas updated_at foi adicionado, nenhum campo foi enviado
      await connection.end();
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Nenhum campo para atualizar foi fornecido' })
      };
    }

    // Adicionar ID no final dos valores
    updateValues.push(taskId);

    // Executar atualização
    const updateQuery = `UPDATE tasks SET ${updateFields.join(', ')} WHERE id = ?`;
    console.log('Executando query:', updateQuery);
    console.log('Valores:', updateValues);

    const [result] = await connection.execute(updateQuery, updateValues);

    // Buscar task atualizada
    const [updatedRows] = await connection.execute(
      'SELECT * FROM tasks WHERE id = ?',
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
        body: JSON.stringify({ error: 'Falha ao atualizar task' })
      };
    }

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'Task atualizada com sucesso',
        task: updatedRows[0]
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

