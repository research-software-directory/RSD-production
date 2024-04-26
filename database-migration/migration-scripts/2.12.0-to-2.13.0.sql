---------- CREATED BY MIGRA ----------

alter table "public"."license_for_software" add column "name" character varying(200);

alter table "public"."license_for_software" add column "open_source" boolean not null default true;

alter table "public"."license_for_software" add column "reference" character varying(200);

alter table "public"."license_for_software" add constraint "license_for_software_reference_check" CHECK (((reference)::text ~ '^https?://'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.highlight_keywords_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	highlight_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_languages_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(prog_language text, prog_language_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(prog_lang) AS prog_language,
	COUNT(id) AS prog_language_cnt
FROM
	highlight_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_licenses_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(license character varying, license_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(licenses) AS license,
	COUNT(id) AS license_cnt
FROM
	highlight_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_overview()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], "position" integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_overview.id,
	software_overview.slug,
	software_overview.brand_name,
	software_overview.short_statement,
	software_overview.image_id,
	software_overview.updated_at,
	software_overview.contributor_cnt,
	software_overview.mention_cnt,
	software_overview.is_published,
	software_overview.keywords,
	software_overview.keywords_text,
	software_overview.prog_lang,
	software_overview.licenses,
	software_highlight.position
FROM
	software_overview()
RIGHT JOIN
	software_highlight ON software_overview.id=software_highlight.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, is_published boolean, contributor_cnt bigint, mention_cnt bigint, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], "position" integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_search.id,
	software_search.slug,
	software_search.brand_name,
	software_search.short_statement,
	software_search.image_id,
	software_search.updated_at,
	software_search.is_published,
	software_search.contributor_cnt,
	software_search.mention_cnt,
	software_search.keywords,
	software_search.keywords_text,
	software_search.prog_lang,
	software_search.licenses,
	software_highlight.position
FROM
	software_search(search)
RIGHT JOIN
	software_highlight ON software_search.id=software_highlight.software
;
$function$
;

