---------- CREATED BY MIGRA ----------

create table "public"."badge" (
    "id" uuid not null default gen_random_uuid(),
    "software" uuid not null,
    "badge_url" character varying(200) not null,
    "alt_text" character varying(100),
    "link_url" character varying(200),
    "position" integer not null,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."badge" enable row level security;

CREATE UNIQUE INDEX badge_pkey ON public.badge USING btree (id);

CREATE UNIQUE INDEX badge_software_badge_url_key ON public.badge USING btree (software, badge_url);

alter table "public"."badge" add constraint "badge_pkey" PRIMARY KEY using index "badge_pkey";

alter table "public"."badge" add constraint "badge_badge_url_check" CHECK (((badge_url)::text ~ '^https?://\S+$'::text));

alter table "public"."badge" add constraint "badge_link_url_check" CHECK (((link_url)::text ~ '^https?://\S+$'::text));

alter table "public"."badge" add constraint "badge_software_badge_url_key" UNIQUE using index "badge_software_badge_url_key";

alter table "public"."badge" add constraint "badge_software_fkey" FOREIGN KEY (software) REFERENCES software(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.sanitise_insert_badge()
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

CREATE OR REPLACE FUNCTION public.sanitise_update_badge()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.delete_software(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the software to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this software';
	END IF;

	DELETE FROM badge WHERE badge.software = delete_software.id;
	DELETE FROM category_for_software WHERE category_for_software.software_id = delete_software.id;
	DELETE FROM contributor WHERE contributor.software = delete_software.id;
	DELETE FROM invite_maintainer_for_software WHERE invite_maintainer_for_software.software = delete_software.id;
	DELETE FROM keyword_for_software WHERE keyword_for_software.software = delete_software.id;
	DELETE FROM license_for_software WHERE license_for_software.software = delete_software.id;
	DELETE FROM maintainer_for_software WHERE maintainer_for_software.software = delete_software.id;
	DELETE FROM mention_for_software WHERE mention_for_software.software = delete_software.id;
	DELETE FROM package_manager WHERE package_manager.software = delete_software.id;
	DELETE FROM reference_paper_for_software WHERE reference_paper_for_software.software = delete_software.id;
	DELETE FROM release_version WHERE release_version.release_id = delete_software.id;
	DELETE FROM release WHERE release.software = delete_software.id;
	DELETE FROM repository_url_for_software WHERE repository_url_for_software.software = delete_software.id;
	DELETE FROM software_for_community WHERE software_for_community.software = delete_software.id;
	DELETE FROM software_for_organisation WHERE software_for_organisation.software = delete_software.id;
	DELETE FROM software_for_project WHERE software_for_project.software = delete_software.id;
	DELETE FROM software_for_software WHERE software_for_software.origin = delete_software.id OR software_for_software.relation = delete_software.id;
	DELETE FROM software_highlight WHERE software_highlight.software = delete_software.id;
	DELETE FROM testimonial WHERE testimonial.software = delete_software.id;

	DELETE FROM software WHERE software.id = delete_software.id;
END
$function$
;

create policy "admin_all_rights"
on "public"."badge"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."badge"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "maintainer_all_rights"
on "public"."badge"
as permissive
for all
to rsd_user
using ((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))))
with check (software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer)));


CREATE TRIGGER check_badge_before_delete BEFORE DELETE ON public.badge FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_badge_before_insert BEFORE INSERT ON public.badge FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_badge_before_update BEFORE UPDATE ON public.badge FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_badge BEFORE INSERT ON public.badge FOR EACH ROW EXECUTE FUNCTION sanitise_insert_badge();

CREATE TRIGGER sanitise_update_badge BEFORE UPDATE ON public.badge FOR EACH ROW EXECUTE FUNCTION sanitise_update_badge();

