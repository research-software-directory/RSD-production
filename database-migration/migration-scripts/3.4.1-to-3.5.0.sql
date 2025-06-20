---------- CREATED BY MIGRA ----------

drop function if exists "public"."public_user_profile"();

alter table "public"."package_manager" alter column "package_manager" drop default;

alter type "public"."package_manager_type" rename to "package_manager_type__old_version_to_be_dropped";

create type "public"."package_manager_type" as enum ('anaconda', 'chocolatey', 'cran', 'crates', 'debian', 'dockerhub', 'fourtu', 'ghcr', 'github', 'gitlab', 'golang', 'julia', 'maven', 'npm', 'pixi', 'pypi', 'snapcraft', 'sonatype', 'other');

alter table "public"."package_manager" alter column package_manager type "public"."package_manager_type" using package_manager::text::"public"."package_manager_type";

alter table "public"."package_manager" alter column "package_manager" set default 'other'::package_manager_type;

drop type "public"."package_manager_type__old_version_to_be_dropped";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.public_user_profile()
 RETURNS TABLE(display_name character varying, given_names character varying, family_names character varying, email_address character varying, affiliation character varying, role character varying, avatar_id character varying, orcid character varying, account uuid, is_public boolean, updated_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
SELECT
	(CONCAT(user_profile.given_names,' ',user_profile.family_names)) AS display_name,
	user_profile.given_names,
	user_profile.family_names,
	user_profile.email_address,
	user_profile.affiliation,
	user_profile.role,
	user_profile.avatar_id,
	login_for_account.sub AS orcid,
	user_profile.account,
	user_profile.is_public,
	user_profile.updated_at
FROM
	user_profile
LEFT JOIN
	login_for_account ON
		user_profile.account = login_for_account.account
		AND
		login_for_account.provider = 'orcid'
WHERE
	user_profile.is_public
$function$
;

