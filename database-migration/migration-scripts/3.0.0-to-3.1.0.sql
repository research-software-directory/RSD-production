---------- CREATED BY MIGRA ----------

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.category_for_project_status(project_id uuid, category_id uuid)
 RETURNS character varying
 LANGUAGE sql
 STABLE
AS $function$
WITH
	category_data AS (SELECT organisation FROM category WHERE category.id = category_id)
SELECT
	CASE
		WHEN (SELECT organisation FROM category_data) IS NULL THEN 'global'
		WHEN (SELECT organisation FROM category_data AS organisation_id) IS NOT NULL THEN (SELECT status FROM project_for_organisation WHERE project_for_organisation.project = project_id AND project_for_organisation.organisation = (SELECT organisation FROM category_data AS organisation_id) AND role = 'participating')::VARCHAR
		ELSE 'other'
		END
$function$
;

