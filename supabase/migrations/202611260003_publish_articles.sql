-- Thread & Fire: private-to-public publication boundary.
-- Run once after the newsroom and editor migrations.
begin;

create table public.published_articles (
  slug text primary key check (slug ~ '^[a-z0-9-]+$'),
  headline text not null check (char_length(headline) between 1 and 200),
  excerpt text not null check (char_length(excerpt) between 1 and 600),
  body text not null check (char_length(body) between 1 and 20000),
  category text not null check (category in ('Culture','Technology','Food','Lifestyle')),
  sources jsonb not null default '[]'::jsonb check (jsonb_typeof(sources) = 'array'),
  published_at timestamptz not null default now()
);
alter table public.published_articles enable row level security;
revoke all on public.published_articles from public, anon, authenticated;
grant select on public.published_articles to anon, authenticated;
create policy public_read_published_articles on public.published_articles
  for select to anon, authenticated using (true);

-- Atomic publish: only allowlisted signed-in editors, only reviewable drafts.
-- The public body is explicitly reviewed separately from the private notes.
create function public.newsroom_publish_draft(
  p_id uuid, p_headline text, p_excerpt text, p_public_body text, p_category text
) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  d public.article_drafts;
  s public.stories;
  public_sources jsonb;
  source_links jsonb;
begin
  if not public.newsroom_is_editor() then
    raise exception 'Editor access required' using errcode = '42501';
  end if;
  if p_headline is null or p_excerpt is null or p_public_body is null or p_category is null or
     char_length(trim(p_headline)) not between 1 and 200 or
     char_length(trim(p_excerpt)) not between 1 and 600 or
     char_length(trim(p_public_body)) not between 1 and 20000 or
     p_category not in ('Culture','Technology','Food','Lifestyle') then
    raise exception 'Invalid publication fields';
  end if;
  if p_public_body ~* '(^|[[:space:]])editorial[[:space:]]+checks[[:space:]]*:' or
     p_public_body ~* '(^|[[:space:]])internal[[:space:]]+notes[[:space:]]*:' then
    raise exception 'Remove internal editorial notes before publishing';
  end if;
  select * into d from public.article_drafts where id = p_id for update;
  if not found or d.status not in ('draft','in_review','approved') then
    raise exception 'Draft is not eligible for publication';
  end if;
  select * into s from public.stories where id = d.story_id for update;
  if not found then raise exception 'Story not found'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('url', c->>'url', 'title', left(coalesce(c->>'title','Source'),200))), '[]'::jsonb)
    into public_sources from jsonb_array_elements(case when jsonb_typeof(d.citations) = 'array' then d.citations else '[]'::jsonb end) c
    where c->>'url' ~ '^https://[^[:space:]]+$';
  select coalesce(jsonb_agg(jsonb_build_object('url',v.source_url,'title','Original TikTok')), '[]'::jsonb)
    into source_links from public.story_sources ss join public.source_videos v on ss.video_id=v.video_id
    where ss.story_id=s.id and v.source_url ~ '^https://www\.tiktok\.com/[^[:space:]]+$';
  insert into public.published_articles(slug,headline,excerpt,body,category,sources,published_at)
    values (s.slug,trim(p_headline),trim(p_excerpt),trim(p_public_body),p_category,source_links||public_sources,now())
    on conflict (slug) do update set headline=excluded.headline,excerpt=excluded.excerpt,body=excluded.body,category=excluded.category,sources=excluded.sources,published_at=excluded.published_at;
  update public.stories set category=p_category,updated_at=now() where id=s.id;
  update public.article_drafts set headline=trim(p_headline),excerpt=trim(p_excerpt),status='published',reviewed_at=now(),reviewed_by=auth.uid() where id=d.id;
  insert into public.publication_history(draft_id,public_url)
    values(d.id,'https://threadandfire.github.io/website/#story/'||s.slug);
  return s.slug;
end;
$$;
revoke all on function public.newsroom_publish_draft(uuid,text,text,text,text) from public, anon, authenticated;
grant execute on function public.newsroom_publish_draft(uuid,text,text,text,text) to authenticated;

commit;
