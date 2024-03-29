---------- CREATED BY MIGRA ----------

alter table "public"."repository_url" add column "scraping_disabled_reason" character varying(200);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.count_software_contributors()
 RETURNS TABLE(software uuid, contributor_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
		contributor.software, COUNT(contributor.id) AS contributor_cnt
	FROM
		contributor
	GROUP BY
		contributor.software;
$function$
;

CREATE OR REPLACE FUNCTION public.count_software_mentions()
 RETURNS TABLE(software uuid, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		mentions_by_software.software, COUNT(mentions_by_software.id) AS mention_cnt
	FROM
		mentions_by_software()
	GROUP BY
		mentions_by_software.software;
$function$
;

CREATE OR REPLACE FUNCTION public.global_search(query character varying)
 RETURNS TABLE(slug character varying, name character varying, source text, is_published boolean, rank integer, index_found integer)
 LANGUAGE sql
 STABLE
AS $function$
	-- SOFTWARE search item
	SELECT
		software.slug,
		software.brand_name AS name,
		'software' AS "source",
		software.is_published,
		(CASE
			WHEN software.slug ILIKE query OR software.brand_name ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 1
			WHEN software.slug ILIKE CONCAT(query, '%') OR software.brand_name ILIKE CONCAT(query, '%') THEN 2
			WHEN software.slug ILIKE CONCAT('%', query, '%') OR software.brand_name ILIKE CONCAT('%', query, '%') THEN 3
			ELSE 4
		END) AS rank,
		(CASE
			WHEN software.slug ILIKE query OR software.brand_name ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 0
			WHEN software.slug ILIKE CONCAT(query, '%') OR software.brand_name ILIKE CONCAT(query, '%') THEN 0
			WHEN software.slug ILIKE CONCAT('%', query, '%') OR software.brand_name ILIKE CONCAT('%', query, '%') THEN LEAST(POSITION(query IN software.slug), POSITION(query IN software.brand_name))
			ELSE 0
		END) AS index_found
	FROM
		software
	LEFT JOIN keyword_for_software ON keyword_for_software.software = software.id
	LEFT JOIN keyword ON keyword.id = keyword_for_software.keyword
	GROUP BY software.id
	HAVING
		software.slug ILIKE CONCAT('%', query, '%')
		OR
		software.brand_name ILIKE CONCAT('%', query, '%')
		OR
		software.short_statement ILIKE CONCAT('%', query, '%')
		OR
		BOOL_OR(keyword.value ILIKE CONCAT('%', query, '%'))
	UNION
	-- PROJECT search item
	SELECT
		project.slug,
		project.title AS name,
		'projects' AS "source",
		project.is_published,
		(CASE
			WHEN project.slug ILIKE query OR project.title ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 1
			WHEN project.slug ILIKE CONCAT(query, '%') OR project.title ILIKE CONCAT(query, '%') THEN 2
			WHEN project.slug ILIKE CONCAT('%', query, '%') OR project.title ILIKE CONCAT('%', query, '%') THEN 3
			ELSE 4
		END) AS rank,
		(CASE
			WHEN project.slug ILIKE query OR project.title ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 0
			WHEN project.slug ILIKE CONCAT(query, '%') OR project.title ILIKE CONCAT(query, '%') THEN 0
			WHEN project.slug ILIKE CONCAT('%', query, '%') OR project.title ILIKE CONCAT('%', query, '%') THEN LEAST(POSITION(query IN project.slug), POSITION(query IN project.title))
			ELSE 0
		END) AS index_found
	FROM
		project
	LEFT JOIN keyword_for_project ON keyword_for_project.project = project.id
	LEFT JOIN keyword ON keyword.id = keyword_for_project.keyword
	GROUP BY project.id
	HAVING
		project.slug ILIKE CONCAT('%', query, '%')
		OR
		project.title ILIKE CONCAT('%', query, '%')
		OR
		project.subtitle ILIKE CONCAT('%', query, '%')
		OR
		BOOL_OR(keyword.value ILIKE CONCAT('%', query, '%'))
	UNION
	-- ORGANISATION search item
	SELECT
		organisation.slug,
		organisation."name",
		'organisations' AS "source",
		TRUE AS is_published,
		(CASE
			WHEN organisation.slug ILIKE query OR organisation."name" ILIKE query THEN 0
			WHEN organisation.slug ILIKE CONCAT(query, '%') OR organisation."name" ILIKE CONCAT(query, '%') THEN 2
			ELSE 3
		END) AS rank,
		(CASE
			WHEN organisation.slug ILIKE query OR organisation."name" ILIKE query THEN 0
			WHEN organisation.slug ILIKE CONCAT(query, '%') OR organisation."name" ILIKE CONCAT(query, '%') THEN 0
			ELSE LEAST(POSITION(query IN organisation.slug), POSITION(query IN organisation."name"))
		END) AS index_found
	FROM
		organisation
	WHERE
	-- ONLY TOP LEVEL ORGANISATIONS
		organisation.parent IS NULL
		AND
		(organisation.slug ILIKE CONCAT('%', query, '%') OR organisation."name" ILIKE CONCAT('%', query, '%'))
;
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_count_for_projects()
 RETURNS TABLE(id uuid, keyword citext, cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_count.cnt
	FROM
		keyword
	LEFT JOIN
		(SELECT
				keyword_for_project.keyword,
				COUNT(keyword_for_project.keyword) AS cnt
			FROM
				keyword_for_project
			GROUP BY keyword_for_project.keyword
		) AS keyword_count ON keyword.id = keyword_count.keyword;
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_count_for_software()
 RETURNS TABLE(id uuid, keyword citext, cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_count.cnt
	FROM
		keyword
	LEFT JOIN
		(SELECT
				keyword_for_software.keyword,
				COUNT(keyword_for_software.keyword) AS cnt
			FROM
				keyword_for_software
			GROUP BY keyword_for_software.keyword
		) AS keyword_count ON keyword.id = keyword_count.keyword;
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_filter_for_project()
 RETURNS TABLE(project uuid, keywords citext[], keywords_text text)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword_for_project.project AS project,
		ARRAY_AGG(
			keyword.value
			ORDER BY value
		) AS keywords,
		STRING_AGG(
			keyword.value,' '
			ORDER BY value
		) AS keywords_text
	FROM
		keyword_for_project
	INNER JOIN
		keyword ON keyword.id = keyword_for_project.keyword
	GROUP BY keyword_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_filter_for_software()
 RETURNS TABLE(software uuid, keywords citext[], keywords_text text)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword_for_software.software AS software,
		ARRAY_AGG(
			keyword.value
			ORDER BY value
		) AS keywords,
		STRING_AGG(
			keyword.value,' '
			ORDER BY value
		) AS keywords_text
	FROM
		keyword_for_software
	INNER JOIN
		keyword ON keyword.id = keyword_for_software.keyword
	GROUP BY keyword_for_software.software;
$function$
;

CREATE OR REPLACE FUNCTION public.keywords_by_project()
 RETURNS TABLE(id uuid, keyword citext, project uuid)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_for_project.project
	FROM
		keyword_for_project
	INNER JOIN
		keyword ON keyword.id = keyword_for_project.keyword;
$function$
;

CREATE OR REPLACE FUNCTION public.keywords_by_software()
 RETURNS TABLE(id uuid, keyword citext, software uuid)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_for_software.software
	FROM
		keyword_for_software
	INNER JOIN
		keyword ON keyword.id = keyword_for_software.keyword;
$function$
;

CREATE OR REPLACE FUNCTION public.maintainer_for_project_by_slug()
 RETURNS TABLE(maintainer uuid, project uuid, slug character varying)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		maintainer_for_project.maintainer,
		maintainer_for_project.project,
		project.slug
	FROM
		maintainer_for_project
	LEFT JOIN
		project ON project.id = maintainer_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.maintainer_for_software_by_slug()
 RETURNS TABLE(maintainer uuid, software uuid, slug character varying)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		maintainer_for_software.maintainer, maintainer_for_software.software, software.slug
	FROM
		maintainer_for_software
	LEFT JOIN
		software ON software.id = maintainer_for_software.software;
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_of_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id character varying, status relation_status, role organisation_role, "position" integer, project uuid, parent uuid)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
			organisation.id AS id,
			organisation.slug,
			organisation.primary_maintainer,
			organisation.name,
			organisation.ror_id,
			organisation.is_tenant,
			organisation.website,
			organisation_route.rsd_path,
			organisation.logo_id,
			project_for_organisation.status,
			project_for_organisation.role,
			project_for_organisation.position,
			project.id AS project,
			organisation.parent
	FROM
		project
	INNER JOIN
		project_for_organisation ON project.id = project_for_organisation.project
	INNER JOIN
		organisation ON project_for_organisation.organisation = organisation.id
	LEFT JOIN
		organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
	WHERE
		project.id = project_id;
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_of_software(software_id uuid)
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id character varying, status relation_status, "position" integer, software uuid)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		organisation.id AS id,
		organisation.slug,
		organisation.primary_maintainer,
		organisation.name,
		organisation.ror_id,
		organisation.is_tenant,
		organisation.website,
		organisation_route.rsd_path,
		organisation.logo_id,
		software_for_organisation.status,
		software_for_organisation.position,
		software.id AS software
	FROM
		software
	INNER JOIN
		software_for_organisation ON software.id = software_for_organisation.software
	INNER JOIN
		organisation ON software_for_organisation.organisation = organisation.id
	LEFT JOIN
		organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
	WHERE
		software.id = software_id;
$function$
;

CREATE OR REPLACE FUNCTION public.prog_lang_filter_for_software()
 RETURNS TABLE(software uuid, prog_lang text[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		repository_url.software,
		(SELECT
			ARRAY_AGG(p_lang ORDER BY repository_url.languages -> p_lang DESC)
		FROM
			JSONB_OBJECT_KEYS(repository_url.languages) p_lang
		) AS "prog_lang"
	FROM
		repository_url;
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		project_status.status AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id
	FROM
		project
	INNER JOIN
		maintainer_for_project ON project.id = maintainer_for_project.project
	LEFT JOIN
		project_status() ON project.id=project_status.project
	WHERE
		maintainer_for_project.maintainer = maintainer_id;
$function$
;

CREATE OR REPLACE FUNCTION public.related_projects_for_software(software_id uuid)
 RETURNS TABLE(software uuid, id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, status relation_status, image_id character varying)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		software_for_project.software,
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		project_status.status AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		software_for_project.status,
		project.image_id
	FROM
		project
	INNER JOIN
		software_for_project ON project.id = software_for_project.project
	LEFT JOIN
		project_status() ON project.id=project_status.project
	WHERE
		software_for_project.software = software_id;
$function$
;

CREATE OR REPLACE FUNCTION public.related_software_for_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, status relation_status)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.updated_at,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt,
		software.is_published,
		software_for_project.status
	FROM
		software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	INNER JOIN
		software_for_project ON software.id=software_for_project.software
	WHERE
		software_for_project.project=project_id;
$function$
;

CREATE OR REPLACE FUNCTION public.related_software_for_software(software_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.updated_at,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt,
		software.is_published
	FROM
		software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	INNER JOIN
		software_for_software ON software.id=software_for_software.relation
	WHERE
		software_for_software.origin = software_id;
$function$
;

CREATE OR REPLACE FUNCTION public.release_cnt_by_year(organisation_id uuid)
 RETURNS TABLE(release_year smallint, release_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		releases_by_organisation.release_year,
		COUNT(releases_by_organisation.*) AS release_cnt
	FROM
		releases_by_organisation()
	WHERE
		releases_by_organisation.organisation_id = release_cnt_by_year.organisation_id
	GROUP BY
		releases_by_organisation.release_year;
$function$
;

CREATE OR REPLACE FUNCTION public.research_domain_by_project()
 RETURNS TABLE(id uuid, key character varying, name character varying, description character varying, project uuid)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		research_domain.id,
		research_domain.key,
		research_domain.name,
		research_domain.description,
		research_domain_for_project.project
	FROM
		research_domain_for_project
	INNER JOIN
		research_domain ON research_domain.id=research_domain_for_project.research_domain;
$function$
;

CREATE OR REPLACE FUNCTION public.research_domain_filter_for_project()
 RETURNS TABLE(project uuid, research_domain character varying[], research_domain_text text)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		research_domain_for_project.project AS project,
		ARRAY_AGG(
			research_domain.key
			ORDER BY key
		) AS research_domain,
		STRING_AGG(
			research_domain.key || ' ' || research_domain."name",' '
			ORDER BY key
		) AS research_domain_text
	FROM
		research_domain_for_project
	INNER JOIN
		research_domain ON research_domain.id = research_domain_for_project.research_domain
	GROUP BY research_domain_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, is_published boolean, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.is_published,
		software.updated_at,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt
	FROM
		software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	INNER JOIN
		maintainer_for_software ON software.id=maintainer_for_software.software
	WHERE
		maintainer_for_software.maintainer=maintainer_id;
$function$
;

CREATE OR REPLACE FUNCTION public.user_agreements_stored(account_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
	SELECT (
		account.agree_terms AND
		account.notice_privacy_statement
	)
	FROM
		account
	WHERE
		account.id = account_id;
$function$
;

