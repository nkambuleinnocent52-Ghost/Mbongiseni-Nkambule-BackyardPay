-- Test-only contract stub in the disposable PostgreSQL database. It does not
-- install pg_cron or execute an actual background job. Do not run in Supabase.
create schema cron;
create table cron.job(jobid bigserial primary key,jobname text unique not null,schedule text not null,command text not null,active boolean not null default true);
create function cron.schedule(text,text,text) returns bigint language sql as $$
 insert into cron.job(jobname,schedule,command,active) values($1,$2,$3,true)
 on conflict(jobname) do update set schedule=excluded.schedule,command=excluded.command,active=true returning jobid;
$$;
revoke all on function cron.schedule(text,text,text) from public,anon,authenticated;
