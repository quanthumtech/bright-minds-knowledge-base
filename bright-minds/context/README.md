# Contexto do Cérebro (projeto nao)

- `nao_config.yaml`: conexão com o banco do CRM (Postgres do Supabase auto-hospedado) pelo schema `cerebro`, via variáveis de ambiente (`CRM_DB_*`). Nenhum segredo fica neste arquivo.
- `RULES.md`: regras do agente em português (idioma, privacidade, uso das fontes).
- `databases/`: gerado por `nao sync` dentro do container (catálogo de colunas). Não é versionado.

Só o template `columns` está ativo no sync, de propósito: `preview`, `profiling` e `ai_summary` gravam ou enviam amostras de linhas, o que traria dados pessoais para o contexto e para o provedor de IA.
