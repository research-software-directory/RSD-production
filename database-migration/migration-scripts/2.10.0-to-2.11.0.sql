---------- CREATED BY MIGRA ----------

create table "public"."image_for_news" (
    "id" uuid not null default gen_random_uuid(),
    "news" uuid not null,
    "image_id" character varying(40) not null,
    "position" character varying(25) default 'card'::character varying,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."image_for_news" enable row level security;

create table "public"."news" (
    "id" uuid not null default gen_random_uuid(),
    "slug" character varying(200) not null,
    "is_published" boolean not null default false,
    "publication_date" date not null,
    "title" character varying(200) not null,
    "author" character varying(200),
    "summary" character varying(300),
    "description" character varying(10000),
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."news" enable row level security;

CREATE UNIQUE INDEX image_for_news_pkey ON public.image_for_news USING btree (id);

CREATE UNIQUE INDEX news_pkey ON public.news USING btree (id);

CREATE UNIQUE INDEX unique_news_image ON public.image_for_news USING btree (news, image_id);

CREATE UNIQUE INDEX unique_news_item ON public.news USING btree (slug, publication_date);

alter table "public"."image_for_news" add constraint "image_for_news_pkey" PRIMARY KEY using index "image_for_news_pkey";

alter table "public"."news" add constraint "news_pkey" PRIMARY KEY using index "news_pkey";

alter table "public"."image_for_news" add constraint "image_for_news_image_id_fkey" FOREIGN KEY (image_id) REFERENCES image(id);

alter table "public"."image_for_news" add constraint "image_for_news_news_fkey" FOREIGN KEY (news) REFERENCES news(id);

alter table "public"."news" add constraint "news_slug_check" CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.sanitise_insert_image_for_news()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_news()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_image_for_news()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_news()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;

	IF NEW.slug IS DISTINCT FROM OLD.slug AND CURRENT_USER IS DISTINCT FROM 'rsd_admin' AND (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) IS DISTINCT FROM TRUE THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to change the slug';
	END IF;
	return NEW;
END
$function$
;

create policy "admin_all_rights"
on "public"."image_for_news"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."image_for_news"
as permissive
for select
to rsd_web_anon, rsd_user
using ((news IN ( SELECT news.id
   FROM news)));


create policy "admin_all_rights"
on "public"."news"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read_published"
on "public"."news"
as permissive
for select
to rsd_web_anon, rsd_user
using (is_published);


CREATE TRIGGER sanitise_insert_image_for_news BEFORE INSERT ON public.image_for_news FOR EACH ROW EXECUTE FUNCTION sanitise_insert_image_for_news();

CREATE TRIGGER sanitise_update_image_for_news BEFORE UPDATE ON public.image_for_news FOR EACH ROW EXECUTE FUNCTION sanitise_update_image_for_news();

CREATE TRIGGER sanitise_insert_news BEFORE INSERT ON public.news FOR EACH ROW EXECUTE FUNCTION sanitise_insert_news();

CREATE TRIGGER sanitise_update_news BEFORE UPDATE ON public.news FOR EACH ROW EXECUTE FUNCTION sanitise_update_news();

