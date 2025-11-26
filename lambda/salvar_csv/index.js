const AWS = require('aws-sdk');
const mysql = require('mysql2/promise');

const secretsManager = new AWS.SecretsManager();
const s3 = new AWS.S3();

exports.handler = async (event) => {
  try {
    console.log('Evento recebido:', JSON.stringify(event, null, 2));

    // Verificar se o bucket CSV está configurado
    if (!process.env.CSV_BUCKET_NAME) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'CSV_BUCKET_NAME não configurado' })
      };
    }

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

    // Buscar todas as tasks
    const [rows] = await connection.execute(
      'SELECT * FROM tasks ORDER BY created_at DESC'
    );

    await connection.end();

    // Verificar se há tasks para exportar
    if (rows.length === 0) {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        },
        body: JSON.stringify({ error: 'Nenhuma task encontrada para exportar' })
      };
    }

    // Gerar conteúdo CSV
    const headers = ['id', 'title', 'description', 'status', 'created_at', 'updated_at'];
    const csvRows = [
      headers.join(',')
    ];

    // Adicionar dados
    rows.forEach(row => {
      const csvRow = headers.map(header => {
        const value = row[header] || '';
        // Escapar vírgulas e quebras de linha nos valores
        if (typeof value === 'string' && (value.includes(',') || value.includes('\n') || value.includes('"'))) {
          return `"${value.replace(/"/g, '""')}"`;
        }
        return value;
      });
      csvRows.push(csvRow.join(','));
    });

    const csvContent = csvRows.join('\n');

    // Gerar nome do arquivo com timestamp
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
    const fileName = `data/tasks_${timestamp}_${Date.now()}.csv`;

    // Salvar CSV no S3
    await s3.putObject({
      Bucket: process.env.CSV_BUCKET_NAME,
      Key: fileName,
      Body: csvContent,
      ContentType: 'text/csv',
      ServerSideEncryption: 'AES256'
    }).promise();

    console.log(`CSV salvo no S3: ${fileName}`);

    // Construir URL do objeto (opcional, se necessário)
    const csvUrl = `s3://${process.env.CSV_BUCKET_NAME}/${fileName}`;

    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        message: 'CSV salvo com sucesso',
        fileName: fileName,
        bucket: process.env.CSV_BUCKET_NAME,
        recordsCount: rows.length,
        csvUrl: csvUrl
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

