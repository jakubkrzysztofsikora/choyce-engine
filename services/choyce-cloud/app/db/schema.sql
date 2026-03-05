-- Choyce Cloud initial schema

create table if not exists families (
    family_id text primary key,
    created_at timestamptz not null default now()
);

create table if not exists profiles (
    profile_id text primary key,
    family_id text not null references families(family_id),
    role text not null check (role in ('kid', 'parent')),
    created_at timestamptz not null default now()
);

create table if not exists invites (
    invite_code text primary key,
    family_id text not null references families(family_id),
    session_id text not null,
    expires_at timestamptz not null,
    created_at timestamptz not null default now()
);

create table if not exists sessions (
    session_id text primary key,
    family_id text not null references families(family_id),
    world_id text not null,
    host_profile_id text not null references profiles(profile_id),
    status text not null,
    created_at timestamptz not null default now(),
    closed_at timestamptz
);

create table if not exists publish_requests (
    request_id text primary key,
    project_id text not null,
    world_id text not null,
    requester_profile_id text not null references profiles(profile_id),
    reviewer_profile_id text references profiles(profile_id),
    state text not null,
    visibility text not null,
    moderation_blob jsonb not null default '[]'::jsonb,
    rejection_reason text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists catalog_entries (
    listing_id text primary key,
    project_id text not null,
    actor_profile_id text not null references profiles(profile_id),
    metadata jsonb not null default '{}'::jsonb,
    approval_state text not null,
    visibility text not null,
    created_at timestamptz not null default now(),
    reviewed_at timestamptz
);

create table if not exists audit_events (
    event_id text primary key,
    parent_id text,
    actor_profile_id text,
    event_type text not null,
    payload jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create table if not exists lifecycle_jobs (
    job_id text primary key,
    job_type text not null check (job_type in ('export', 'delete', 'retention_update')),
    parent_profile_id text not null references profiles(profile_id),
    subject_profile_id text not null references profiles(profile_id),
    payload jsonb not null default '{}'::jsonb,
    status text not null,
    created_at timestamptz not null default now(),
    completed_at timestamptz
);

create table if not exists retention_policies (
    subject_profile_id text primary key references profiles(profile_id),
    policy jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now()
);

create table if not exists consent_records (
    consent_id text primary key,
    subject_profile_id text not null references profiles(profile_id),
    consent_key text not null,
    granted boolean not null,
    reason text not null default '',
    updated_at timestamptz not null default now()
);
