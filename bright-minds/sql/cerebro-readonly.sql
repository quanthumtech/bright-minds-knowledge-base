-- Usuário somente leitura do Cérebro + schema `cerebro` (visões com colunas sensíveis removidas).
-- Rodar no banco do Supabase auto-hospedado, como supabase_admin. Pode ser reexecutado
-- (idempotente) sempre que o schema do CRM mudar: as visões são recriadas com as colunas atuais.
--
--   docker exec -i <container-db> psql -U supabase_admin -d postgres \
--     -v ro_password='<senha forte, so letras e numeros>' -v allow_pii=off < cerebro-readonly.sql
--
-- allow_pii=off (padrão): remove colunas de e-mail/telefone/CPF/RG e o conteúdo de mensagens.
-- allow_pii=on : mantém e-mail/telefone/CPF/RG (decisão do DPO/Bright Minds). O conteúdo das
--                mensagens e as colunas de segredos continuam fora em qualquer caso.
\set ON_ERROR_STOP on
\if :{?allow_pii} \else \set allow_pii off \endif
\if :{?ro_password} \else \echo 'defina -v ro_password=...' \quit \endif

select set_config('cerebro.allow_pii', :'allow_pii', false);

select format('create role cerebro_ro login password %L nosuperuser nocreatedb nocreaterole noinherit connection limit 5', :'ro_password')
where not exists (select 1 from pg_roles where rolname = 'cerebro_ro') \gexec
select format('alter role cerebro_ro with password %L', :'ro_password') \gexec

alter role cerebro_ro set default_transaction_read_only = on;
alter role cerebro_ro set statement_timeout = '30s';
alter role cerebro_ro set idle_in_transaction_session_timeout = '60s';
alter role cerebro_ro set search_path = cerebro;
select format('grant connect on database %I to cerebro_ro', current_database()) \gexec

create schema if not exists cerebro;
grant usage on schema cerebro to cerebro_ro;
revoke create on schema cerebro from cerebro_ro;

do $$
declare
  t record;
  cols text;
  allow_pii boolean := coalesce(current_setting('cerebro.allow_pii', true), 'off') = 'on';
  -- tabelas que nunca entram (credenciais, tokens, logs de acesso, gravações, e-mails completos)
  deny_tables text[] := array[
    'app_settings','client_integrations','client_meta_config','client_public_shares','client_users',
    'user_roles','crm_gmail_accounts','crm_instagram_accounts','crm_whatsapp_instances','evolution_audit_log',
    'meta_event_logs','access_logs','sync_logs','audit_snapshots','crm_call_recordings','crm_emails',
    'whatsapp_report_configs','whatsapp_report_sends'
  ];
  secret_re text := '(token|secret|password|passwd|api_?key|credential|hash|private|signature|qr_code)';
  pii_re text := '(^|_)(email|e_mail|phone|telefone|celular|cpf|rg)(_|$)';
begin
  for t in
    select c.relname
    from pg_class c
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','p')
    order by c.relname
  loop
    execute format('drop view if exists cerebro.%I', t.relname);
    continue when t.relname = any(deny_tables);

    select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into cols
    from pg_attribute a
    where a.attrelid = format('public.%I', t.relname)::regclass
      and a.attnum > 0 and not a.attisdropped
      and a.attname !~* secret_re
      and (allow_pii or a.attname !~* pii_re)
      and not (t.relname = 'crm_messages' and a.attname in ('message_text','rich_content','media_url','error_message'))
      and not (t.relname = 'profiles' and a.attname not in ('id','user_id','display_name','created_at'));

    if cols is not null then
      execute format('create view cerebro.%I with (security_barrier = true) as select %s from public.%I', t.relname, cols, t.relname);
    end if;
  end loop;
end $$;

-- remove visões de tabelas que deixaram de existir
do $$
declare v record;
begin
  for v in
    select viewname from pg_views
    where schemaname = 'cerebro'
      and not exists (select 1 from pg_class c where c.relnamespace = 'public'::regnamespace and c.relname = viewname)
  loop
    execute format('drop view cerebro.%I', v.viewname);
  end loop;
end $$;

revoke all on all tables in schema cerebro from cerebro_ro;
grant select on all tables in schema cerebro to cerebro_ro;

\echo 'ok: cerebro_ro criado/atualizado'
select count(*) as visoes_no_cerebro from pg_views where schemaname = 'cerebro';
