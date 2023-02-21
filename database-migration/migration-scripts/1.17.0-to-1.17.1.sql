---------- CREATED BY MIGRA ----------

-- moved manually
alter table "public"."mention" add column "doi_registration_date" timestamp with time zone;

-- added manually
UPDATE "public"."mention" SET "doi_registration_date" = "publication_date";

drop function if exists "public"."release_cnt_by_organisation"(organisation_id uuid);

drop function if exists "public"."releases_by_organisation"(organisation_id uuid);

alter table "public"."mention" drop column "publication_date";


set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.release_cnt_by_organisation()
 RETURNS TABLE(organisation_id uuid, release_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	SELECT
		releases_by_organisation.organisation_id AS organisation_id,
		COUNT(releases_by_organisation.*) AS release_cnt
	FROM
		organisation
	INNER JOIN
		releases_by_organisation() ON releases_by_organisation.organisation_id = organisation.id
	GROUP BY
		releases_by_organisation.organisation_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.releases_by_organisation()
 RETURNS TABLE(organisation_id uuid, software_id uuid, software_slug character varying, software_name character varying, release_doi citext, release_tag character varying, release_date timestamp with time zone, release_year smallint, release_authors character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	SELECT
		organisation.id AS organisation_id,
		software.id AS software_id,
		software.slug AS software_slug,
		software.brand_name AS software_name,
		mention.doi AS release_doi,
		mention.version AS release_tag,
		mention.doi_registration_date AS release_date,
		mention.publication_year AS release_year,
		mention.authors AS release_authors
	FROM
		organisation
	CROSS JOIN
		list_child_organisations(organisation.id)
	INNER JOIN
		software_for_organisation ON list_child_organisations.organisation_id = software_for_organisation.organisation
	INNER JOIN
		software ON software.id = software_for_organisation.software
	INNER JOIN
		"release" ON "release".software = software.id
	INNER JOIN
		release_version ON release_version.release_id = "release".software
	INNER JOIN
		mention ON mention.id = release_version.mention_id
;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, ror_id character varying, website character varying, is_tenant boolean, rsd_path character varying, parent_names character varying, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, release_cnt bigint, score bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		organisation.id,
		organisation.slug,
		organisation.parent,
		organisation.primary_maintainer,
		organisation.name,
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
END
$function$
;

CREATE OR REPLACE FUNCTION public.release_cnt_by_year(organisation_id uuid)
 RETURNS TABLE(release_year smallint, release_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	SELECT
		releases_by_organisation.release_year,
		COUNT(releases_by_organisation.*) AS release_cnt
	FROM
		releases_by_organisation()
	WHERE
		releases_by_organisation.organisation_id = release_cnt_by_year.organisation_id
	GROUP BY
		releases_by_organisation.release_year
	;
END
$function$
;
