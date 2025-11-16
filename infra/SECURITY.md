# Segurança de Credenciais - Boas Práticas

## ⚠️ IMPORTANTE: NUNCA coloque senhas ou credenciais hardcoded no código

## Gerenciamento de Credenciais

### 1. Variáveis Sensíveis no Terraform

As variáveis `db_username` e `db_password` estão marcadas como `sensitive = true` e **NUNCA** devem ter valores hardcoded.

### 2. Como Fornecer Credenciais

#### Opção 1: Arquivo terraform.tfvars (Recomendado para desenvolvimento)

1. Copie o arquivo de exemplo:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Preencha com seus valores reais no arquivo `terraform.tfvars`:
   ```hcl
   db_username = "admin"
   db_password = "sua_senha_segura_aqui"
   ```

3. **IMPORTANTE**: O arquivo `terraform.tfvars` está no `.gitignore` e **NÃO** deve ser versionado no Git.

#### Opção 2: Variáveis de Ambiente (Recomendado para CI/CD)

```bash
export TF_VAR_db_username="admin"
export TF_VAR_db_password="sua_senha_segura"
terraform apply
```

#### Opção 3: AWS Secrets Manager (Recomendado para produção)

Para produção, considere usar AWS Secrets Manager ou AWS Systems Manager Parameter Store para armazenar as credenciais antes de executar o Terraform.

### 3. AWS Secrets Manager

Após a criação do RDS, as credenciais são armazenadas no **AWS Secrets Manager** de forma segura.

#### Como as aplicações devem acessar:

**Lambdas:**
```javascript
const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();

const secretResponse = await secretsManager.getSecretValue({
  SecretId: process.env.DB_SECRET_ARN
}).promise();

const credentials = JSON.parse(secretResponse.SecretString);
// Usar credentials.username e credentials.password
```

**ECS Tasks:**
- Use a variável de ambiente `DB_SECRET_ARN` para referenciar o secret
- O ECS Task Role tem permissão apenas de **LEITURA** no secret

### 4. Permissões IAM

#### Lambda e ECS
- ✅ **Permitido**: `secretsmanager:GetSecretValue` (ler o valor)
- ✅ **Permitido**: `secretsmanager:DescribeSecret` (obter metadados)
- ❌ **NÃO permitido**: `secretsmanager:PutSecretValue`, `CreateSecret`, `DeleteSecret`, etc.

**Princípio de Menor Privilégio**: As aplicações têm apenas permissões de **LEITURA** no Secrets Manager.

### 5. Checklist de Segurança

- [ ] Variáveis sensíveis marcadas como `sensitive = true`
- [ ] Nenhuma senha hardcoded no código
- [ ] `terraform.tfvars` no `.gitignore`
- [ ] Credenciais armazenadas no AWS Secrets Manager
- [ ] Permissões IAM restritas apenas a leitura
- [ ] Aplicações usam Secrets Manager em runtime (não variáveis de ambiente com senhas)

### 6. Rotação de Senhas

Para rotacionar a senha do RDS:

1. Atualize o secret no AWS Secrets Manager
2. Atualize a senha do RDS manualmente ou via Terraform
3. As aplicações continuarão funcionando pois leem do Secrets Manager

### 7. Monitoramento

- Monitore acessos ao Secrets Manager via CloudTrail
- Configure alertas para tentativas de acesso não autorizadas
- Revise periodicamente as permissões IAM

## Referências

- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [Terraform Sensitive Variables](https://www.terraform.io/docs/language/values/variables.html#suppressing-values-in-cli-output)

