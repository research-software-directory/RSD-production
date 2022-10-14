---------- CREATED BY MIGRA ----------

drop function if exists "public"."organisations_of_project"(project_id uuid);

drop function if exists "public"."organisations_of_software"(software_id uuid);

alter table "public"."organisation" add column "description" character varying(10000);

alter table "public"."project_for_organisation" add column "position" integer;

alter table "public"."software_for_organisation" add column "position" integer;

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.organisations_of_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id uuid, status relation_status, role organisation_role, "position" integer, project uuid, parent uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
			organisation.id AS id,
			organisation.slug,
			organisation.primary_maintainer,
			organisation.name,
			organisation.ror_id,
			organisation.is_tenant,
			organisation.website,
			organisation_route.rsd_path,
			logo_for_organisation.organisation AS logo_id,
			project_for_organisation.status,
			project_for_organisation.role,
			project_for_organisation.position,
			project.id AS project,
			organisation.parent
	FROM
		project
	INNER JOIN
		project_for_organisation ON project.id = project_for_organisation.project
	INNER JOIN
		organisation ON project_for_organisation.organisation = organisation.id
	LEFT JOIN
		organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
	LEFT JOIN
		logo_for_organisation ON logo_for_organisation.organisation = organisation.id
	WHERE
		project.id = project_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_of_software(software_id uuid)
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id uuid, status relation_status, "position" integer, software uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		organisation.id AS id,
		organisation.slug,
		organisation.primary_maintainer,
		organisation.name,
		organisation.ror_id,
		organisation.is_tenant,
		organisation.website,
		organisation_route.rsd_path,
		logo_for_organisation.organisation AS logo_id,
		software_for_organisation.status,
		software_for_organisation.position,
		software.id AS software
	FROM
		software
	INNER JOIN
		software_for_organisation ON software.id = software_for_organisation.software
	INNER JOIN
		organisation ON software_for_organisation.organisation = organisation.id
	LEFT JOIN
		organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
	LEFT JOIN
		logo_for_organisation ON logo_for_organisation.organisation = organisation.id
	WHERE
		software.id = software_id
	;
END
$function$
;
