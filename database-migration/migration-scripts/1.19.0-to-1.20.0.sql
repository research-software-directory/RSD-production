---------- CREATED BY MIGRA ----------

drop function if exists "public"."unique_contributors"();

drop function if exists "public"."unique_persons"();

drop function if exists "public"."unique_team_members"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.person_mentions()
 RETURNS TABLE(id uuid, given_names character varying, family_names character varying, email_address character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, origin character varying, slug character varying)
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
	software.slug
FROM
	contributor
INNER JOIN
	software ON contributor.software = software.id
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
	project.slug
FROM
	team_member
INNER JOIN
	project ON team_member.project = project.id
$function$
;

CREATE OR REPLACE FUNCTION public.unique_person_entries()
 RETURNS TABLE(display_name text, affiliation character varying, orcid character varying, given_names character varying, family_names character varying, email_address character varying, role character varying, avatar_id character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT
	(CONCAT(contributor.given_names,' ',contributor.family_names)) AS display_name,
	contributor.affiliation,
	contributor.orcid,
	contributor.given_names,
	contributor.family_names,
	contributor.email_address,
	contributor.role,
	contributor.avatar_id
FROM
	contributor
UNION
SELECT DISTINCT
	(CONCAT(team_member.given_names,' ',team_member.family_names)) AS display_name,
	team_member.affiliation,
	team_member.orcid,
	team_member.given_names,
	team_member.family_names,
	team_member.email_address,
	team_member.role,
	team_member.avatar_id
FROM
	team_member
ORDER BY
	display_name ASC;
$function$
;

CREATE OR REPLACE FUNCTION public.homepage_counts(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT contributor_cnt bigint, OUT software_mention_cnt bigint)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	SELECT COUNT(id) FROM software INTO software_cnt;
	SELECT COUNT(id) FROM project INTO project_cnt;
	SELECT
		COUNT(id) AS organisation_cnt
	FROM
		organisations_overview(TRUE)
	WHERE
		organisations_overview.parent IS NULL AND organisations_overview.score>0
	INTO organisation_cnt;
	SELECT COUNT(DISTINCT(orcid,given_names,family_names)) FROM contributor INTO contributor_cnt;
	SELECT COUNT(mention) FROM mention_for_software INTO software_mention_cnt;
END
$function$
;

