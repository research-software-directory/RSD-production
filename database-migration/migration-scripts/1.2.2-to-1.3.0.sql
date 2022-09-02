---------- CREATED BY MIGRA ----------

drop function if exists "public"."project_search"();

drop function if exists "public"."projects_by_maintainer"(maintainer_id uuid);

drop function if exists "public"."projects_by_organisation"(organisation_id uuid);

drop function if exists "public"."related_projects_for_project"(origin_id uuid);

drop function if exists "public"."related_projects_for_software"(software_id uuid);

alter table "public"."project" add column "image_contain" boolean not null default false;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.project_search()
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id uuid, keywords citext[])
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		CASE
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now()  THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		image_for_project.project AS image_id,
		keyword_filter_for_project.keywords
	FROM
		project
	LEFT JOIN
		image_for_project ON project.id = image_for_project.project
	LEFT JOIN
		keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		CASE
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now()  THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		image_for_project.project AS image_id
	FROM
		project
	LEFT JOIN
		image_for_project ON project.id = image_for_project.project
	INNER JOIN
		maintainer_for_project ON project.id = maintainer_for_project.project
	WHERE
		maintainer_for_project.maintainer = maintainer_id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, is_featured boolean, image_id uuid, organisation uuid, status relation_status, keywords citext[])
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		CASE
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now()  THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project_for_organisation.is_featured,
		image_for_project.project AS image_id,
		project_for_organisation.organisation,
		project_for_organisation.status,
		keyword_filter_for_project.keywords
	FROM
		project
	LEFT JOIN
		image_for_project ON project.id = image_for_project.project
	LEFT JOIN
		project_for_organisation ON project.id = project_for_organisation.project
	LEFT JOIN
		keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
	WHERE
		project_for_organisation.organisation=organisation_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.related_projects_for_project(origin_id uuid)
 RETURNS TABLE(origin uuid, id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, status relation_status, image_id uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		project_for_project.origin,
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		CASE
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now()  THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project_for_project.status,
		image_for_project.project AS image_id
	FROM
		project
	LEFT JOIN
		image_for_project ON image_for_project.project = project.id
	INNER JOIN
		project_for_project ON project.id = project_for_project.relation
	WHERE
		project_for_project.origin = origin_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.related_projects_for_software(software_id uuid)
 RETURNS TABLE(software uuid, id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, status relation_status, image_id uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		software_for_project.software,
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		CASE
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now()  THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		software_for_project.status,
		image_for_project.project AS image_id
	FROM
		project
	LEFT JOIN
		image_for_project ON image_for_project.project = project.id
	INNER JOIN
		software_for_project ON project.id = software_for_project.project
	WHERE
		software_for_project.software = software_id
	;
END
$function$
;
