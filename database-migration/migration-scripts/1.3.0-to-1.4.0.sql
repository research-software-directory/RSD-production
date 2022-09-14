---------- CREATED BY MIGRA ----------

alter table "public"."project_for_organisation" drop constraint "project_for_organisation_pkey";

drop index if exists "public"."project_for_organisation_pkey";

CREATE UNIQUE INDEX project_for_organisation_pkey ON public.project_for_organisation USING btree (project, organisation, role);

alter table "public"."project_for_organisation" add constraint "project_for_organisation_pkey" PRIMARY KEY using index "project_for_organisation_pkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.project_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, project_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	IF (public) THEN
		RETURN QUERY
		SELECT
			project_for_organisation.organisation,
			COUNT(DISTINCT project) AS project_cnt
		FROM
			project_for_organisation
		WHERE
			status = 'approved' AND
			project IN (
				SELECT id FROM project WHERE is_published=TRUE
			)
		GROUP BY project_for_organisation.organisation;
	ELSE
		RETURN QUERY
		SELECT
			project_for_organisation.organisation,
			COUNT(DISTINCT project) AS project_cnt
		FROM
			project_for_organisation
		GROUP BY project_for_organisation.organisation;
	END IF;
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
	SELECT DISTINCT ON (project.id)
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

