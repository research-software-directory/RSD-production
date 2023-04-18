---------- CREATED BY MIGRA ----------

drop policy "maintainer_all_rights" on "public"."login_for_account";

drop policy "maintainer_delete" on "public"."project_for_project";

drop policy "maintainer_insert" on "public"."project_for_project";

drop policy "maintainer_update" on "public"."project_for_project";

drop function if exists "public"."project_search"();

drop function if exists "public"."related_projects_for_project"(origin_id uuid);

drop function if exists "public"."software_search"();

drop function if exists "public"."project_quality"(show_all boolean);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.count_project_related_projects()
 RETURNS TABLE(project uuid, project_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	id,
	COUNT(DISTINCT relations)
FROM
(
	SELECT
		project_for_project.origin AS id,
		UNNEST(ARRAY_AGG(project_for_project.relation)) AS relations
	FROM
		project_for_project
	WHERE
		project_for_project.status = 'approved'
	GROUP BY
		project_for_project.origin
	UNION ALL
	SELECT
		project_for_project.relation AS id,
		UNNEST(ARRAY_AGG(project_for_project.origin)) AS relations
	FROM
		project_for_project
	WHERE
		project_for_project.status = 'approved'
	GROUP BY
		project_for_project.relation
) AS cnts
GROUP BY id;
$function$
;

CREATE OR REPLACE FUNCTION public.count_project_related_software()
 RETURNS TABLE(project uuid, software_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_for_project.project,
	COUNT(software_for_project.software)
FROM
	software_for_project
WHERE
	software_for_project.status = 'approved'
GROUP BY
	software_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.project_overview()
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], keywords_text text, research_domain character varying[], research_domain_text text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		CASE
			WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
			WHEN project.date_start > now() THEN 'Starting'::VARCHAR
			WHEN project.date_end < now() THEN 'Finished'::VARCHAR
			ELSE 'Running'::VARCHAR
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id,
		keyword_filter_for_project.keywords,
		keyword_filter_for_project.keywords_text,
		research_domain_filter_for_project.research_domain,
		research_domain_filter_for_project.research_domain_text
	FROM
		project
	LEFT JOIN
		keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
	LEFT JOIN
		research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], keywords_text text, research_domain character varying[], research_domain_text text)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	CASE
		WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
		WHEN project.date_start > now() THEN 'Starting'::VARCHAR
		WHEN project.date_end < now() THEN 'Finished'::VARCHAR
		ELSE 'Running'::VARCHAR
	END AS current_state,
	project.date_start,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	keyword_filter_for_project.keywords,
	keyword_filter_for_project.keywords_text,
	research_domain_filter_for_project.research_domain,
	research_domain_filter_for_project.research_domain_text
FROM
	project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
WHERE
	project.title ILIKE CONCAT('%', search, '%')
	OR
	project.slug ILIKE CONCAT('%', search, '%')
	OR
	project.subtitle ILIKE CONCAT('%', search, '%')
	OR
	keyword_filter_for_project.keywords_text ILIKE CONCAT('%', search, '%')
	OR
	research_domain_filter_for_project.research_domain_text ILIKE CONCAT('%', search, '%')
ORDER BY
	CASE
		WHEN title ILIKE search THEN 0
		WHEN title ILIKE CONCAT(search, '%') THEN 1
		WHEN title ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN subtitle ILIKE search THEN 0
		WHEN subtitle ILIKE CONCAT(search, '%') THEN 1
		WHEN subtitle ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.related_projects_for_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, status relation_status, origin uuid, relation uuid)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (project.id)
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	CASE
		WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
		WHEN project.date_start > now() THEN 'Starting'::VARCHAR
		WHEN project.date_end < now() THEN 'Finished'::VARCHAR
		ELSE 'Running'::VARCHAR
	END AS current_state,
	project.date_start,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	project_for_project.status,
	project_for_project.origin,
	project_for_project.relation
FROM
	project
INNER JOIN
	project_for_project ON
		(project.id = project_for_project.relation AND project_for_project.origin = project_id)
		OR
		(project.id = project_for_project.origin AND project_for_project.relation = project_id)
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_overview()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.updated_at,
	count_software_countributors.contributor_cnt,
	count_software_mentions.mention_cnt,
	software.is_published,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang
FROM
	software
LEFT JOIN
	count_software_countributors() ON software.id=count_software_countributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.updated_at,
	count_software_countributors.contributor_cnt,
	count_software_mentions.mention_cnt,
	software.is_published,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang
FROM
	software
LEFT JOIN
	count_software_countributors() ON software.id=count_software_countributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
WHERE
	software.brand_name ILIKE CONCAT('%', search, '%')
	OR
	software.slug ILIKE CONCAT('%', search, '%')
	OR
	software.short_statement ILIKE CONCAT('%', search, '%')
	OR
	keyword_filter_for_software.keywords_text ILIKE CONCAT('%', search, '%')
ORDER BY
	CASE
		WHEN brand_name ILIKE search THEN 0
		WHEN brand_name ILIKE CONCAT(search, '%') THEN 1
		WHEN brand_name ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN short_statement ILIKE search THEN 0
		WHEN short_statement ILIKE CONCAT(search, '%') THEN 1
		WHEN short_statement ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.global_search()
 RETURNS TABLE(slug character varying, name character varying, source text, is_published boolean, search_text text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	-- SOFTWARE search item
	SELECT
		software_overview.slug,
		software_overview.brand_name AS name,
		'software' AS "source",
		software_overview.is_published,
		CONCAT_WS(
			' ',
			software_overview.brand_name,
			software_overview.short_statement,
			software_overview.keywords_text
		) AS search_text
	FROM
		software_overview()
	UNION
	-- PROJECT search item
	SELECT
		project_overview.slug,
		project_overview.title AS name,
		'projects' AS "source",
		project_overview.is_published,
		CONCAT_WS(
			' ',
			project_overview.title,
			project_overview.subtitle,
			project_overview.keywords_text,
			project_overview.research_domain_text
		) AS search_text
	FROM
		project_overview()
	UNION
	-- ORGANISATION search item
	SELECT
		organisation.slug,
		organisation."name",
		'organisations' AS "source",
		TRUE AS is_published,
		CONCAT_WS(
			' ',
			organisation."name",
			organisation.website
		) AS search_text
	FROM
		organisation
;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_quality(show_all boolean DEFAULT false)
 RETURNS TABLE(slug character varying, title character varying, has_subtitle boolean, is_published boolean, date_start date, date_end date, grant_id character varying, has_image boolean, team_member_cnt integer, has_contact_person boolean, participating_org_cnt integer, funding_org_cnt integer, software_cnt integer, project_cnt integer, keyword_cnt integer, research_domain_cnt integer, impact_cnt integer, output_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.slug,
	project.title,
	project.subtitle IS NOT NULL,
	project.is_published,
	project.date_start,
	project.date_end,
	project.grant_id,
	project.image_id IS NOT NULL,
	COALESCE(count_project_team_members.team_member_cnt, 0),
	COALESCE(count_project_team_members.has_contact_person, FALSE),
	COALESCE(count_project_organisations.participating_org_cnt, 0),
	COALESCE(count_project_organisations.funding_org_cnt, 0),
	COALESCE(count_project_related_software.software_cnt, 0),
	COALESCE(count_project_related_projects.project_cnt, 0),
	COALESCE(count_project_keywords.keyword_cnt, 0),
	COALESCE(count_project_research_domains.research_domain_cnt, 0),
	COALESCE(count_project_impact.impact_cnt, 0),
	COALESCE(count_project_output.output_cnt, 0)
FROM
	project
LEFT JOIN
	count_project_team_members() ON project.id = count_project_team_members.project
LEFT JOIN
	count_project_organisations() ON project.id = count_project_organisations.project
LEFT JOIN
	count_project_related_software() ON project.id = count_project_related_software.project
LEFT JOIN
	count_project_related_projects() ON project.id = count_project_related_projects.project
LEFT JOIN
	count_project_keywords() ON project.id = count_project_keywords.project
LEFT JOIN
	count_project_research_domains() ON project.id = count_project_research_domains.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
WHERE
	CASE WHEN show_all IS TRUE THEN TRUE ELSE project.id IN (SELECT * FROM projects_of_current_maintainer()) END;
$function$
;

create policy "maintainer_delete"
on "public"."login_for_account"
as permissive
for delete
to rsd_user
using ((account IN ( SELECT account.id
   FROM account)));


create policy "maintainer_select"
on "public"."login_for_account"
as permissive
for select
to rsd_user
using ((account IN ( SELECT account.id
   FROM account)));


create policy "maintainer_delete"
on "public"."project_for_project"
as permissive
for delete
to rsd_user
using (((status = 'approved'::relation_status) AND ((origin IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))) OR (relation IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))))));


create policy "maintainer_insert"
on "public"."project_for_project"
as permissive
for insert
to rsd_user
with check ((status = 'approved'::relation_status) AND ((origin IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))) OR (relation IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer)))));


create policy "maintainer_update"
on "public"."project_for_project"
as permissive
for update
to rsd_user
using (((origin IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))) OR (relation IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer)))));
