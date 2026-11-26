-- Thread & Fire: private editorial database
begin;

create table public.source_videos (
  video_id text primary key check (video_id ~ '^[0-9]{15,22}$'),
  source_url text not null,
  creator_handle text,
  creator_name text,
  caption text not null default '',
  views bigint check (views >= 0),
  likes bigint check (likes >= 0),
  region text not null default 'US',
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  raw_metadata jsonb not null default '{}'::jsonb
);

create table public.stories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  topic text not null,
  category text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.story_sources (
  story_id uuid not null references public.stories(id),
  video_id text not null references public.source_videos(video_id),
  linked_at timestamptz not null default now(),
  primary key (story_id, video_id)
);

create table public.article_drafts (
  id uuid primary key default gen_random_uuid(),
  story_id uuid not null references public.stories(id),
  revision integer not null check (revision > 0),
  headline text not null,
  excerpt text not null,
  body text not null,
  citations jsonb not null default '[]'::jsonb,
  status text not null default 'draft' check (status in ('draft','in_review','approved','rejected','published')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  check (status not in ('approved','published','rejected') or (reviewed_at is not null and reviewed_by is not null)),
  unique (story_id, revision)
);

create table public.publication_history (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null unique references public.article_drafts(id),
  published_at timestamptz not null default now(),
  public_url text not null
);

create index source_videos_last_seen_idx on public.source_videos(last_seen_at desc);
create index stories_updated_idx on public.stories(updated_at desc);
create index story_sources_video_idx on public.story_sources(video_id);
create index article_drafts_status_idx on public.article_drafts(status, created_at desc);

-- No direct public or signed-in client access at this stage.
alter table public.source_videos enable row level security;
alter table public.stories enable row level security;
alter table public.story_sources enable row level security;
alter table public.article_drafts enable row level security;
alter table public.publication_history enable row level security;
revoke all on public.source_videos, public.stories, public.story_sources, public.article_drafts, public.publication_history from public, anon, authenticated;
grant select, insert, update on public.source_videos, public.stories, public.story_sources, public.article_drafts, public.publication_history to service_role;

commit;
