begin;
-- Private supporting files. Uploaded evidence is not bank verification or a signature.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('bp-documents','bp-documents',false,10485760,array['application/pdf','image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;
create table if not exists public.bp_documents(
 id uuid primary key default gen_random_uuid(),tenancy_id uuid not null references public.bp_tenancies(id),
 object_path text not null unique,title text not null check(length(title) between 3 and 150),
 category text not null check(category in ('Lease','Inspection','Payment evidence','Deposit evidence','Other')),
 uploaded_by uuid not null references public.bp_profiles(id),created_at timestamptz not null default now()
);
alter table public.bp_documents enable row level security;
revoke all on public.bp_documents from anon,authenticated;
grant select on public.bp_documents to authenticated;
drop policy if exists document_scope on public.bp_documents;
create policy document_scope on public.bp_documents for select to authenticated using(public.bp_sees_tenancy(tenancy_id));
drop policy if exists bp_file_read on storage.objects;
create policy bp_file_read on storage.objects for select to authenticated using(bucket_id='bp-documents' and exists(select 1 from public.bp_documents d where d.object_path=name and public.bp_sees_tenancy(d.tenancy_id)));
drop policy if exists bp_file_upload on storage.objects;
create policy bp_file_upload on storage.objects for insert to authenticated with check(bucket_id='bp-documents' and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' and public.bp_sees_tenancy(split_part(name,'/',1)::uuid));
-- Only orphaned files owned by their uploader can be cleaned up. Registered evidence cannot be overwritten/deleted by the app.
drop policy if exists bp_file_cleanup on storage.objects;
create policy bp_file_cleanup on storage.objects for delete to authenticated using(bucket_id='bp-documents' and owner_id=auth.uid()::text and not exists(select 1 from public.bp_documents d where d.object_path=name));
create or replace function public.bp_register_document(tid uuid,path text,label text,category_name text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare rid uuid;
begin
 if not public.bp_sees_tenancy(tid) then raise exception 'Rental access required.';end if;
 if split_part(path,'/',1)<>tid::text or path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(pdf|jpg|png)$' or not exists(select 1 from storage.objects o where o.bucket_id='bp-documents' and o.name=path and o.owner_id=auth.uid()::text) then raise exception 'Upload your file to this rental first.';end if;
 insert into public.bp_documents(tenancy_id,object_path,title,category,uploaded_by) values(tid,path,trim(label),category_name,auth.uid()) returning id into rid;
 return rid;
end $$;
revoke all on function public.bp_register_document(uuid,text,text,text) from public,anon;
grant execute on function public.bp_register_document(uuid,text,text,text) to authenticated;

commit;
