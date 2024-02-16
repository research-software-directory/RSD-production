---------- CREATED BY MIGRA ----------

drop function if exists "public"."global_search"();

set check_function_bodies = off;

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
		organisation.slug ILIKE CONCAT('%', query, '%') OR organisation."name" ILIKE CONCAT('%', query, '%')
;
$function$
;

