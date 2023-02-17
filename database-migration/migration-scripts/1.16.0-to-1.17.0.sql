---------- CREATED BY MIGRA ----------

drop function if exists "public"."release_cnt_by_organisation"();

drop function if exists "public"."software_release"();

-- this statement is safe, even if there is no NOT NULL constraint to drop
alter table "public"."account" alter column "agree_terms_updated_at" drop not null;

-- this statement is safe, even if there is no NOT NULL constraint to drop
alter table "public"."account" alter column "notice_privacy_statement_updated_at" drop not null;

alter table "public"."mention" add column "journal" character varying(500);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.release_cnt_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, release_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	SELECT
		organisation_id AS id,
		COUNT(releases_by_organisation.release_doi) AS release_cnt
	FROM
		releases_by_organisation(organisation_id)
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
		COUNT(releases_by_organisation.release_doi) AS release_cnt
	FROM
		releases_by_organisation(organisation_id)
	GROUP BY
		releases_by_organisation.release_year
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.releases_by_organisation(organisation_id uuid)
 RETURNS TABLE(software_id uuid, software_slug character varying, software_name character varying, release_doi citext, release_tag character varying, release_date date, release_year smallint, release_authors character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	SELECT DISTINCT
		software.id AS software_id,
		software.slug AS software_slug,
		software.brand_name AS software_name,
		mention.doi AS release_doi,
		mention.version AS release_tag,
		mention.publication_date AS release_date,
		mention.publication_year AS release_year,
		mention.authors AS release_authors
	FROM
		list_child_organisations(organisation_id)
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
		release_cnt_by_organisation(organisation.id) ON release_cnt_by_organisation.id = organisation.id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, is_published boolean, is_featured boolean, status relation_status, contributor_cnt bigint, mention_cnt bigint, updated_at timestamp with time zone, organisation uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT DISTINCT ON (software.id)
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.is_published,
		software_for_organisation.is_featured,
		software_for_organisation.status,
		count_software_countributors.contributor_cnt,
		count_software_mentions.mention_cnt,
		software.updated_at,
		software_for_organisation.organisation
	FROM
		software
	LEFT JOIN
		software_for_organisation ON software.id=software_for_organisation.software
	LEFT JOIN
		count_software_countributors() ON software.id=count_software_countributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	WHERE
		software_for_organisation.organisation IN (
			SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
		)
	;
END
$function$
;

