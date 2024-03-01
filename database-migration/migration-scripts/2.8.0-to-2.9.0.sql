---------- CREATED BY MIGRA ----------

drop view if exists "public"."user_count_per_home_organisation";

alter table "public"."login_for_account" add column "last_login_date" timestamp with time zone;

alter table "public"."organisation" add column "city" character varying(100);

alter table "public"."organisation" add column "ror_last_error" character varying(500);

alter table "public"."organisation" add column "ror_scraped_at" timestamp with time zone;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.citation_by_project()
 RETURNS TABLE(project uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying, reference_papers uuid[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	output_for_project.project,
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
	mention.source,
	ARRAY_AGG(
		output_for_project.mention
	) AS reference_paper
FROM
	output_for_project
INNER JOIN
	citation_for_mention ON citation_for_mention.mention = output_for_project.mention
INNER JOIN
	mention ON mention.id = citation_for_mention.citation
--EXCLUDE reference papers items from citations
WHERE
	mention.id NOT IN (
		SELECT mention FROM output_for_project
	)
GROUP BY
	output_for_project.project,
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
;
$function$
;

CREATE OR REPLACE FUNCTION public.impact_by_project()
 RETURNS TABLE(project uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying, note character varying)
 LANGUAGE sql
 STABLE
AS $function$
-- impact for project
SELECT
	impact_for_project.project,
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
	mention.source,
	mention.note
FROM
	mention
INNER JOIN
	impact_for_project ON impact_for_project.mention = mention.id
-- will deduplicate identical entries
-- from scraped citations
UNION
-- scraped citations from reference papers
SELECT
	project,
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
	source,
	-- scraped citations have no note prop
	-- we need this prop in the edit impact section
	NULL as note
FROM
	citation_by_project()
;
$function$
;

CREATE OR REPLACE FUNCTION public.citation_by_software()
 RETURNS TABLE(software uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying, reference_papers uuid[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	reference_paper_for_software.software,
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
	mention.source,
	ARRAY_AGG(
		reference_paper_for_software.mention
	) AS reference_paper
FROM
	reference_paper_for_software
INNER JOIN
	citation_for_mention ON citation_for_mention.mention = reference_paper_for_software.mention
INNER JOIN
	mention ON mention.id = citation_for_mention.citation
--EXCLUDE reference papers items from citations
WHERE
	mention.id NOT IN (
		SELECT mention FROM reference_paper_for_software
	)
GROUP BY
	reference_paper_for_software.software,
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
;
$function$
;

CREATE OR REPLACE FUNCTION public.count_project_impact()
 RETURNS TABLE(project uuid, impact_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	impact_by_project.project,
	COUNT(impact_by_project.id)
FROM
	impact_by_project()
GROUP BY
	impact_by_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.reference_papers_to_scrape()
 RETURNS TABLE(id uuid, doi citext, citations_scraped_at timestamp with time zone, known_dois citext[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT mention.id, mention.doi, mention.citations_scraped_at, ARRAY_REMOVE(ARRAY_AGG(citation.doi), NULL)
	FROM mention
	LEFT JOIN citation_for_mention ON mention.id = citation_for_mention.mention
	LEFT JOIN mention AS citation ON citation_for_mention.citation = citation.id
	WHERE
	-- ONLY items with DOI
		mention.doi IS NOT NULL AND (
			mention.id IN (
				SELECT mention FROM reference_paper_for_software
			)
			OR
			mention.id IN (
				SELECT mention FROM output_for_project
			)
		)
	GROUP BY mention.id
$function$
;

CREATE OR REPLACE FUNCTION public.slug_from_log_reference(table_name character varying, reference_id uuid)
 RETURNS character varying
 LANGUAGE sql
 STABLE
AS $function$
SELECT CASE
	WHEN table_name = 'repository_url' THEN (
		SELECT
			CONCAT('/software/', slug, '/edit/information')
		FROM
			software WHERE id = reference_id
	)
	WHEN table_name = 'package_manager' THEN (
		SELECT
			CONCAT('/software/', slug, '/edit/package-managers')
		FROM
			software
		WHERE id = (SELECT software FROM package_manager WHERE id = reference_id))
	WHEN table_name = 'mention' AND reference_id IS NOT NULL THEN (
		SELECT
			CONCAT('/api/v1/mention?id=eq.', reference_id)
	)
	WHEN table_name = 'organisation' AND reference_id IS NOT NULL THEN (
		SELECT
			CONCAT('/organisations/', slug, '?tab=settings')
		FROM
			organisation
		WHERE id = reference_id
	)
	END
$function$
;

create or replace view "public"."user_count_per_home_organisation" as  SELECT login_for_account.home_organisation,
    count(*) AS count
   FROM login_for_account
  GROUP BY login_for_account.home_organisation;


