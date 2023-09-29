---------- CREATED BY MIGRA ----------

drop function if exists "public"."prog_lang_cnt_for_software"();

drop function if exists "public"."research_domain_count_for_projects"();

drop function if exists "public"."organisations_overview"(public boolean);

drop function if exists "public"."project_overview"();

drop function if exists "public"."project_search"(search character varying);

drop function if exists "public"."projects_by_organisation"(organisation_id uuid);

drop function if exists "public"."software_by_organisation"(organisation_id uuid);

drop function if exists "public"."software_overview"();

drop function if exists "public"."software_search"(search character varying);

create table "public"."global_announcement" (
    "id" boolean not null default true,
    "text" character varying(2000),
    "enabled" boolean not null default false,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."global_announcement" enable row level security;

create table "public"."software_highlight" (
    "software" uuid not null,
    "date_start" date,
    "date_end" date,
    "position" integer,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."software_highlight" enable row level security;

CREATE UNIQUE INDEX global_announcement_pkey ON public.global_announcement USING btree (id);

CREATE UNIQUE INDEX software_highlight_pkey ON public.software_highlight USING btree (software);

alter table "public"."global_announcement" add constraint "global_announcement_pkey" PRIMARY KEY using index "global_announcement_pkey";

alter table "public"."software_highlight" add constraint "software_highlight_pkey" PRIMARY KEY using index "software_highlight_pkey";

alter table "public"."global_announcement" add constraint "global_announcement_id_check" CHECK (id);

alter table "public"."software_highlight" add constraint "software_highlight_software_fkey" FOREIGN KEY (software) REFERENCES software(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.backend_log_view()
 RETURNS TABLE(id uuid, service_name character varying, table_name character varying, reference_id uuid, message character varying, stack_trace character varying, other_data jsonb, created_at timestamp with time zone, updated_at timestamp with time zone, slug character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	*,
	slug_from_log_reference(backend_log.table_name, backend_log.reference_id)
FROM
	backend_log
$function$
;

CREATE OR REPLACE FUNCTION public.license_filter_for_software()
 RETURNS TABLE(software uuid, licenses character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	license_for_software.software,
	ARRAY_AGG(license_for_software.license)
FROM
	license_for_software
GROUP BY
	license_for_software.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_domains_filter(organisation_id uuid, search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(domain character varying, domain_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(research_domain) AS domain,
	COUNT(id) AS domain_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	domain
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_keywords_filter(organisation_id uuid, search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_participating_organisations_filter(organisation_id uuid, search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(organisation character varying, organisation_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(participating_organisations) AS organisation,
	COUNT(id) AS organisation_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	organisation
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_status_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(project_status character varying, project_status_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project_status,
	COUNT(id) AS project_status_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
GROUP BY
	project_status
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_keywords_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	software_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_languages_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(prog_language text, prog_language_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(prog_lang) AS prog_language,
	COUNT(id) AS prog_language_cnt
FROM
	software_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_licenses_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(license character varying, license_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(licenses) AS license,
	COUNT(id) AS license_cnt
FROM
	software_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.project_domains_filter(search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(domain character varying, domain_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(research_domain) AS domain,
	COUNT(id) AS domain_cnt
FROM
	project_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	domain
;
$function$
;

CREATE OR REPLACE FUNCTION public.project_keywords_filter(search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	project_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.project_participating_organisations()
 RETURNS TABLE(project uuid, organisations character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project_for_organisation.project,
	ARRAY_AGG(organisation.name) AS organisations
FROM
	organisation
INNER JOIN
	project_for_organisation ON organisation.id = project_for_organisation.organisation
WHERE
	project_for_organisation.role = 'participating' AND organisation.parent IS NULL
GROUP BY
	project_for_organisation.project
;
$function$
;

CREATE OR REPLACE FUNCTION public.project_participating_organisations_filter(search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(organisation character varying, organisation_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(participating_organisations) AS organisation,
	COUNT(id) AS organisation_cnt
FROM
	project_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	organisation
;
$function$
;

CREATE OR REPLACE FUNCTION public.project_status()
 RETURNS TABLE(project uuid, status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.id,
	CASE
		WHEN project.date_end < now() THEN 'finished'::VARCHAR
		WHEN project.date_start > now() THEN 'pending'::VARCHAR
		WHEN project.date_start < now() AND project.date_end > now() THEN 'in_progress'::VARCHAR
		ELSE 'unknown'::VARCHAR
	END AS status
FROM
	project
$function$
;

CREATE OR REPLACE FUNCTION public.project_status_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(project_status character varying, project_status_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project_status,
	COUNT(id) AS project_status_cnt
FROM
	project_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
GROUP BY
	project_status
;
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_organisation_search(organisation_id uuid, search character varying)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, is_featured boolean, status relation_status, keywords citext[], research_domain character varying[], participating_organisations character varying[], impact_cnt integer, output_cnt integer, project_status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (project.id)
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	project.date_start,
	project.date_end,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	project_for_organisation.is_featured,
	project_for_organisation.status,
	keyword_filter_for_project.keywords,
	research_domain_filter_for_project.research_domain,
	project_participating_organisations.organisations AS participating_organisations,
	COALESCE(count_project_impact.impact_cnt, 0) AS impact_cnt,
	COALESCE(count_project_output.output_cnt, 0) AS output_cnt,
	project_status.status
FROM
	project
LEFT JOIN
	project_for_organisation ON project.id = project_for_organisation.project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
LEFT JOIN
	project_participating_organisations() ON project.id=project_participating_organisations.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
LEFT JOIN
	project_status() ON project.id=project_status.project
WHERE
	project_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	) AND (
		project.title ILIKE CONCAT('%', search, '%')
		OR
		project.slug ILIKE CONCAT('%', search, '%')
		OR
		project.subtitle ILIKE CONCAT('%', search, '%')
		OR
		keyword_filter_for_project.keywords_text ILIKE CONCAT('%', search, '%')
		OR
		research_domain_filter_for_project.research_domain_text ILIKE CONCAT('%', search, '%')
	)
ORDER BY
	project.id,
	CASE
		WHEN title ILIKE search THEN 0
		WHEN title ILIKE CONCAT(search, '%') THEN 1
		WHEN title ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN subtitle ILIKE search THEN 0
		WHEN subtitle ILIKE CONCAT(search, '%') THEN 1
		WHEN subtitle ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_global_announcement()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = TRUE;
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_software_highlight()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_global_announcement()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_software_highlight()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.software = OLD.software;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
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
			CONCAT('/software/',slug,'/edit/information') as slug
		FROM
			software WHERE id = reference_id
	)
	WHEN table_name = 'package_manager' THEN (
		SELECT
			CONCAT('/software/',slug,'/edit/package-managers') as slug
		FROM
			software
		WHERE id = (SELECT software FROM package_manager WHERE id = reference_id))
	END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_organisation_search(organisation_id uuid, search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, is_featured boolean, status relation_status, keywords citext[], prog_lang text[], licenses character varying[], contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (software.id)
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.is_published,
	software.updated_at,
	software_for_organisation.is_featured,
	software_for_organisation.status,
	keyword_filter_for_software.keywords,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt
FROM
	software
LEFT JOIN
	software_for_organisation ON software.id=software_for_organisation.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
WHERE
	software_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	) AND (
		software.brand_name ILIKE CONCAT('%', search, '%')
		OR
		software.slug ILIKE CONCAT('%', search, '%')
		OR
		software.short_statement ILIKE CONCAT('%', search, '%')
		OR
		keyword_filter_for_software.keywords_text ILIKE CONCAT('%', search, '%')
	)
ORDER BY
	software.id,
	CASE
		WHEN brand_name ILIKE search THEN 0
		WHEN brand_name ILIKE CONCAT(search, '%') THEN 1
		WHEN brand_name ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN short_statement ILIKE search THEN 0
		WHEN short_statement ILIKE CONCAT(search, '%') THEN 1
		WHEN short_statement ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_for_highlight()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, is_published boolean, contributor_cnt bigint, mention_cnt bigint, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], "position" integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.updated_at,
	software.is_published,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	software_highlight.position
FROM
	software
INNER JOIN
	software_highlight ON software.id=software_highlight.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_keywords_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_languages_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(prog_language text, prog_language_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(prog_lang) AS prog_language,
	COUNT(id) AS prog_language_cnt
FROM
	software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_licenses_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(license character varying, license_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(licenses) AS license,
	COUNT(id) AS license_cnt
FROM
	software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.get_image(uid character varying)
 RETURNS bytea
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE headers TEXT;
DECLARE blob BYTEA;

BEGIN
	SELECT format(
		'[{"Content-Type": "%s"},'
		'{"Content-Disposition": "inline; filename=\"%s\""},'
		'{"Cache-Control": "max-age=31536001"}]',
		mime_type,
		uid)
	FROM image WHERE id = uid INTO headers;

	PERFORM set_config('response.headers', headers, TRUE);

	SELECT decode(image.data, 'base64') FROM image WHERE id = uid INTO blob;

	IF FOUND
		THEN RETURN(blob);
	ELSE RAISE SQLSTATE 'PT404'
		USING
			message = 'NOT FOUND',
			detail = 'File not found',
			hint = format('%s seems to be an invalid file id', image_id);
	END IF;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, short_description character varying, country character varying, ror_id character varying, website character varying, is_tenant boolean, rsd_path character varying, parent_names character varying, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, release_cnt bigint, score bigint)
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
	organisation.country,
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

CREATE OR REPLACE FUNCTION public.prog_lang_filter_for_software()
 RETURNS TABLE(software uuid, prog_lang text[])
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		repository_url.software,
		(SELECT
			ARRAY_AGG(p_lang ORDER BY repository_url.languages -> p_lang DESC)
		FROM
			JSONB_OBJECT_KEYS(repository_url.languages) p_lang
		) AS "prog_lang"
	FROM
		repository_url
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_overview()
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], keywords_text text, research_domain character varying[], research_domain_text text, participating_organisations character varying[], impact_cnt integer, output_cnt integer, project_status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	project.date_start,
	project.date_end,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	keyword_filter_for_project.keywords,
	keyword_filter_for_project.keywords_text,
	research_domain_filter_for_project.research_domain,
	research_domain_filter_for_project.research_domain_text,
	project_participating_organisations.organisations AS participating_organisations,
	COALESCE(count_project_impact.impact_cnt, 0) AS impact_cnt,
	COALESCE(count_project_output.output_cnt, 0) AS output_cnt,
	project_status.status
FROM
	project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
LEFT JOIN
	project_participating_organisations() ON project.id=project_participating_organisations.project
LEFT JOIN
	count_project_impact() ON project.id=count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id=count_project_output.project
LEFT JOIN
	project_status() ON project.id=project_status.project
;
$function$
;

CREATE OR REPLACE FUNCTION public.project_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], keywords_text text, research_domain character varying[], research_domain_text text, participating_organisations character varying[], impact_cnt integer, output_cnt integer, project_status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	project.date_start,
	project.date_end,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	keyword_filter_for_project.keywords,
	keyword_filter_for_project.keywords_text,
	research_domain_filter_for_project.research_domain,
	research_domain_filter_for_project.research_domain_text,
	project_participating_organisations.organisations AS participating_organisations,
	COALESCE(count_project_impact.impact_cnt, 0),
	COALESCE(count_project_output.output_cnt, 0),
	project_status.status
FROM
	project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
LEFT JOIN
	project_participating_organisations() ON project.id=project_participating_organisations.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
LEFT JOIN
	project_status() ON project.id=project_status.project
WHERE
	project.title ILIKE CONCAT('%', search, '%')
	OR
	project.slug ILIKE CONCAT('%', search, '%')
	OR
	project.subtitle ILIKE CONCAT('%', search, '%')
	OR
	keyword_filter_for_project.keywords_text ILIKE CONCAT('%', search, '%')
	OR
	research_domain_filter_for_project.research_domain_text ILIKE CONCAT('%', search, '%')
ORDER BY
	CASE
		WHEN title ILIKE search THEN 0
		WHEN title ILIKE CONCAT(search, '%') THEN 1
		WHEN title ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN subtitle ILIKE search THEN 0
		WHEN subtitle ILIKE CONCAT(search, '%') THEN 1
		WHEN subtitle ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
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
		project_status.status AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id
	FROM
		project
	INNER JOIN
		maintainer_for_project ON project.id = maintainer_for_project.project
	LEFT JOIN
		project_status() ON project.id=project_status.project
	WHERE
		maintainer_for_project.maintainer = maintainer_id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, is_featured boolean, status relation_status, keywords citext[], research_domain character varying[], participating_organisations character varying[], impact_cnt integer, output_cnt integer, project_status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (project.id)
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	project.date_start,
	project.date_end,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	project_for_organisation.is_featured,
	project_for_organisation.status,
	keyword_filter_for_project.keywords,
	research_domain_filter_for_project.research_domain,
	project_participating_organisations.organisations AS participating_organisations,
	COALESCE(count_project_impact.impact_cnt, 0) AS impact_cnt,
	COALESCE(count_project_output.output_cnt, 0) AS output_cnt,
	project_status.status
FROM
	project
LEFT JOIN
	project_for_organisation ON project.id = project_for_organisation.project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
LEFT JOIN
	project_participating_organisations() ON project.id=project_participating_organisations.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
LEFT JOIN
	project_status() ON project.id=project_status.project
WHERE
	project_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	)
;
$function$
;

CREATE OR REPLACE FUNCTION public.related_projects_for_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, status relation_status, origin uuid, relation uuid)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (project.id)
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
	project_for_project.status,
	project_for_project.origin,
	project_for_project.relation
FROM
	project
INNER JOIN
	project_for_project ON
		(project.id = project_for_project.relation AND project_for_project.origin = project_id)
		OR
		(project.id = project_for_project.origin AND project_for_project.relation = project_id)
LEFT JOIN
	project_status() ON project.id=project_status.project
;
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
		project_status.status AS current_state,
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
	LEFT JOIN
		project_status() ON project.id=project_status.project
	WHERE
		software_for_project.software = software_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, is_featured boolean, status relation_status, keywords citext[], prog_lang text[], licenses character varying[], contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$

SELECT DISTINCT ON (software.id)
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.is_published,
	software.updated_at,
	software_for_organisation.is_featured,
	software_for_organisation.status,
	keyword_filter_for_software.keywords,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt
FROM
	software
LEFT JOIN
	software_for_organisation ON software.id=software_for_organisation.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
WHERE
	software_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	)
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_overview()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.updated_at,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt,
	software.is_published,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses
FROM
	software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, is_published boolean, contributor_cnt bigint, mention_cnt bigint, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.updated_at,
	software.is_published,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses
FROM
	software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
WHERE
	software.brand_name ILIKE CONCAT('%', search, '%')
	OR
	software.slug ILIKE CONCAT('%', search, '%')
	OR
	software.short_statement ILIKE CONCAT('%', search, '%')
	OR
	keyword_filter_for_software.keywords_text ILIKE CONCAT('%', search, '%')
ORDER BY
	CASE
		WHEN brand_name ILIKE search THEN 0
		WHEN brand_name ILIKE CONCAT(search, '%') THEN 1
		WHEN brand_name ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN short_statement ILIKE search THEN 0
		WHEN short_statement ILIKE CONCAT(search, '%') THEN 1
		WHEN short_statement ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.suggest_platform(hostname character varying)
 RETURNS platform_type
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	code_platform
FROM
	(
		SELECT
			url,
			code_platform
		FROM
			repository_url
	) AS sub
WHERE
	(
		-- Returns the hostname of sub.url
		SELECT
			TOKEN
		FROM
			ts_debug(sub.url)
		WHERE
			alias = 'host'
	) = hostname
GROUP BY
	sub.code_platform
ORDER BY
	COUNT(*)
DESC LIMIT
	1;
;
$function$
;

create policy "admin_all_rights"
on "public"."global_announcement"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."global_announcement"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "admin_all_rights"
on "public"."software_highlight"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."software_highlight"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


CREATE TRIGGER sanitise_insert_global_announcement BEFORE INSERT ON public.global_announcement FOR EACH ROW EXECUTE FUNCTION sanitise_insert_global_announcement();

CREATE TRIGGER sanitise_update_global_announcement BEFORE UPDATE ON public.global_announcement FOR EACH ROW EXECUTE FUNCTION sanitise_update_global_announcement();

CREATE TRIGGER check_software_highlight_before_delete BEFORE DELETE ON public.software_highlight FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_software_highlight_before_insert BEFORE INSERT ON public.software_highlight FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_highlight_before_update BEFORE UPDATE ON public.software_highlight FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_software_highlight BEFORE INSERT ON public.software_highlight FOR EACH ROW EXECUTE FUNCTION sanitise_insert_software_highlight();

CREATE TRIGGER sanitise_update_software_highlight BEFORE UPDATE ON public.software_highlight FOR EACH ROW EXECUTE FUNCTION sanitise_update_software_highlight();

