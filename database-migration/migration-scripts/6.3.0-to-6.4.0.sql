---------- CREATED BY MIGRA ----------

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_mention(mention_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
			AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete mentions';
	END IF;

	IF mention_id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the mention to delete';
	END IF;

	DELETE FROM mention_for_software WHERE mention_for_software.mention = mention_id;
	DELETE FROM reference_paper_for_software WHERE reference_paper_for_software.mention = mention_id;
	DELETE FROM citation_for_mention WHERE citation_for_mention.mention = mention_id OR citation_for_mention.citation = mention_id;
	DELETE FROM output_for_project WHERE output_for_project.mention = mention_id;
	DELETE FROM impact_for_project WHERE impact_for_project.mention = mention_id;
	DELETE FROM release_version WHERE release_version.mention_id = delete_mention.mention_id;

	DELETE FROM mention WHERE mention.id = mention_id;
END
$function$
;

