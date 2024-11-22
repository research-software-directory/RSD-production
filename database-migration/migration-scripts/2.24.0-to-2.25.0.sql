---------- CREATED BY MIGRA ----------

alter table "public"."repository_url" add column "archived" boolean;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.projects_of_category()
 RETURNS SETOF category_for_project
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT project.id, category_path.id
FROM project
INNER JOIN category_for_project
	ON project.id = category_for_project.project_id
INNER JOIN category_path(category_for_project.category_id)
	ON TRUE;
$function$
;

CREATE OR REPLACE FUNCTION public.software_of_category()
 RETURNS SETOF category_for_software
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT software.id, category_path.id
FROM software
INNER JOIN category_for_software
	ON software.id = category_for_software.software_id
INNER JOIN category_path(category_for_software.category_id)
	ON TRUE;
$function$
;

