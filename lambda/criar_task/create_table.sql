-- Script SQL para criar a tabela tasks no RDS MySQL
-- Execute este script após criar o RDS

CREATE DATABASE IF NOT EXISTS tasksdb;

USE tasksdb;

CREATE TABLE IF NOT EXISTS tasks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_status (status),
  INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inserir alguns dados de exemplo (opcional)
INSERT INTO tasks (title, description, status) VALUES
  ('Corrigir erro de autenticação', 'O login via Google está retornando erro 403 intermitente.', 'pending'),
  ('Refatorar módulo de pagamentos', 'Migrar a integração antiga para a nova API do Stripe.', 'in_progress'),
  ('Atualizar documentação da API', 'Adicionar os novos endpoints de usuários no Swagger.', 'completed'),
  ('Configurar pipeline de CI/CD', 'Automatizar os testes unitários no GitHub Actions.', 'pending'),
  ('Otimizar query de relatórios', 'A busca por data está levando mais de 5 segundos.', 'pending'),
  ('Revisão de código do Pull Request #42', 'Verificar as alterações na lógica de carrinho de compras.', 'in_progress'),
  ('Backup do banco de dados', 'Verificar se o dump diário foi realizado com sucesso.', 'completed'),
  ('Reunião de Daily', 'Sincronização diária com a equipe de frontend.', 'completed');
