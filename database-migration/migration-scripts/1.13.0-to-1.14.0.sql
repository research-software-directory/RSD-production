---------- CREATED BY MIGRA ----------

alter table "public"."software" add column "image_id" character varying(40);

alter table "public"."software" add constraint "software_image_id_fkey" FOREIGN KEY (image_id) REFERENCES image(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.organisation_route(id uuid, OUT organisation uuid, OUT rsd_path character varying)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
	current_org UUID := id;
	route VARCHAR := '';
	slug VARCHAR;
BEGIN
	WHILE current_org IS NOT NULL LOOP
		SELECT
			organisation.slug,
			organisation.parent
		FROM
			organisation
		WHERE
			organisation.id = current_org
		INTO slug, current_org;
--	combine paths in reverse order
		route := CONCAT(slug,'/',route);
	END LOOP;
	SELECT id, route INTO organisation,rsd_path;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_search()
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], keywords_text text, research_domain character varying[], research_domain_text text)
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
			WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
			WHEN project.date_start > now() THEN 'Starting'::VARCHAR
			WHEN project.date_end < now() THEN 'Finished'::VARCHAR
			ELSE 'Running'::VARCHAR
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id,
		keyword_filter_for_project.keywords,
		keyword_filter_for_project.keywords_text,
		research_domain_filter_for_project.research_domain,
		research_domain_filter_for_project.research_domain_text
	FROM
		project
	LEFT JOIN
		keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
	LEFT JOIN
		research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying)
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
			WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
			WHEN project.date_start > now() THEN 'Starting'::VARCHAR
			WHEN project.date_end < now() THEN 'Finished'::VARCHAR
			ELSE 'Running'::VARCHAR
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id
	FROM
		project
	INNER JOIN
		maintainer_for_project ON project.id = maintainer_for_project.project
	WHERE
		maintainer_for_project.maintainer = maintainer_id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, is_featured boolean, image_id character varying, organisation uuid, status relation_status, keywords citext[])
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT DISTINCT ON (project.id)
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		CASE
			WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
			WHEN project.date_start > now() THEN 'Starting'::VARCHAR
			WHEN project.date_end < now() THEN 'Finished'::VARCHAR
			ELSE 'Running'::VARCHAR
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project_for_organisation.is_featured,
		project.image_id,
		project_for_organisation.organisation,
		project_for_organisation.status,
		keyword_filter_for_project.keywords
	FROM
		project
	LEFT JOIN
		project_for_organisation ON project.id = project_for_organisation.project
	LEFT JOIN
		keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
	WHERE
		project_for_organisation.organisation IN (SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id))
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.related_projects_for_project(origin_id uuid)
 RETURNS TABLE(origin uuid, id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, status relation_status, image_id character varying)
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
			WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
			WHEN project.date_start > now() THEN 'Starting'::VARCHAR
			WHEN project.date_end < now() THEN 'Finished'::VARCHAR
			ELSE 'Running'::VARCHAR
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project_for_project.status,
		project.image_id
	FROM
		project
	INNER JOIN
		project_for_project ON project.id = project_for_project.relation
	WHERE
		project_for_project.origin = origin_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.related_projects_for_software(software_id uuid)
 RETURNS TABLE(software uuid, id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, status relation_status, image_id character varying)
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
			WHEN project.date_start IS NULL THEN 'Starting'::VARCHAR
			WHEN project.date_start > now() THEN 'Starting'::VARCHAR
			WHEN project.date_end < now() THEN 'Finished'::VARCHAR
			ELSE 'Running'::VARCHAR
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		software_for_project.status,
		project.image_id
	FROM
		project
	INNER JOIN
		software_for_project ON project.id = software_for_project.project
	WHERE
		software_for_project.software = software_id
	;
END
$function$
;
