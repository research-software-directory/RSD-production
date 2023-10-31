---------- CREATED BY MIGRA ----------

drop trigger if exists "check_oaipmh_before_delete" on "public"."oaipmh";

drop trigger if exists "check_oaipmh_before_insert" on "public"."oaipmh";

drop trigger if exists "check_oaipmh_before_update" on "public"."oaipmh";

drop trigger if exists "sanitise_insert_oaipmh" on "public"."oaipmh";

drop trigger if exists "sanitise_update_oaipmh" on "public"."oaipmh";

drop policy "admin_all_rights" on "public"."oaipmh";

drop policy "anyone_can_read" on "public"."oaipmh";

alter table "public"."oaipmh" drop constraint "oaipmh_id_check";

drop function if exists "public"."sanitise_insert_oaipmh"();

drop function if exists "public"."sanitise_update_oaipmh"();

alter table "public"."oaipmh" drop constraint "oaipmh_pkey";

drop index if exists "public"."oaipmh_pkey";

drop table "public"."oaipmh";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.z_delete_old_releases()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.concept_doi IS DISTINCT FROM OLD.concept_doi THEN
		DELETE FROM release_version WHERE release_version.release_id = OLD.id;
		DELETE FROM release WHERE release.software = OLD.id;
	END IF;
	RETURN NEW;
END
$function$
;

CREATE TRIGGER z_delete_old_releases BEFORE UPDATE ON public.software FOR EACH ROW EXECUTE FUNCTION z_delete_old_releases();

