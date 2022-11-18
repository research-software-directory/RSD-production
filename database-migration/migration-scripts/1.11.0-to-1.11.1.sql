---------- CREATED BY MIGRA ----------

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.homepage_counts(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT contributor_cnt bigint, OUT software_mention_cnt bigint)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	SELECT count(id) FROM software INTO software_cnt;
	SELECT count(id) FROM project INTO project_cnt;
	SELECT
		count(id) AS organisation_cnt
	FROM
		organisations_overview(true)
	WHERE
		organisations_overview.parent IS NULL AND organisations_overview.score>0
	INTO organisation_cnt;
	SELECT count(display_name) FROM unique_contributors() INTO contributor_cnt;
	SELECT count(mention) FROM mention_for_software INTO software_mention_cnt;
END
$function$
;
