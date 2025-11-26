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
    // Usar 'tasksdb' como database (criado pelo init-database.ps1)
    const database = credentials.dbname || 'tasksdb';
    console.log('Conectando ao RDS...', {
      host: process.env.RDS_ENDPOINT,
      port: process.env.RDS_PORT,
      database: database,
      user: credentials.username
    });
    
    const connection = await mysql.createConnection({
      host: process.env.RDS_ENDPOINT,
      port: parseInt(process.env.RDS_PORT),
      user: credentials.username,
      password: credentials.password,
      database: database
    });
    console.log('✅ Conectado ao RDS MySQL no database:', database);

    // Extrair parâmetros de query (filtros opcionais)
    const queryParams = event.queryStringParameters || {};
    const status = queryParams.status;
    const limit = parseInt(queryParams.limit) || 100;
    const offset = parseInt(queryParams.offset) || 0;

    let query = 'SELECT * FROM tasks WHERE 1=1';
    const queryParams_array = [];

    // Filtro por status se fornecido
    if (status) {
      query += ' AND status = ?';
      queryParams_array.push(status);
    }

    // LIMIT e OFFSET devem ser números diretos na query, não placeholders
    query += ` ORDER BY created_at DESC LIMIT ${parseInt(limit)} OFFSET ${parseInt(offset)}`;

    // Executar query
    console.log('Executando query:', query);
    console.log('Parâmetros:', queryParams_array);
    const [rows] = await connection.execute(query, queryParams_array);
    console.log('✅ Query executada. Linhas encontradas:', rows.length);

    // Contar total de tasks (para paginação)
    let countQuery = 'SELECT COUNT(*) as total FROM tasks WHERE 1=1';
    const countParams = [];
    if (status) {
      countQuery += ' AND status = ?';
      countParams.push(status);
    }
    console.log('Executando count query:', countQuery);
    const [countResult] = await connection.execute(countQuery, countParams);
    const total = countResult[0].total;
    console.log('✅ Total de tasks:', total);

    await connection.end();

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        tasks: rows,
        count: rows.length,
        total: total,
        limit: limit,
        offset: offset
      })
    };

  } catch (error) {
    console.error('❌ ERRO na Lambda ListarTasks:', error);
    console.error('Stack:', error.stack);
    console.error('Mensagem:', error.message);
    console.error('Código:', error.code);
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: error.message,
        code: error.code,
        details: process.env.NODE_ENV === 'development' ? error.stack : 'Verifique os logs do CloudWatch para mais detalhes'
      })
    };
  }
};

