---------- CREATED BY MIGRA ----------

drop function if exists "public"."software_search"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.prog_lang_cnt_for_software()
 RETURNS TABLE(prog_lang text, cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		JSONB_OBJECT_KEYS(languages) AS "prog_lang",
		COUNT(software) AS cnt
	FROM
		repository_url
	GROUP BY
		JSONB_OBJECT_KEYS(languages)
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.prog_lang_filter_for_software()
 RETURNS TABLE(software uuid, prog_lang text[])
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		repository_url.software,
		(SELECT
			ARRAY_AGG(p_lang)
		  FROM
		  	JSONB_OBJECT_KEYS(repository_url.languages) p_lang
		) AS "prog_lang"
	FROM
		repository_url
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_search()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[])
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
END
$function$
;

