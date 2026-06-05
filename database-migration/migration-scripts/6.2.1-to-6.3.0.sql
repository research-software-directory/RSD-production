---------- CREATED BY MIGRA ----------

drop function if exists "public"."person_mentions"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.person_mentions()
 RETURNS TABLE(id uuid, given_names character varying, family_names character varying, display_name character varying, email_address character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, origin character varying, slug character varying, public_orcid_profile character varying, account character varying, avatars_by_name character varying[], avatars_by_orcid character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	contributor.id,
	contributor.given_names,
	contributor.family_names,
	CONCAT(contributor.given_names, ' ', contributor.family_names) AS display_name,
	contributor.email_address,
	contributor.affiliation,
	contributor.role,
	contributor.orcid,
	contributor.avatar_id,
	'contributor' AS origin,
	software.slug,
	public_profile.orcid as public_orcid_profile,
	contributor.account,
	person_avatars_by_name.avatars AS avatars_by_name,
	person_avatars_by_orcid.avatars	AS avatars_by_orcid
FROM
	contributor
INNER JOIN
	software ON contributor.software = software.id
LEFT JOIN
	public_profile() ON public_profile.orcid=contributor.orcid
LEFT JOIN
	person_avatars_by_name() ON person_avatars_by_name.display_name = CONCAT(contributor.given_names,' ',contributor.family_names)
LEFT JOIN
	person_avatars_by_orcid() ON person_avatars_by_orcid.orcid = contributor.orcid
UNION ALL
SELECT
	team_member.id,
	team_member.given_names,
	team_member.family_names,
	CONCAT(team_member.given_names, ' ', team_member.family_names) AS display_name,
	team_member.email_address,
	team_member.affiliation,
	team_member.role,
	team_member.orcid,
	team_member.avatar_id,
	'team_member' AS origin,
	project.slug,
	public_profile.orcid as public_orcid_profile,
	team_member.account,
	person_avatars_by_name.avatars AS avatars_by_name,
	person_avatars_by_orcid.avatars	AS avatars_by_orcid
FROM
	team_member
INNER JOIN
	project ON team_member.project = project.id
LEFT JOIN
	public_profile() ON public_profile.orcid = team_member.orcid
LEFT JOIN
	person_avatars_by_name() ON person_avatars_by_name.display_name = CONCAT(team_member.given_names,' ',	team_member.family_names)
LEFT JOIN
	person_avatars_by_orcid() ON person_avatars_by_orcid.orcid = team_member.orcid
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_contributor()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	IF (CURRENT_USER = 'rsd_admin' OR (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER)) IS DISTINCT FROM TRUE THEN
		NEW.account = OLD.account;
		IF OLD.account IS NOT NULL THEN
			NEW.family_names = OLD.family_names;
			NEW.given_names = OLD.given_names;
			NEW.orcid = OLD.orcid;
		END IF;
	END IF;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_team_member()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	IF (CURRENT_USER = 'rsd_admin' OR (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER)) IS DISTINCT FROM TRUE THEN
		NEW.account = OLD.account;
		IF OLD.account IS NOT NULL THEN
			NEW.family_names = OLD.family_names;
			NEW.given_names = OLD.given_names;
			NEW.orcid = OLD.orcid;
		END IF;
	END IF;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.unique_person_entries()
 RETURNS TABLE(display_name text, given_names character varying, family_names character varying, email_address character varying, affiliation character varying, role character varying, avatar_id character varying, orcid character varying, account uuid)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT
	CONCAT(contributor.given_names, ' ', contributor.family_names) AS display_name,
	contributor.given_names,
	contributor.family_names,
	contributor.email_address,
	contributor.affiliation,
	contributor.role,
	contributor.avatar_id,
	contributor.orcid,
	contributor.account
FROM
	contributor
UNION
SELECT DISTINCT
	CONCAT(team_member.given_names, ' ', team_member.family_names) AS display_name,
	team_member.given_names,
	team_member.family_names,
	team_member.email_address,
	team_member.affiliation,
	team_member.role,
	team_member.avatar_id,
	team_member.orcid,
	team_member.account
FROM
	team_member
ORDER BY
	display_name ASC;
$function$
;

