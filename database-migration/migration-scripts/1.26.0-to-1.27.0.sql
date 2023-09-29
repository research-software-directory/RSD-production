---------- CREATED BY MIGRA ----------

drop function if exists "public"."homepage_counts"(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT contributor_cnt bigint, OUT software_mention_cnt bigint);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.homepage_counts(OUT software_cnt bigint, OUT open_software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT contributor_cnt bigint, OUT software_mention_cnt bigint)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	SELECT COUNT(id) FROM software INTO software_cnt;
	SELECT COUNT(id) FROM software WHERE NOT closed_source INTO open_software_cnt;
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

CREATE OR REPLACE FUNCTION public.organisations_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, ror_id character varying, website character varying, is_tenant boolean, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, rsd_path character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (organisation.id)
	organisation.id,
	organisation.slug,
	organisation.parent,
	organisation.primary_maintainer,
	organisation.name,
	organisation.ror_id,
	organisation.website,
	organisation.is_tenant,
	organisation.logo_id,
	software_count_by_organisation.software_cnt,
	project_count_by_organisation.project_cnt,
	children_count_by_organisation.children_cnt,
	organisation_route.rsd_path
FROM
	organisation
LEFT JOIN
	software_count_by_organisation() ON software_count_by_organisation.organisation = organisation.id
LEFT JOIN
	project_count_by_organisation() ON project_count_by_organisation.organisation = organisation.id
LEFT JOIN
	children_count_by_organisation() ON children_count_by_organisation.parent = organisation.id
LEFT JOIN
	maintainer_for_organisation ON maintainer_for_organisation.organisation = organisation.id
LEFT JOIN
	organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
WHERE
	maintainer_for_organisation.maintainer = maintainer_id OR organisation.primary_maintainer = maintainer_id;
$function$
;

CREATE OR REPLACE FUNCTION public.software_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, software_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	list_parent_organisations.organisation_id,
	COUNT(DISTINCT software_for_organisation.software) AS software_cnt
FROM
	software_for_organisation
CROSS JOIN list_parent_organisations(software_for_organisation.organisation)
WHERE
		(NOT public)
	OR
		(
			software_for_organisation.status = 'approved'
		AND
			software IN (SELECT id FROM software WHERE is_published)
		)
GROUP BY list_parent_organisations.organisation_id;
$function$
;

