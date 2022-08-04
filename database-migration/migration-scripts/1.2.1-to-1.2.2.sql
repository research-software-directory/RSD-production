---------- CREATED MANUALLY ----------

-- It is advised to first turn off the scrapers before running this script as they might insert new duplicates
-- Check for duplicate DOI's in the mention, software and release_content tables respectively
SELECT LOWER(doi), COUNT(doi) FROM mention GROUP BY LOWER(doi) HAVING COUNT(doi) > 1;

SELECT LOWER(concept_doi), COUNT(concept_doi) FROM software GROUP BY LOWER(concept_doi) HAVING COUNT(concept_doi) > 1;

SELECT LOWER(doi), COUNT(doi) FROM release_content GROUP BY LOWER(doi) HAVING COUNT(doi) > 1;

-- We only have duplicates in the mention table. Therefore, we only need to deduplicate those.
-- IF YOU HAVE ANY DUPLICATES IN ONE OF THE TWO OTHER TABLES, YOU NEED TO WRITE CODE THAT DEDUPLICATES THIS YOURSELF!
-- We can not simply delete duplicates, as they might be referenced to in the mention_for_software, impact_for_project or output_for_project table.
-- First (arbitrarily) select mentions to keep:
SELECT DISTINCT ON (LOWER(doi)) * INTO TEMP mentions_to_keep FROM mention WHERE LOWER(doi) IN (SELECT LOWER(doi) FROM mention GROUP BY LOWER(doi) HAVING COUNT(doi) > 1);
-- Select duplicate mentions to delete that are not mentions to keep:
SELECT * INTO TEMP mentions_to_delete FROM mention WHERE LOWER(doi) IN (SELECT LOWER(doi) FROM mention GROUP BY LOWER(doi) HAVING COUNT(doi) > 1) AND id NOT IN (SELECT id FROM mentions_to_keep);

-- Create a table where each id of a mention to delete has a corresponding id of a mention to keep:
SELECT mentions_to_keep.id AS id_keep, mentions_to_delete.id AS id_delete INTO TEMP map_delete_to_keep FROM mentions_to_keep INNER JOIN mentions_to_delete ON LOWER(mentions_to_keep.doi) = LOWER(mentions_to_delete.doi);

-- Now update the references in the mention_for_software, impact_for_project and output_for_project from mentions to delete to the corresponding mentions to delete:
UPDATE mention_for_software SET mention = (SELECT id_keep FROM map_delete_to_keep WHERE mention = id_delete) WHERE mention IN (SELECT id FROM mentions_to_delete);
UPDATE impact_for_project SET mention = (SELECT id_keep FROM map_delete_to_keep WHERE mention = id_delete) WHERE mention IN (SELECT id FROM mentions_to_delete);
UPDATE output_for_project SET mention = (SELECT id_keep FROM map_delete_to_keep WHERE mention = id_delete) WHERE mention IN (SELECT id FROM mentions_to_delete);

-- Finally, we can delete the duplicate mentions
DELETE FROM mention WHERE id IN (SELECT id FROM mentions_to_delete);


---------- CREATED BY MIGRA ----------

alter table "public"."mention" drop constraint "mention_doi_check";

alter table "public"."software" drop constraint "software_concept_doi_check";

drop function if exists "public"."software_join_release"();

alter table "public"."mention" alter column "doi" set data type citext using "doi"::citext;

alter table "public"."release_content" alter column "doi" set data type citext using "doi"::citext;

alter table "public"."software" alter column "concept_doi" set data type citext using "concept_doi"::citext;

alter table "public"."release_content" add constraint "release_content_doi_check" CHECK (((doi ~ '^10(\.\w+)+/\S+$'::citext) AND (length((doi)::text) <= 255)));

alter table "public"."mention" add constraint "mention_doi_check" CHECK (((doi ~ '^10(\.\w+)+/\S+$'::citext) AND (length((doi)::text) <= 255)));

alter table "public"."software" add constraint "software_concept_doi_check" CHECK (((concept_doi ~ '^10(\.\w+)+/\S+$'::citext) AND (length((concept_doi)::text) <= 255)));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.software_join_release()
 RETURNS TABLE(software_id uuid, slug character varying, concept_doi citext, release_id uuid, releases_scraped_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY SELECT software.id AS software_id, software.slug, software.concept_doi, release.id AS release_id, release.releases_scraped_at FROM software LEFT JOIN RELEASE ON software.id = RELEASE.software;
	RETURN;
END
$function$
;

