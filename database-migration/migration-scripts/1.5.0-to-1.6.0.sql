---------- CREATED BY MIGRA ----------

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.software_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, software_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	IF (public) THEN
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT software_for_organisation.software) AS software_cnt
		FROM
			software_for_organisation
		CROSS JOIN list_parent_organisations(software_for_organisation.organisation)
		WHERE
			software_for_organisation.status = 'approved' AND
			software IN (
				SELECT id FROM software WHERE is_published=TRUE
			)
		GROUP BY list_parent_organisations.organisation_id;
	ELSE
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT software_for_organisation.software) AS software_cnt
		FROM
			software_for_organisation
		CROSS JOIN list_parent_organisations(software_for_organisation.organisation)
		GROUP BY list_parent_organisations.organisation_id;
	END IF;
END
$function$
;
