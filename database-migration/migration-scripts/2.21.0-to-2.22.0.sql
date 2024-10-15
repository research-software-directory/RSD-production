---------- CREATED BY MIGRA ----------

alter table "public"."mention" add column "openalex_id" citext;

CREATE UNIQUE INDEX mention_openalex_id_key ON public.mention USING btree (openalex_id);

alter table "public"."mention" add constraint "mention_openalex_id_check" CHECK ((openalex_id ~ '^https://openalex\.org/[WwAaSsIiCcPpFf]\d{3,13}$'::citext));

alter table "public"."mention" add constraint "mention_openalex_id_key" UNIQUE using index "mention_openalex_id_key";

-- manually added

UPDATE mention SET openalex_id = external_id WHERE external_id ~ '^https://openalex\.org/[WwAaSsIiCcPpFf]\d{3,13}$';

-- end manually added

alter table "public"."mention" drop constraint "mention_external_id_source_key";

drop function if exists "public"."reference_papers_to_scrape"();

drop index if exists "public"."mention_external_id_source_key";

alter table "public"."mention" drop column "external_id";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.reference_papers_to_scrape()
 RETURNS TABLE(id uuid, doi citext, openalex_id citext, citations_scraped_at timestamp with time zone, known_citing_dois citext[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT mention.id, mention.doi, mention.openalex_id, mention.citations_scraped_at, ARRAY_REMOVE(ARRAY_AGG(citation.doi), NULL)
	FROM mention
	LEFT JOIN citation_for_mention ON mention.id = citation_for_mention.mention
	LEFT JOIN mention AS citation ON citation_for_mention.citation = citation.id
	WHERE
	-- ONLY items with DOI or OpenAlex id
		(mention.doi IS NOT NULL OR mention.openalex_id IS NOT NULL)
		AND (
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

