---------- CREATED BY MIGRA ----------

drop function if exists "public"."projects_by_maintainer"(maintainer_id uuid);

alter table "public"."package_manager" alter column "package_manager" drop default;

alter type "public"."package_manager_type" rename to "package_manager_type__old_version_to_be_dropped";

create type "public"."package_manager_type" as enum ('anaconda', 'chocolatey', 'cran', 'crates', 'debian', 'dockerhub', 'ghcr', 'github', 'gitlab', 'golang', 'maven', 'npm', 'pypi', 'snapcraft', 'sonatype', 'other');

alter table "public"."package_manager" alter column package_manager type "public"."package_manager_type" using package_manager::text::"public"."package_manager_type";

alter table "public"."package_manager" alter column "package_manager" set default 'other'::package_manager_type;

drop type "public"."package_manager_type__old_version_to_be_dropped";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.projects_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, impact_cnt integer, output_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		project_status.status AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id,
		COALESCE(count_project_impact.impact_cnt, 0),
		COALESCE(count_project_output.output_cnt, 0)
	FROM
		project
	INNER JOIN
		maintainer_for_project ON project.id = maintainer_for_project.project
	LEFT JOIN
		count_project_impact() ON count_project_impact.project = project.id
	LEFT JOIN
		count_project_output() ON count_project_output.project = project.id
	LEFT JOIN
		project_status() ON project.id=project_status.project
	WHERE
		maintainer_for_project.maintainer = maintainer_id;
$function$
;

