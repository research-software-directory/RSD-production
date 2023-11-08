---------- CREATED BY MIGRA ----------

alter table "public"."mention" alter column "authors" set data type character varying(50000) using "authors"::character varying(50000);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.project_status()
 RETURNS TABLE(project uuid, status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.id,
	CASE
		WHEN project.date_end < now() THEN 'finished'::VARCHAR
		WHEN project.date_start > now() THEN 'upcoming'::VARCHAR
		WHEN project.date_start < now() AND project.date_end > now() THEN 'in_progress'::VARCHAR
		ELSE 'unknown'::VARCHAR
	END AS status
FROM
	project
$function$
;

CREATE OR REPLACE FUNCTION public.slug_from_log_reference(table_name character varying, reference_id uuid)
 RETURNS TABLE(slug character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT CASE
	WHEN table_name = 'repository_url' THEN (
		SELECT
			CONCAT('/software/', slug, '/edit/information') as slug
		FROM
			software WHERE id = reference_id
	)
	WHEN table_name = 'package_manager' THEN (
		SELECT
			CONCAT('/software/', slug, '/edit/package-managers') as slug
		FROM
			software
		WHERE id = (SELECT software FROM package_manager WHERE id = reference_id))
	WHEN table_name = 'mention' AND reference_id IS NOT NULL THEN (
		SELECT
			CONCAT('/api/v1/mention?id=eq.', reference_id) as slug
	)
	END
$function$
;

