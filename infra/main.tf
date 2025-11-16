# ============================================================================
# main.tf - Arquivo Principal de Orquestração
# ============================================================================
# Este arquivo serve como ponto de entrada principal para orquestração de recursos.
# Aqui podem ser chamados módulos reutilizáveis ou recursos principais que
# coordenam outros recursos definidos em arquivos separados.
#
# Estrutura do projeto:
# - Cada tipo de recurso AWS está em seu próprio arquivo (networking.tf, rds.tf, etc.)
# - Este arquivo pode ser usado para chamar módulos ou definir dependências globais
# ============================================================================

# Exemplo de uso de módulos (descomente se necessário):
# module "networking" {
#   source = "./modules/networking"
#   vpc_cidr = var.vpc_cidr
#   availability_zones = var.availability_zones
# }

# NOTA: O provider AWS está definido em providers.tf
# As credenciais devem ser configuradas via variáveis de ambiente ou AWS CLI
# NÃO coloque credenciais hardcoded aqui (remover antes de commitar)
