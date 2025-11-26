import axios from "axios";

// Ler URL do config.js ou usar variável de ambiente
const getApiUrl = () => {
  // Prioridade 1: config.js (runtime) - permite mudar URL sem rebuild
  if (typeof window !== 'undefined' && (window as any).APP_CONFIG?.API_URL) {
    const configUrl = (window as any).APP_CONFIG.API_URL;
    // Remover trailing slash se houver
    return configUrl.replace(/\/$/, '');
  }
  // Prioridade 2: Variável de ambiente (build time)
  const envUrl = import.meta.env.VITE_API_URL;
  if (envUrl) {
    return envUrl.replace(/\/$/, '');
  }
  // Fallback para desenvolvimento local
  return "http://localhost:8000";
};

export const api = axios.create({
  baseURL: getApiUrl(),
  timeout: 30000, // 30 segundos (aumentado para API Gateway)
  headers: {
    "Content-Type": "application/json",
  },
});

// Interceptor para log de requisições (apenas em desenvolvimento)
if (import.meta.env.DEV) {
  api.interceptors.request.use(
    (config) => {
      console.log(`🚀 ${config.method?.toUpperCase()} ${config.url}`, config.data || config.params || '');
      return config;
    },
    (error) => {
      console.error("Erro na requisição:", error);
      return Promise.reject(error);
    }
  );
}

// Interceptor para tratamento de erros
api.interceptors.response.use(
  (response) => {
    // Log de sucesso apenas em desenvolvimento
    if (import.meta.env.DEV) {
      console.log(`✅ ${response.config.method?.toUpperCase()} ${response.config.url}`, response.status);
    }
    return response;
  },
  (error) => {
    // Tratamento detalhado de erros
    if (error.response) {
      // Servidor respondeu com status de erro
      console.error(`❌ Erro ${error.response.status}:`, error.response.data);
    } else if (error.request) {
      // Requisição foi feita mas não houve resposta
      console.error("❌ Sem resposta do servidor:", error.message);
    } else {
      // Erro ao configurar a requisição
      console.error("❌ Erro na configuração:", error.message);
    }
    return Promise.reject(error);
  }
);
