# Bright Minds Knowledge Base (o "Cérebro")

Fork do [getnao/nao](https://github.com/getnao/nao) com a identidade visual da Bright Minds e preparado para o Dokploy.
O Cérebro é um chat de IA que consulta o banco do CRM (Supabase auto-hospedado) e responde perguntas de negócio em português.

```
Navegador ─ HTTPS ─> Traefik (Dokploy) ─> nao (porta 5005) ─┬─> Postgres do nao (histórico de chat)
                                                             ├─> LLM (Anthropic/OpenAI, chave no Environment)
                                                             └─> rede Docker do Supabase ─> banco do CRM
                                                                   (usuário cerebro_ro, só leitura, schema cerebro)
```

## O que é de quem

| Pasta/arquivo | Conteúdo |
|---|---|
| `docker-compose.dokploy.yml` | Compose para o Dokploy: `nao` + Postgres do histórico. Sem `ports`; o domínio do Dokploy aponta para o `nao:5005` |
| `.env.dokploy.example` | Variáveis do Environment (copie e preencha; não versione o preenchido) |
| `bright-minds/sql/cerebro-readonly.sql` | Cria o usuário `cerebro_ro` e o schema `cerebro` (visões só com colunas permitidas) |
| `bright-minds/context/` | Projeto nao: `nao_config.yaml` (conexão por variáveis) e `RULES.md` (regras do agente em pt-BR) |
| `bright-minds/scripts/` | `create-readonly-role.sh` (cria o usuário e imprime os valores do Environment) e `sync.sh` (atualiza o catálogo) |
| `apps/frontend/...` | Rebranding: logo, ícones, cores, fontes, título (lista no fim) |

## Implantação passo a passo

Convenção: **[SERVIDOR]** = terminal SSH do servidor do Dokploy · **[DOKPLOY]** = painel · **[LOCAL]** = sua máquina.

### 1. [LOCAL] Publicar este repositório no GitHub
O repositório local tem `upstream` apontando para o getnao/nao. Crie um repositório da Quanthum (privado) e envie:
```bash
git remote add origin https://github.com/<org>/bright-minds-knowledge-base.git
git add -A && git commit -m "feat: Bright Minds Knowledge Base (branding + deploy Dokploy)"
git push -u origin main
```

### 2. [SERVIDOR] Criar o usuário somente leitura no banco do Supabase
O banco do CRM precisa existir (restore concluído). Copie o SQL e rode o script (gera a senha e a mostra uma vez):
```bash
# [LOCAL] envie os arquivos (ou clone o repositório no servidor)
scp -r bright-minds root@<servidor>:~/bright-minds
# [SERVIDOR]
bash ~/bright-minds/scripts/create-readonly-role.sh
```
O script imprime `CRM_DB_HOST`, `CRM_DB_USER`, `CRM_DB_PASSWORD` e as redes do container do banco. Anote-os.
- Por padrão remove colunas de e-mail/telefone/CPF/RG e o texto das mensagens (`ALLOW_PII=off`). Para liberar e-mail/telefone, só com decisão do DPO da Bright Minds: `ALLOW_PII=on bash .../create-readonly-role.sh`.
- O conteúdo das mensagens, tokens, credenciais e logs de acesso **nunca** entram.
- Reexecute o script sempre que o schema do CRM mudar (as visões são recriadas) e depois rode o sync (passo 6).

### 3. [SERVIDOR] Descobrir a rede do Supabase
```bash
docker inspect <CRM_DB_HOST> --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}'
```
Use como `SUPABASE_NETWORK` a rede do stack do Supabase (ex.: `bright-minds-supabase-xxxxxx_default`), não a `dokploy-network`.
> Se o stack do Supabase for recriado, o nome do container e da rede mudam: atualize `CRM_DB_HOST`/`SUPABASE_NETWORK`, rode de novo o passo 2 (senha nova) e faça Deploy.

### 4. [DOKPLOY] Criar o serviço
> Tem que ser do tipo **Compose**, não *Application*: o Cérebro precisa do Postgres do histórico, do contexto montado e da rede do Supabase, e o Dockerfile sozinho não entrega isso.
1. **Create Service → Compose** → Provider **Git** (o repositório do passo 1), branch `main`, **Compose Path** `./docker-compose.dokploy.yml`.
2. **Environment**: cole o conteúdo de `.env.dokploy.example` preenchido (`BETTER_AUTH_SECRET` com `openssl rand -base64 32`, `NAO_DB_PASSWORD` com `openssl rand -hex 16`, a chave do LLM e os valores do passo 2/3).
3. **Domains**: serviço `nao`, porta `5005`, HTTPS (Let's Encrypt). `BETTER_AUTH_URL` precisa ser exatamente essa URL.
4. **Deploy**. O primeiro build demora (imagem do nao com Chromium e dependências Python).

### 5. Primeiro acesso
Abra a URL e crie o primeiro usuário (vira administrador). O cadastro livre fica desligado (`ENABLE_USER_SIGNUP=false`); convide os demais pelas configurações.
Sem chave de LLM no Environment o chat não responde: preencha `ANTHROPIC_API_KEY`, `OPENAI_API_KEY` ou `GEMINI_API_KEY` e faça Redeploy.

### 6. [SERVIDOR] Sincronizar o catálogo
```bash
bash ~/bright-minds/scripts/sync.sh
```
Gera, dentro do volume, o catálogo de colunas das visões do schema `cerebro` (só estrutura; nada de amostras de dados). No Dokploy dá para agendar o mesmo comando em **Schedules** (diário).

### 7. Teste de fumaça
Pergunte: "Quantos negócios foram criados por mês neste ano?" e "Quais são as origens de contatos com mais volume?". O Cérebro deve citar a tabela e o período. Peça um telefone ou o texto de uma conversa: ele deve recusar (política de privacidade + visões sem essas colunas).

## Rodar localmente (sem Docker)
Perfis em `bright-minds/local/`: **demo** (Postgres local descartável com dados fictícios) e **staging** (o CRM recém-migrado, por túnel SSH).
Requisitos: `bun` no PATH, `uv` e Docker. Uma vez:
```bash
cd bright-minds/local
uv venv --python 3.13 .venv && uv pip install --python .venv/bin/python -e "../../cli[postgres]" "psycopg[binary]" packaging
bun install --ignore-scripts          # na raiz do repositório
./build-frontend.sh                    # compila o frontend em apps/frontend/dist (contêiner Node 22)
```
**Demo:** `./demo-db.sh up && ./start.sh demo` → http://localhost:5005 (o primeiro usuário vira administrador).

**Staging (banco real migrado):**
1. [SERVIDOR] `bash ~/bright-minds/scripts/create-readonly-role.sh` e anote `CRM_DB_PASSWORD` e o container do banco.
2. [SERVIDOR] IP do container na rede do Supabase: `docker inspect <container-do-banco> --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{$v.IPAddress}}{{"\n"}}{{end}}'`
3. [LOCAL] túnel (deixe aberto): `ssh -N -L 55433:<IP>:5432 root@<servidor>`
4. [LOCAL] preencha `bright-minds/local/.env.staging` (`CRM_DB_PASSWORD` e a chave do LLM) e rode `./start.sh staging sync`.
Parar: `./start.sh stop`. Logs em `bright-minds/local/run-<perfil>/`. Os arquivos `.env.*` e `run-*` não são versionados.

## Segurança e LGPD
- **Banco nunca exposto**: o `nao` entra na rede Docker do Supabase; nenhuma porta do Postgres é publicada.
- **Usuário `cerebro_ro`**: leitura apenas do schema `cerebro`; `default_transaction_read_only`, timeout de 30 s, no máximo 5 conexões, sem acesso a `public`, `auth` ou `storage`.
- **O que o LLM recebe**: o resultado das consultas feitas pelo agente vai para o provedor de LLM escolhido (Anthropic/OpenAI). Isso é transferência internacional de dados: alinhar com o DPO da Bright Minds antes de liberar para o time e antes de usar `ALLOW_PII=on`.
- **Multi-cliente**: o CRM é multi-tenant (`client_id`); o Cérebro enxerga todos os clientes. Quem acessa o Cérebro precisa ter essa permissão.
- **Telemetria desligada** (`POSTHOG_DISABLED=true`). Sem afirmação de certificação de segurança neste projeto.

## Licença (importante)
O nao é Apache 2.0, **exceto 52 arquivos marcados `/* @license Enterprise */`**, que têm licença comercial (uso em produção exige subscrição ou acordo com a nao Labs). O white-label nativo do nao é um desses arquivos e **não foi usado**: o rebranding foi feito só em arquivos Apache (assets, CSS, componentes de logo, `index.html`). A imagem oficial contém os arquivos Enterprise (desativados sem licença). **Antes de ir para produção, confirme com a nao Labs (https://getnao.io) se o uso interno da Bright Minds sem subscrição é coberto.** Esta nota não é parecer jurídico.

## Rebranding aplicado (arquivos Apache)
- Logo/ícones: `apps/frontend/public/{appicon.png,color.png,outline.png,favicon.ico,lightLogo.svg,darkLogo.svg}` + `bright-minds-logo.png`/`bright-minds-mark.png`; `src/components/icons/{nao-logo.svg,nao-full-logo.svg,nao-logo-greyscale.svg}` (PNG embutido) e `nao-logo-animated.tsx` (pulso da marca).
- Cores/fontes: `src/styles.css` (amarelo `#FFDA00`, tinta `#0B0C12`, osso `#F4F4F0`; Inter + Sora; claro e escuro). Texto de botões sobre amarelo em `ui/button.tsx` e `settings/slack-form.tsx`.
- `index.html` (título, descrição, `lang=pt-BR`, theme-color) e o rótulo do menu em `sidebar-settings-nav.tsx`.
- A interface do nao continua em inglês (o projeto não tem i18n); o agente responde em português pelas regras de `context/RULES.md`.

## Atualizar a partir do nao oficial
```bash
git fetch upstream && git merge upstream/main
```
Conflitos esperados só nos arquivos de branding acima; mantenha a versão Bright Minds neles.

## Problemas comuns
| Sintoma | Causa provável |
|---|---|
| Deploy falha com `defina SUPABASE_NETWORK` ou `network ... not found` | Rede errada ou stack do Supabase recriado: refaça o passo 3 |
| `nao debug` / chat: `connection refused` ou `could not translate host name` | `CRM_DB_HOST` errado (nome do container mudou) ou serviço fora da rede do Supabase |
| `password authentication failed for user "cerebro_ro"` | Senha desatualizada: rode o passo 2 de novo e atualize `CRM_DB_PASSWORD` |
| Catálogo vazio / "0 tables" | O passo 2 não foi executado (schema `cerebro` vazio) ou faltou o sync (passo 6) |
| Chat sem resposta | Falta `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` no Environment |
| Página não abre / redireciona errado | `BETTER_AUTH_URL` diferente da URL do domínio |
