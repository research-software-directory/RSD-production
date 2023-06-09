---------- CREATED BY MIGRA ----------

set check_function_bodies = off;

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
	WHERE
	-- ONLY TOP LEVEL ORGANISATIONS
		organisation.parent IS NULL
;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisation_route(id uuid)
 RETURNS TABLE(organisation uuid, rsd_path character varying, parent_names character varying)
 LANGUAGE sql
 STABLE
AS $function$
WITH RECURSIVE search_tree(slug, name, organisation_id, parent, reverse_depth) AS (
		SELECT o.slug, o.name, o.id, o.parent, 1
		FROM organisation o WHERE o.id = organisation_route.id
	UNION ALL
		SELECT o.slug, o.name, o.id, o.parent, st.reverse_depth + 1
		FROM organisation o, search_tree st
		WHERE o.id = st.parent
)
SELECT organisation_route.id, STRING_AGG(slug, '/' ORDER BY reverse_depth DESC), STRING_AGG(name, ' > ' ORDER BY reverse_depth DESC) FROM search_tree;
$function$
;

