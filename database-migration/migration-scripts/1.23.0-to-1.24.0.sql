---------- CREATED BY MIGRA ----------

drop function if exists "public"."organisations_overview"(public boolean);

alter table "public"."organisation" add column "country" character varying(100);

alter table "public"."organisation" add column "short_description" character varying(300);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.organisations_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, short_description character varying, ror_id character varying, website character varying, is_tenant boolean, rsd_path character varying, parent_names character varying, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, release_cnt bigint, score bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	organisation.id,
	organisation.slug,
	organisation.parent,
	organisation.primary_maintainer,
	organisation.name,
	organisation.short_description,
	organisation.ror_id,
	organisation.website,
	organisation.is_tenant,
	organisation_route.rsd_path,
	organisation_route.parent_names,
	organisation.logo_id,
	software_count_by_organisation.software_cnt,
	project_count_by_organisation.project_cnt,
	children_count_by_organisation.children_cnt,
	release_cnt_by_organisation.release_cnt,
	(
		COALESCE(software_count_by_organisation.software_cnt,0) +
		COALESCE(project_count_by_organisation.project_cnt,0)
	) as score
FROM
	organisation
LEFT JOIN
	organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
LEFT JOIN
	software_count_by_organisation(public) ON software_count_by_organisation.organisation = organisation.id
LEFT JOIN
	project_count_by_organisation(public) ON project_count_by_organisation.organisation = organisation.id
LEFT JOIN
	children_count_by_organisation() ON children_count_by_organisation.parent = organisation.id
LEFT JOIN
	release_cnt_by_organisation() ON release_cnt_by_organisation.organisation_id = organisation.id
;
$function$
;

