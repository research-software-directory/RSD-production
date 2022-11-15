---------- CREATED BY MIGRA ----------

drop function if exists "public"."homepage_counts"(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint);

drop function if exists "public"."global_search"();

drop function if exists "public"."keyword_filter_for_project"();

drop function if exists "public"."keyword_filter_for_software"();

drop function if exists "public"."project_search"();

drop function if exists "public"."software_search"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.homepage_counts(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT contributor_cnt bigint, OUT software_mention_cnt bigint)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	SELECT count(id) FROM software INTO software_cnt;
	SELECT count(id) FROM project INTO project_cnt;
	SELECT count(id) FROM organisation WHERE parent IS NULL INTO organisation_cnt;
	SELECT count(display_name) FROM unique_contributors() INTO contributor_cnt;
	SELECT count(mention) FROM mention_for_software INTO software_mention_cnt;
END
$function$
;

CREATE OR REPLACE FUNCTION public.research_domain_count_for_projects()
 RETURNS TABLE(id uuid, key character varying, name character varying, cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		research_domain.id,
		research_domain.key,
		research_domain.name,
		research_domain_count.cnt
	FROM
		research_domain
	LEFT JOIN
		(SELECT
				research_domain_for_project.research_domain,
				count(research_domain_for_project.research_domain) AS cnt
			FROM
				research_domain_for_project
			GROUP BY research_domain_for_project.research_domain
		) AS research_domain_count ON research_domain.id = research_domain_count.research_domain
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.research_domain_filter_for_project()
 RETURNS TABLE(project uuid, research_domain character varying[], research_domain_text text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
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
	GROUP BY research_domain_for_project.project
;
END
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
		software_search.slug,
		software_search.brand_name AS name,
		'software' AS "source",
		software_search.is_published,
		CONCAT_WS(
			' ',
			software_search.brand_name,
			software_search.short_statement,
			software_search.keywords_text
		) AS search_text
	FROM
		software_search()
	UNION
	-- PROJECT search item
	SELECT
		project_search.slug,
		project_search.title AS name,
		'projects' AS "source",
		project_search.is_published,
		CONCAT_WS(
			' ',
			project_search.title,
			project_search.subtitle,
			project_search.keywords_text,
			project_search.research_domain_text
		) AS search_text
	FROM
		project_search()
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

CREATE OR REPLACE FUNCTION public.keyword_filter_for_project()
 RETURNS TABLE(project uuid, keywords citext[], keywords_text text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
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
	GROUP BY keyword_for_project.project
;
END
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_filter_for_software()
 RETURNS TABLE(software uuid, keywords citext[], keywords_text text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
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
	GROUP BY keyword_for_software.software
;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_search()
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id uuid, keywords citext[], keywords_text text, research_domain character varying[], research_domain_text text)
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
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now() THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		image_for_project.project AS image_id,
		keyword_filter_for_project.keywords,
		keyword_filter_for_project.keywords_text,
		research_domain_filter_for_project.research_domain,
		research_domain_filter_for_project.research_domain_text
	FROM
		project
	LEFT JOIN
		image_for_project ON project.id = image_for_project.project
	LEFT JOIN
		keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
	LEFT JOIN
		research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_search()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
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
		keyword_filter_for_software.keywords_text
	FROM
		software
	LEFT JOIN
		count_software_countributors() ON software.id=count_software_countributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	LEFT JOIN
		keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
	;
END
$function$
;
