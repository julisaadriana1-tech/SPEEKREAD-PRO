-- SpeakRead Pro — esquema inicial
-- Ejecutar en Supabase: SQL Editor > New query > pegar todo > Run
-- (o con la CLI: supabase db push)

create extension if not exists pgcrypto;

-- =========================================================
-- 1. PERFIL
-- =========================================================
create table public.profiles (
  id              uuid primary key references auth.users on delete cascade,
  display_name    text,
  job_role        text,
  goals           text[] not null default '{}',
  interests       text[] not null default '{}',
  daily_goal_min  int  not null default 10 check (daily_goal_min in (5, 10, 15)),
  cefr_level      text not null default 'A1' check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  onboarded       boolean not null default false,
  is_admin        boolean not null default false,
  xp_total        int  not null default 0,
  current_streak  int  not null default 0,
  longest_streak  int  not null default 0,
  last_active_on  date,
  created_at      timestamptz not null default now()
);

-- Crea el perfil automáticamente al registrarse
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)));
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =========================================================
-- 2. CONTENIDO
-- =========================================================
create table public.lessons (
  id           uuid primary key default gen_random_uuid(),
  cefr_level   text not null check (cefr_level in ('A1','A2','B1','B2','C1','C2')),
  unit         int  not null default 1,
  order_index  int  not null default 1,
  title        text not null,
  context      text not null check (context in ('work','life')),
  topic        text not null,
  body_en      text not null,
  body_es      text,
  audio_url    text,
  est_minutes  int  not null default 10,
  published    boolean not null default false,
  created_at   timestamptz not null default now()
);
create index on public.lessons (cefr_level, unit, order_index);

create table public.lesson_sentences (
  id         uuid primary key default gen_random_uuid(),
  lesson_id  uuid not null references public.lessons on delete cascade,
  idx        int  not null,
  text_en    text not null,
  text_es    text,
  audio_url  text,
  unique (lesson_id, idx)
);

create table public.vocabulary (
  id              uuid primary key default gen_random_uuid(),
  lesson_id       uuid not null references public.lessons on delete cascade,
  word            text not null,
  ipa             text,
  definition_en   text,
  translation_es  text,
  example_en      text
);
create index on public.vocabulary (lesson_id);

create table public.quiz_questions (
  id           uuid primary key default gen_random_uuid(),
  lesson_id    uuid not null references public.lessons on delete cascade,
  idx          int  not null default 0,
  type         text not null check (type in ('mc','tf','gap','context')),
  prompt       text not null,
  options      jsonb not null default '[]',
  answer       text not null,
  explanation  text
);
create index on public.quiz_questions (lesson_id);

create table public.badges (
  code         text primary key,
  name         text not null,
  description  text not null,
  icon         text not null default 'emoji_events'
);

create table public.challenges (
  id         serial primary key,
  period     text not null check (period in ('daily','weekly')),
  title      text not null,
  metric     text not null check (metric in ('lessons','good_sentences','minutes','quiz_correct')),
  target     int  not null,
  xp_reward  int  not null default 25,
  starts_on  date,
  ends_on    date,
  active     boolean not null default true
);

-- =========================================================
-- 3. DATOS DEL USUARIO
-- =========================================================
create table public.lesson_attempts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles on delete cascade,
  lesson_id     uuid not null references public.lessons on delete cascade,
  started_at    timestamptz,
  completed_at  timestamptz not null default now(),
  pron_score    numeric,
  accuracy      numeric,
  fluency       numeric,
  completeness  numeric,
  prosody       numeric,
  quiz_score    numeric,
  xp_earned     int not null default 0,
  duration_sec  int not null default 0
);
create index on public.lesson_attempts (user_id, completed_at desc);

create table public.pronunciation_attempts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles on delete cascade,
  lesson_id       uuid references public.lessons on delete cascade,
  sentence_id     uuid references public.lesson_sentences on delete cascade,
  reference_text  text not null,
  overall_score   numeric,
  accuracy        numeric,
  fluency         numeric,
  completeness    numeric,
  prosody         numeric,
  words           jsonb not null default '[]',
  created_at      timestamptz not null default now()
);
create index on public.pronunciation_attempts (user_id, lesson_id, created_at desc);

create table public.quiz_answers (
  attempt_id   uuid not null references public.lesson_attempts on delete cascade,
  question_id  uuid not null references public.quiz_questions on delete cascade,
  answer       text,
  is_correct   boolean not null,
  primary key (attempt_id, question_id)
);

create table public.user_words (
  user_id          uuid not null references public.profiles on delete cascade,
  vocab_id         uuid not null references public.vocabulary on delete cascade,
  status           text not null default 'new' check (status in ('new','learning','mastered')),
  best_score       numeric not null default 0,
  times_practiced  int not null default 0,
  last_seen_at     timestamptz,
  primary key (user_id, vocab_id)
);

create table public.daily_activity (
  user_id            uuid not null references public.profiles on delete cascade,
  day                date not null,
  minutes            int not null default 0,
  xp                 int not null default 0,
  lessons_completed  int not null default 0,
  good_sentences     int not null default 0,
  quiz_correct       int not null default 0,
  primary key (user_id, day)
);

create table public.user_badges (
  user_id     uuid not null references public.profiles on delete cascade,
  badge_code  text not null references public.badges on delete cascade,
  earned_at   timestamptz not null default now(),
  primary key (user_id, badge_code)
);

create table public.user_challenges (
  user_id       uuid not null references public.profiles on delete cascade,
  challenge_id  int  not null references public.challenges on delete cascade,
  period_start  date not null,
  progress      int  not null default 0,
  completed_at  timestamptz,
  primary key (user_id, challenge_id, period_start)
);

-- =========================================================
-- 4. SEGURIDAD (Row Level Security)
-- =========================================================
alter table public.profiles               enable row level security;
alter table public.lessons                enable row level security;
alter table public.lesson_sentences       enable row level security;
alter table public.vocabulary             enable row level security;
alter table public.quiz_questions         enable row level security;
alter table public.badges                 enable row level security;
alter table public.challenges             enable row level security;
alter table public.lesson_attempts        enable row level security;
alter table public.pronunciation_attempts enable row level security;
alter table public.quiz_answers           enable row level security;
alter table public.user_words             enable row level security;
alter table public.daily_activity         enable row level security;
alter table public.user_badges            enable row level security;
alter table public.user_challenges        enable row level security;

-- Perfil: cada persona ve y edita solo el suyo, y solo columnas "seguras".
create policy "own profile read"   on public.profiles for select using (id = auth.uid());
create policy "own profile update" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated, anon;
grant update (display_name, job_role, goals, interests, daily_goal_min, cefr_level, onboarded)
  on public.profiles to authenticated;

-- Contenido: lectura para usuarios logueados, solo lecciones publicadas.
create policy "published lessons" on public.lessons for select to authenticated using (published);
create policy "sentences of published" on public.lesson_sentences for select to authenticated
  using (exists (select 1 from public.lessons l where l.id = lesson_id and l.published));
create policy "vocab of published" on public.vocabulary for select to authenticated
  using (exists (select 1 from public.lessons l where l.id = lesson_id and l.published));
create policy "quiz of published" on public.quiz_questions for select to authenticated
  using (exists (select 1 from public.lessons l where l.id = lesson_id and l.published));
create policy "badges read"     on public.badges     for select to authenticated using (true);
create policy "challenges read" on public.challenges for select to authenticated using (true);

-- Datos del usuario: solo lectura de lo propio.
-- Las escrituras las hacen complete_lesson() y la Edge Function (con service role),
-- así nadie puede asignarse XP o puntajes desde la app.
create policy "own attempts"   on public.lesson_attempts        for select using (user_id = auth.uid());
create policy "own pron"       on public.pronunciation_attempts for select using (user_id = auth.uid());
create policy "own answers"    on public.quiz_answers           for select
  using (exists (select 1 from public.lesson_attempts a where a.id = attempt_id and a.user_id = auth.uid()));
create policy "own words"      on public.user_words             for select using (user_id = auth.uid());
create policy "own activity"   on public.daily_activity         for select using (user_id = auth.uid());
create policy "own badges"     on public.user_badges            for select using (user_id = auth.uid());
create policy "own challenges" on public.user_challenges        for select using (user_id = auth.uid());

-- =========================================================
-- 5. LÓGICA DE NEGOCIO EN EL SERVIDOR
-- =========================================================

-- Fecha local del usuario a partir de su offset en minutos (ej. Asunción = -180)
create or replace function public.local_day(p_offset_min int)
returns date language sql stable as $$
  select ((now() at time zone 'utc') + make_interval(mins => coalesce(p_offset_min, 0)))::date;
$$;

-- Desafío diario activo para una fecha (rota por día del año)
create or replace function public.daily_challenge_for(p_day date)
returns public.challenges language sql stable as $$
  select c.* from public.challenges c
  where c.period = 'daily' and c.active
  order by c.id
  offset (extract(doy from p_day)::int % greatest(
           (select count(*) from public.challenges where period = 'daily' and active)::int, 1))
  limit 1;
$$;

-- Cierra una lección: corrige el quiz, calcula XP, racha, palabras, desafío e insignias.
-- p_answers: [{"question_id": "...", "answer": "..."}]
create or replace function public.complete_lesson(
  p_lesson_id     uuid,
  p_answers       jsonb,
  p_duration_sec  int,
  p_started_at    timestamptz default null,
  p_offset_min    int default 0
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_uid        uuid := auth.uid();
  v_today      date := public.local_day(p_offset_min);
  v_since      timestamptz := now() - interval '3 hours';
  v_good       int := 0;
  v_ok         int := 0;
  v_sent_avg   numeric;
  v_full       record;
  v_pron       numeric;
  v_attempt    uuid;
  v_correct    int := 0;
  v_total      int := 0;
  v_quiz       numeric;
  v_xp         int := 0;
  v_ch         public.challenges;
  v_prog       int;
  v_ch_done    boolean := false;
  v_prof       record;
  v_streak     int;
  v_badges     text[] := '{}';
  v_duration   int := least(greatest(coalesce(p_duration_sec, 0), 0), 3600);
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  if not exists (select 1 from lessons where id = p_lesson_id and published) then
    raise exception 'lesson not found';
  end if;

  -- Mejor puntaje por oración en esta sesión (últimas 3 horas)
  select count(*) filter (where s >= 80),
         count(*) filter (where s >= 60 and s < 80),
         avg(s)
    into v_good, v_ok, v_sent_avg
  from (
    select sentence_id, max(overall_score) as s
    from pronunciation_attempts
    where user_id = v_uid and lesson_id = p_lesson_id
      and sentence_id is not null and created_at > v_since
    group by sentence_id
  ) best;

  -- Última lectura completa en voz alta
  select overall_score, accuracy, fluency, completeness, prosody
    into v_full
  from pronunciation_attempts
  where user_id = v_uid and lesson_id = p_lesson_id
    and sentence_id is null and created_at > v_since
  order by created_at desc
  limit 1;

  v_pron := coalesce(v_full.overall_score, round(v_sent_avg));

  insert into lesson_attempts (user_id, lesson_id, started_at, pron_score, accuracy, fluency,
                               completeness, prosody, duration_sec)
  values (v_uid, p_lesson_id, p_started_at, v_pron, v_full.accuracy, v_full.fluency,
          v_full.completeness, v_full.prosody, v_duration)
  returning id into v_attempt;

  -- Corrección del quiz en el servidor
  insert into quiz_answers (attempt_id, question_id, answer, is_correct)
  select v_attempt, q.id, a->>'answer',
         lower(trim(coalesce(a->>'answer', ''))) = lower(trim(q.answer))
  from jsonb_array_elements(coalesce(p_answers, '[]'::jsonb)) a
  join quiz_questions q on q.id = (a->>'question_id')::uuid and q.lesson_id = p_lesson_id
  on conflict do nothing;

  select count(*) filter (where is_correct), count(*)
    into v_correct, v_total
  from quiz_answers where attempt_id = v_attempt;

  v_quiz := case when v_total > 0 then round(100.0 * v_correct / v_total) end;

  -- XP (ver sección 7 del documento de producto)
  v_xp := v_good * 5 + v_ok * 2
        + case when v_full.overall_score is not null then 20 + floor(v_full.overall_score / 5)::int else 0 end
        + v_correct * 3
        + 15;

  -- Vocabulario: mejor puntaje de cada palabra de la lección en esta sesión
  with ws as (
    select lower(regexp_replace(w->>'word', '[^a-zA-Z''-]', '', 'g')) as word,
           (w->>'score')::numeric as score
    from pronunciation_attempts pa, jsonb_array_elements(pa.words) w
    where pa.user_id = v_uid and pa.lesson_id = p_lesson_id and pa.created_at > v_since
  ), vs as (
    select v.id, max(ws.score) as best, count(ws.score)::int as n
    from vocabulary v
    left join ws on ws.word = lower(v.word)
    where v.lesson_id = p_lesson_id
    group by v.id
  )
  insert into user_words (user_id, vocab_id, status, best_score, times_practiced, last_seen_at)
  select v_uid, id,
         case when coalesce(best, 0) >= 80 and n >= 3 then 'mastered' else 'learning' end,
         coalesce(best, 0), n, now()
  from vs
  on conflict (user_id, vocab_id) do update set
    best_score      = greatest(user_words.best_score, excluded.best_score),
    times_practiced = user_words.times_practiced + excluded.times_practiced,
    last_seen_at    = now(),
    status = case
      when greatest(user_words.best_score, excluded.best_score) >= 80
       and user_words.times_practiced + excluded.times_practiced >= 3 then 'mastered'
      else 'learning' end;

  -- Actividad del día
  insert into daily_activity (user_id, day, minutes, xp, lessons_completed, good_sentences, quiz_correct)
  values (v_uid, v_today, ceil(v_duration / 60.0)::int, v_xp, 1, v_good, v_correct)
  on conflict (user_id, day) do update set
    minutes           = daily_activity.minutes + excluded.minutes,
    xp                = daily_activity.xp + excluded.xp,
    lessons_completed = daily_activity.lessons_completed + 1,
    good_sentences    = daily_activity.good_sentences + excluded.good_sentences,
    quiz_correct      = daily_activity.quiz_correct + excluded.quiz_correct;

  -- Desafío diario
  v_ch := public.daily_challenge_for(v_today);
  if v_ch.id is not null then
    select case v_ch.metric
             when 'lessons'        then lessons_completed
             when 'good_sentences' then good_sentences
             when 'minutes'        then minutes
             when 'quiz_correct'   then quiz_correct
           end
      into v_prog
    from daily_activity where user_id = v_uid and day = v_today;

    insert into user_challenges (user_id, challenge_id, period_start, progress)
    values (v_uid, v_ch.id, v_today, v_prog)
    on conflict (user_id, challenge_id, period_start) do update set progress = excluded.progress;

    if v_prog >= v_ch.target then
      update user_challenges set completed_at = now()
      where user_id = v_uid and challenge_id = v_ch.id and period_start = v_today
        and completed_at is null;
      if found then
        v_ch_done := true;
        v_xp := v_xp + v_ch.xp_reward;
        update daily_activity set xp = xp + v_ch.xp_reward where user_id = v_uid and day = v_today;
      end if;
    end if;
  end if;

  update lesson_attempts set quiz_score = v_quiz, xp_earned = v_xp where id = v_attempt;

  -- Racha
  select current_streak, longest_streak, last_active_on into v_prof
  from profiles where id = v_uid for update;

  v_streak := case
    when v_prof.last_active_on = v_today     then greatest(v_prof.current_streak, 1)
    when v_prof.last_active_on = v_today - 1 then v_prof.current_streak + 1
    else 1 end;

  update profiles set
    xp_total       = xp_total + v_xp,
    current_streak = v_streak,
    longest_streak = greatest(longest_streak, v_streak),
    last_active_on = v_today
  where id = v_uid;

  -- Insignias
  insert into user_badges (user_id, badge_code) values (v_uid, 'first_words') on conflict do nothing;
  if found then v_badges := array_append(v_badges, 'first_words'); end if;

  if v_streak >= 7 then
    insert into user_badges (user_id, badge_code) values (v_uid, 'on_track') on conflict do nothing;
    if found then v_badges := array_append(v_badges, 'on_track'); end if;
  end if;
  if v_streak >= 90 then
    insert into user_badges (user_id, badge_code) values (v_uid, 'quarter_close') on conflict do nothing;
    if found then v_badges := array_append(v_badges, 'quarter_close'); end if;
  end if;
  if coalesce(v_full.accuracy, 0) >= 100 then
    insert into user_badges (user_id, badge_code) values (v_uid, 'perfect_read') on conflict do nothing;
    if found then v_badges := array_append(v_badges, 'perfect_read'); end if;
  end if;

  return jsonb_build_object(
    'attempt_id',          v_attempt,
    'xp_earned',           v_xp,
    'pron_score',          v_pron,
    'accuracy',            v_full.accuracy,
    'fluency',             v_full.fluency,
    'completeness',        v_full.completeness,
    'prosody',             v_full.prosody,
    'quiz_score',          v_quiz,
    'quiz_correct',        v_correct,
    'quiz_total',          v_total,
    'good_sentences',      v_good,
    'streak',              v_streak,
    'challenge_completed', v_ch_done,
    'new_badges',          to_jsonb(v_badges)
  );
end; $$;

-- Datos del dashboard en una sola llamada
create or replace function public.get_dashboard(p_offset_min int default 0)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_today  date := public.local_day(p_offset_min);
  v_p      public.profiles;
  v_ch     public.challenges;
  v_result jsonb;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select * into v_p from profiles where id = v_uid;
  v_ch := public.daily_challenge_for(v_today);

  select jsonb_build_object(
    'display_name',      v_p.display_name,
    'cefr_level',        v_p.cefr_level,
    'xp_total',          v_p.xp_total,
    'current_streak',    case when v_p.last_active_on >= v_today - 1 then v_p.current_streak else 0 end,
    'longest_streak',    v_p.longest_streak,
    'studied_today',     coalesce(v_p.last_active_on = v_today, false),
    'daily_goal_min',    v_p.daily_goal_min,
    'lessons_total_in_level',
        (select count(*) from lessons where published and cefr_level = v_p.cefr_level),
    'lessons_done_in_level',
        (select count(distinct a.lesson_id) from lesson_attempts a
           join lessons l on l.id = a.lesson_id
          where a.user_id = v_uid and l.cefr_level = v_p.cefr_level),
    'lessons_done_total',
        (select count(distinct lesson_id) from lesson_attempts where user_id = v_uid),
    'words_learned',
        (select count(*) from user_words where user_id = v_uid),
    'words_mastered',
        (select count(*) from user_words where user_id = v_uid and status = 'mastered'),
    'avg_pron_30d',
        (select round(avg(overall_score)) from pronunciation_attempts
          where user_id = v_uid and created_at > now() - interval '30 days'),
    'minutes_total',
        (select coalesce(sum(minutes), 0) from daily_activity where user_id = v_uid),
    'minutes_today',
        (select coalesce(sum(minutes), 0) from daily_activity where user_id = v_uid and day = v_today),
    'challenge', case when v_ch.id is null then null else jsonb_build_object(
        'title',     v_ch.title,
        'target',    v_ch.target,
        'xp_reward', v_ch.xp_reward,
        'progress',  coalesce((select progress from user_challenges
                                where user_id = v_uid and challenge_id = v_ch.id
                                  and period_start = v_today), 0),
        'completed', exists (select 1 from user_challenges
                              where user_id = v_uid and challenge_id = v_ch.id
                                and period_start = v_today and completed_at is not null)
      ) end,
    'badges',
        (select coalesce(jsonb_agg(jsonb_build_object('code', b.code, 'name', b.name,
                 'description', b.description, 'earned', ub.earned_at is not null)
                 order by ub.earned_at nulls last, b.code), '[]'::jsonb)
           from badges b
           left join user_badges ub on ub.badge_code = b.code and ub.user_id = v_uid),
    'recent',
        (select coalesce(jsonb_agg(r order by r.completed_at desc), '[]'::jsonb) from (
           select a.lesson_id, l.title, l.cefr_level, a.completed_at,
                  a.pron_score, a.quiz_score, a.xp_earned
           from lesson_attempts a join lessons l on l.id = a.lesson_id
           where a.user_id = v_uid
           order by a.completed_at desc
           limit 15) r)
  ) into v_result;

  return v_result;
end; $$;

grant execute on function public.complete_lesson(uuid, jsonb, int, timestamptz, int) to authenticated;
grant execute on function public.get_dashboard(int) to authenticated;
revoke execute on function public.complete_lesson(uuid, jsonb, int, timestamptz, int) from anon;
revoke execute on function public.get_dashboard(int) from anon;

-- =========================================================
-- 6. STORAGE para audios nativos (lectura pública)
-- =========================================================
insert into storage.buckets (id, name, public)
values ('lesson-audio', 'lesson-audio', true)
on conflict (id) do nothing;
