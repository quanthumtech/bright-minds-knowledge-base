-- Dados FICTÍCIOS só para testar o Cérebro localmente (não é o CRM real).
create table if not exists public.clients (id serial primary key, name text, plano text, segmento text, fee_mensal numeric, email text, created_at timestamptz default now());
create table if not exists public.client_users (id serial primary key, client_id int, user_id uuid, client_role text);
create table if not exists public.crm_contacts (id serial primary key, client_id int, name text, email text, phone text, source text, tags text[], created_at timestamptz default now());
create table if not exists public.crm_deals (id serial primary key, contact_id int, title text, value numeric, status text, pipeline text, created_at timestamptz default now());
create table if not exists public.crm_messages (id serial primary key, contact_id int, channel text, direction text, message_text text, created_at timestamptz default now());
create table if not exists public.crm_gmail_accounts (id serial primary key, email text, access_token text, refresh_token text);
create table if not exists public.profiles (id serial primary key, user_id uuid, display_name text, email text, phone text, created_at timestamptz default now());
truncate clients, client_users, crm_contacts, crm_deals, crm_messages, crm_gmail_accounts, profiles restart identity;
insert into crm_contacts(client_id,name,email,phone,source,created_at)
  select 1 + g % 3, 'Contato ' || g, 'c' || g || '@exemplo.invalid', '11000' || g,
         (array['site','meta_ads','google_ads','indicacao','whatsapp'])[1 + g % 5],
         now() - (g % 360 || ' days')::interval from generate_series(1,400) g;
insert into crm_deals(contact_id,title,value,status,pipeline,created_at)
  select 1 + g % 400, 'Negócio ' || g, 500 + (g * 37) % 9500,
         (array['aberto','ganho','perdido'])[1 + g % 3], (array['vendas','pos_venda'])[1 + g % 2],
         now() - ((g * 3) % 330 || ' days')::interval from generate_series(1,600) g;
insert into crm_messages(contact_id,channel,direction,message_text,created_at)
  select 1 + g % 400, (array['whatsapp','instagram','email'])[1 + g % 3], (array['in','out'])[1 + g % 2], 'texto privado ' || g,
         now() - ((g * 2) % 120 || ' days')::interval from generate_series(1,900) g;
insert into crm_gmail_accounts(email,access_token,refresh_token) values ('x@exemplo.invalid','SEGREDO-FICTICIO','SEGREDO-FICTICIO-2');
insert into profiles(user_id,display_name,email,phone) values (gen_random_uuid(),'Atendente Demo','a@exemplo.invalid','11');
insert into clients(name,plano,segmento,fee_mensal,email) values ('Cliente Demo A','pro','varejo',4500,'a@exemplo.invalid'),('Cliente Demo B','basico','servicos',2200,'b@exemplo.invalid'),('Cliente Demo C','pro','saude',6100,'c@exemplo.invalid');
insert into client_users(client_id,user_id,client_role) values (1,gen_random_uuid(),'admin');
