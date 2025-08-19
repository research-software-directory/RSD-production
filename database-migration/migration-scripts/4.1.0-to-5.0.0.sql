---------- CREATED BY MIGRA ----------

drop trigger if exists "check_meta_pages_before_delete" on "public"."meta_pages";

drop trigger if exists "check_meta_pages_before_insert" on "public"."meta_pages";

drop trigger if exists "check_meta_pages_before_update" on "public"."meta_pages";

drop trigger if exists "sanitise_insert_meta_pages" on "public"."meta_pages";

drop trigger if exists "sanitise_update_meta_pages" on "public"."meta_pages";

drop policy "admin_all_rights" on "public"."meta_pages";

drop policy "anyone_can_read" on "public"."meta_pages";

alter table "public"."meta_pages" drop constraint "meta_pages_slug_check";

alter table "public"."meta_pages" drop constraint "meta_pages_slug_key";

drop function if exists "public"."sanitise_insert_meta_pages"();

drop function if exists "public"."sanitise_update_meta_pages"();

alter table "public"."meta_pages" drop constraint "meta_pages_pkey";

drop index if exists "public"."meta_pages_pkey";

drop index if exists "public"."meta_pages_slug_key";

-- EDITED MANUALLY
ALTER TABLE meta_pages RENAME TO meta_page;
-- END EDITED MANUALLY

alter table "public"."meta_page" enable row level security;

create table "public"."swhid_for_software" (
    "id" uuid not null default gen_random_uuid(),
    "software" uuid not null,
    "swhid" character varying(1000),
    "position" integer not null,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."swhid_for_software" enable row level security;

alter table "public"."remote_software" alter column "brand_name" set data type character varying(250) using "brand_name"::character varying(250);

alter table "public"."remote_software" alter column "slug" set data type character varying(250) using "slug"::character varying(250);

alter table "public"."software_for_community" alter column "requested_at" drop not null;

CREATE UNIQUE INDEX meta_page_pkey ON public.meta_page USING btree (id);

CREATE UNIQUE INDEX meta_page_slug_key ON public.meta_page USING btree (slug);

CREATE UNIQUE INDEX swhid_for_software_pkey ON public.swhid_for_software USING btree (id);

CREATE INDEX swhid_for_software_software_idx ON public.swhid_for_software USING btree (software);

alter table "public"."meta_page" add constraint "meta_page_pkey" PRIMARY KEY using index "meta_page_pkey";

alter table "public"."swhid_for_software" add constraint "swhid_for_software_pkey" PRIMARY KEY using index "swhid_for_software_pkey";

alter table "public"."meta_page" add constraint "meta_page_slug_check" CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text));

alter table "public"."meta_page" add constraint "meta_page_slug_key" UNIQUE using index "meta_page_slug_key";

alter table "public"."swhid_for_software" add constraint "swhid_for_software_software_fkey" FOREIGN KEY (software) REFERENCES software(id);

alter table "public"."swhid_for_software" add constraint "swhid_for_software_swhid_check" CHECK (((swhid)::text ~ '^swh:1:(snp|rel|rev|dir|cnt):[0-9a-f]{40}(;(origin=[^\s;]+|visit=swh:1:(snp|rel|rev|dir|cnt):[0-9a-f]{40}|anchor=swh:1:(snp|rel|rev|dir|cnt):[0-9a-f]{40}|path=[^\s;]+|lines=\d+(-\d+)?))*$'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.sanitise_insert_meta_page()
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

CREATE OR REPLACE FUNCTION public.sanitise_insert_swhid_for_software()
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

CREATE OR REPLACE FUNCTION public.sanitise_update_meta_page()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;

	IF NEW.slug IS DISTINCT FROM OLD.slug AND CURRENT_USER IS DISTINCT FROM 'rsd_admin' AND (
		SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER
	) IS DISTINCT FROM TRUE
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to change the slug';
	END IF;

	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_swhid_for_software()
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

CREATE OR REPLACE FUNCTION public.cleanup_expired_token()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
	deleted_row RECORD;
	rows_deleted INTEGER := 0;
	soon_expiring RECORD;
	soon_expiring_count INTEGER := 0;
BEGIN
	FOR deleted_row IN
		DELETE FROM user_access_token
		WHERE expires_at <= CURRENT_TIMESTAMP
		RETURNING *
	LOOP
		-- Send notification for each deleted row
		PERFORM pg_notify(
			'access_token_deleted_now',
			json_build_object(
				'id', deleted_row.id,
				'account', deleted_row.account,
				'display_name', deleted_row.display_name
			)::text
		);
		rows_deleted := rows_deleted + 1;
	END LOOP;
	RAISE NOTICE 'Deleted % access tokens and sent notifications', rows_deleted;

	FOR soon_expiring IN
		SELECT * FROM user_access_token
		WHERE expires_at::date = CURRENT_DATE + 7
	LOOP
		-- Send notification for each token expiring in 7 days
		PERFORM pg_notify(
			'access_token_expiring_7_days',
			json_build_object(
				'id', soon_expiring.id,
				'account', soon_expiring.account,
				'display_name', soon_expiring.display_name
			)::text
		);
		soon_expiring_count := soon_expiring_count + 1;
	END LOOP;
	RAISE NOTICE '% access tokens expiring in 7 days, sent notifications', soon_expiring_count;

END;
$function$
;

create policy "admin_all_rights"
on "public"."meta_page"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."meta_page"
as permissive
for select
to rsd_web_anon, rsd_user
using (is_published);


create policy "admin_all_rights"
on "public"."swhid_for_software"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."swhid_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "maintainer_all_rights"
on "public"."swhid_for_software"
as permissive
for all
to rsd_user
using ((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))))
with check (software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer)));


CREATE TRIGGER check_meta_page_before_delete BEFORE DELETE ON public.meta_page FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_meta_page_before_insert BEFORE INSERT ON public.meta_page FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_meta_page_before_update BEFORE UPDATE ON public.meta_page FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_meta_page BEFORE INSERT ON public.meta_page FOR EACH ROW EXECUTE FUNCTION sanitise_insert_meta_page();

CREATE TRIGGER sanitise_update_meta_page BEFORE UPDATE ON public.meta_page FOR EACH ROW EXECUTE FUNCTION sanitise_update_meta_page();

CREATE TRIGGER check_swhid_for_software_before_delete BEFORE DELETE ON public.swhid_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_swhid_for_software_before_insert BEFORE INSERT ON public.swhid_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_swhid_for_software_before_update BEFORE UPDATE ON public.swhid_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_swhid_for_software BEFORE INSERT ON public.swhid_for_software FOR EACH ROW EXECUTE FUNCTION sanitise_insert_swhid_for_software();

CREATE TRIGGER sanitise_update_swhid_for_software BEFORE UPDATE ON public.swhid_for_software FOR EACH ROW EXECUTE FUNCTION sanitise_update_swhid_for_software();

