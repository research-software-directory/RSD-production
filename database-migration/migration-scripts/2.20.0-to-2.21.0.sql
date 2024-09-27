---------- CREATED BY MIGRA ----------

drop function if exists "public"."person_mentions"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.person_avatars_by_name()
 RETURNS TABLE(display_name text, avatars character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		unique_person_entries.display_name,
		array_agg(DISTINCT(unique_person_entries.avatar_id)) AS avatars
	FROM
		unique_person_entries()
	WHERE
		unique_person_entries.avatar_id IS NOT NULL
	GROUP BY
		unique_person_entries.display_name
	;
$function$
;

CREATE OR REPLACE FUNCTION public.person_avatars_by_orcid()
 RETURNS TABLE(orcid text, avatars character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		unique_person_entries.orcid,
		array_agg(DISTINCT(unique_person_entries.avatar_id)) AS avatars
	FROM
		unique_person_entries()
	WHERE
		unique_person_entries.avatar_id IS NOT NULL AND
		unique_person_entries.orcid IS NOT NULL
	GROUP BY
		unique_person_entries.orcid
	;
$function$
;

CREATE OR REPLACE FUNCTION public.suggested_roles()
 RETURNS character varying[]
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
    ARRAY_AGG("role")
  FROM (
		SELECT
			"role"
		FROM
			contributor
		WHERE
			"role" IS NOT NULL
		UNION
		SELECT
			"role"
		FROM
			team_member
		WHERE
		"role" IS NOT NULL
  ) roles
;
$function$
;

CREATE OR REPLACE FUNCTION public.person_mentions()
 RETURNS TABLE(id uuid, given_names character varying, family_names character varying, email_address character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, origin character varying, slug character varying, public_orcid_profile character varying, avatars_by_name character varying[], avatars_by_orcid character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	contributor.id,
	contributor.given_names,
	contributor.family_names,
	contributor.email_address,
	contributor.affiliation,
	contributor.role,
	contributor.orcid,
	contributor.avatar_id,
	'contributor' AS origin,
	software.slug,
	public_profile.orcid as public_orcid_profile,
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
UNION
SELECT
	team_member.id,
	team_member.given_names,
	team_member.family_names,
	team_member.email_address,
	team_member.affiliation,
	team_member.role,
	team_member.orcid,
	team_member.avatar_id,
	'team_member' AS origin,
	project.slug,
	public_profile.orcid as public_orcid_profile,
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

