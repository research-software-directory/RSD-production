---------- CREATED BY MIGRA ----------

drop function if exists "public"."slug_from_log_reference"(table_name character varying, reference_id uuid);

alter table "public"."package_manager" alter column "package_manager" drop default;

alter type "public"."package_manager_type" rename to "package_manager_type__old_version_to_be_dropped";

create type "public"."package_manager_type" as enum ('anaconda', 'chocolatey', 'cran', 'crates', 'debian', 'dockerhub', 'github', 'gitlab', 'golang', 'maven', 'npm', 'pypi', 'snapcraft', 'sonatype', 'other');

alter table "public"."package_manager" alter column package_manager type "public"."package_manager_type" using package_manager::text::"public"."package_manager_type";

alter table "public"."package_manager" alter column "package_manager" set default 'other'::package_manager_type;

drop type "public"."package_manager_type__old_version_to_be_dropped";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.sanitise_update_account()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	IF NEW.agree_terms != OLD.agree_terms THEN
		NEW.agree_terms_updated_at = NEW.updated_at;
	ELSE
		NEW.agree_terms_updated_at = OLD.agree_terms_updated_at;
	END IF;
	IF NEW.notice_privacy_statement != OLD.notice_privacy_statement THEN
		NEW.notice_privacy_statement_updated_at = NEW.updated_at;
	ELSE
		NEW.notice_privacy_statement_updated_at = OLD.notice_privacy_statement_updated_at;
	END IF;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.slug_from_log_reference(table_name character varying, reference_id uuid)
 RETURNS character varying
 LANGUAGE sql
 STABLE
AS $function$
SELECT CASE
	WHEN table_name = 'repository_url' THEN (
		SELECT
			CONCAT('/software/', slug, '/edit/information')
		FROM
			software WHERE id = reference_id
	)
	WHEN table_name = 'package_manager' THEN (
		SELECT
			CONCAT('/software/', slug, '/edit/package-managers')
		FROM
			software
		WHERE id = (SELECT software FROM package_manager WHERE id = reference_id))
	WHEN table_name = 'mention' AND reference_id IS NOT NULL THEN (
		SELECT
			CONCAT('/api/v1/mention?id=eq.', reference_id)
	)
	END
$function$
;

CREATE OR REPLACE FUNCTION public.user_agreements_stored(account_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN (
		SELECT (
			account.agree_terms AND
			account.notice_privacy_statement
		)
		FROM
			account
		WHERE
			account.id = account_id
	);
END
$function$
;

