---------- CREATED BY MIGRA ----------

drop function if exists "public"."count_software_contributors_mentions"();

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.mentions_by_software()
 RETURNS TABLE(software uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying)
 LANGUAGE sql
 STABLE
AS $function$
-- mentions for software
SELECT
	mention_for_software.software,
	mention.id,
	mention.doi,
	mention.url,
	mention.title,
	mention.authors,
	mention.publisher,
	mention.publication_year,
	mention.journal,
	mention.page,
	mention.image_url,
	mention.mention_type,
	mention.source
FROM
	mention
INNER JOIN
	mention_for_software ON mention_for_software.mention = mention.id
-- will deduplicate identical entries
-- from scraped citations
UNION
-- scraped citations from reference papers
SELECT
	software,
	id,
	doi,
	url,
	title,
	authors,
	publisher,
	publication_year,
	journal,
	page,
	image_url,
	mention_type,
	source
FROM
	citation_by_software()
;
$function$
;

CREATE OR REPLACE FUNCTION public.count_software_mentions()
 RETURNS TABLE(software uuid, mention_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY SELECT
		mentions_by_software.software, COUNT(mentions_by_software.id) AS mention_cnt
	FROM
		mentions_by_software()
	GROUP BY
		mentions_by_software.software;
END
$function$
;

