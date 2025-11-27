# Grafana Setup

### Indice

1. [Pré requisitos](#pré-requisitos)
2. [1. Iniciar o Servidor Grafana](#1.-iniciar-o-servidor-grafana)
3. [2. Acessar o Grafana](#2.-acessar-o-grafana)
4. [3. Configurar o Grafana](#3.-configurar-o-grafana)
5. [4. Configurar os Dashboards](#4.-configurar-os-dashboards)

### Pré requisitos

- Docker

## 1. Iniciar o Servidor Grafana

```bash
docker compose up -d
```

## 2. Acessar o Grafana

Acesse o Grafana no navegador com o seguinte link: http://localhost:3000

## 3. Configurar o Grafana

1. Acesse o Grafana no navegador com o seguinte link: http://localhost:3000
2. Faça login com o usuário admin/admin
3. Clique em "Data Sources"
4. Clique em "Add data source"
5. Selecione "CloudWatch"
6. Configure as credenciais da sua conta AWS
7. Clique em "Save and test"
8. Se estiver OK, voce pode prosseguir para o passo 4.

## 4. Configurar os Dashboards

1. Acesse o Grafana no navegador com o seguinte link: http://localhost:3000
2. Clique em "Dashboards"
3. Clique em "New dashboard"
4. Clique em "Import dashboard"
5. Clique em "Upload JSON"
6. Selecione os arquivos em [dashboards/](dashboards/)
7. Clique em "Import"
