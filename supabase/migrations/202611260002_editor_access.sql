-- Thread & Fire: editor access and review controls.
-- Run once after 202611260001_newsroom.sql.
begin;

create table public.newsroom_editors (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.newsroom_editors enable row level security;
revoke all on public.newsroom_editors from public, anon, authenticated;

create function public.newsroom_is_editor()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.newsroom_editors e where e.user_id = auth.uid());
$$;
revoke all on function public.newsroom_is_editor() from public, anon, authenticated;
grant execute on function public.newsroom_is_editor() to authenticated;

grant select on public.source_videos, public.stories, public.story_sources, public.article_drafts, public.publication_history to authenticated;

create policy editor_read_sources on public.source_videos for select to authenticated using ((select public.newsroom_is_editor()));
create policy editor_read_stories on public.stories for select to authenticated using ((select public.newsroom_is_editor()));
create policy editor_read_story_sources on public.story_sources for select to authenticated using ((select public.newsroom_is_editor()));
create policy editor_read_drafts on public.article_drafts for select to authenticated using ((select public.newsroom_is_editor()));
create policy editor_read_publications on public.publication_history for select to authenticated using ((select public.newsroom_is_editor()));

-- Direct UPDATE is not granted to client roles. This function is the only
-- client-accessible mutation path and verifies the editor and draft state.
create function public.newsroom_review_draft(
  p_id uuid, p_action text, p_headline text, p_excerpt text, p_body text
)
returns public.article_drafts
language plpgsql security definer set search_path = ''
as $$
declare result public.article_drafts;
begin
  if not public.newsroom_is_editor() then
    raise exception 'Editor access required' using errcode = '42501';
  end if;
  if p_action is null or p_action not in ('save','approve','reject','rewrite') then
    raise exception 'Invalid editorial action';
  end if;
  if p_headline is null or p_excerpt is null or p_body is null or
     char_length(trim(p_headline)) not between 1 and 200 or
     char_length(trim(p_excerpt)) not between 1 and 600 or
     char_length(trim(p_body)) not between 1 and 20000 then
    raise exception 'Invalid draft text lengths';
  end if;
  update public.article_drafts
  set headline = trim(p_headline), excerpt = trim(p_excerpt), body = p_body,
      status = case p_action when 'approve' then 'approved' when 'reject' then 'rejected'
        when 'rewrite' then 'draft' else 'in_review' end,
      reviewed_at = case when p_action in ('approve','reject') then now() else null end,
      reviewed_by = case when p_action in ('approve','reject') then auth.uid() else null end
  where id = p_id and status in ('draft','in_review')
  returning * into result;
  if not found then raise exception 'Draft is no longer editable'; end if;
  return result;
end;
$$;
revoke all on function public.newsroom_review_draft(uuid,text,text,text,text) from public, anon, authenticated;
grant execute on function public.newsroom_review_draft(uuid,text,text,text,text) to authenticated;

-- The editor allowlist intentionally starts empty. After creating your user
-- in Authentication > Users, add its exact UID in a separate SQL operation:
-- insert into public.newsroom_editors(user_id) values ('YOUR-AUTH-USER-UID');

commit;
