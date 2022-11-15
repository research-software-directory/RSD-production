-- UNSAFE, work in progress, not production ready yet!

---------- CREATED BY MIGRA ----------

create extension if not exists "pgcrypto" with schema "public" version '1.3';

drop policy "admin_all_rights" on "public"."image_for_project";

drop policy "anyone_can_read" on "public"."image_for_project";

drop policy "maintainer_all_rights" on "public"."image_for_project";

drop policy "admin_all_rights" on "public"."logo_for_organisation";

drop policy "anyone_can_read" on "public"."logo_for_organisation";

drop policy "maintainer_all_rights" on "public"."logo_for_organisation";

drop policy "maintainer_insert_non_tenant" on "public"."logo_for_organisation";

alter table "public"."image_for_project" drop constraint "image_for_project_project_fkey";

alter table "public"."logo_for_organisation" drop constraint "logo_for_organisation_organisation_fkey";

drop function if exists "public"."get_contributor_image"(id uuid);

drop function if exists "public"."get_logo"(id uuid);

drop function if exists "public"."get_project_image"(id uuid);

drop function if exists "public"."get_team_member_image"(id uuid);

drop function if exists "public"."organisations_by_maintainer"(maintainer_id uuid);

drop function if exists "public"."organisations_of_project"(project_id uuid);

drop function if exists "public"."organisations_of_software"(software_id uuid);

drop function if exists "public"."organisations_overview"(public boolean);

drop function if exists "public"."project_search"();

drop function if exists "public"."projects_by_maintainer"(maintainer_id uuid);

drop function if exists "public"."projects_by_organisation"(organisation_id uuid);

drop function if exists "public"."related_projects_for_project"(origin_id uuid);

drop function if exists "public"."related_projects_for_software"(software_id uuid);

drop function if exists "public"."unique_contributors"();

drop function if exists "public"."unique_team_members"();

alter table "public"."image_for_project" drop constraint "image_for_project_pkey";

alter table "public"."logo_for_organisation" drop constraint "logo_for_organisation_pkey";

drop index if exists "public"."image_for_project_pkey";

drop index if exists "public"."logo_for_organisation_pkey";

drop table "public"."image_for_project";

drop table "public"."logo_for_organisation";

create table "public"."image" (
    "id" character varying(40) not null,
    "data" character varying(2750000) not null,
    "mime_type" character varying(100) not null,
    "created_at" timestamp with time zone not null
);


alter table "public"."image" enable row level security;

alter table "public"."contributor" drop column "avatar_data";

alter table "public"."contributor" drop column "avatar_mime_type";

alter table "public"."contributor" add column "avatar_id" character varying(40);

alter table "public"."organisation" add column "logo_id" character varying(40);

alter table "public"."project" add column "image_id" character varying(40);

alter table "public"."team_member" drop column "avatar_data";

alter table "public"."team_member" drop column "avatar_mime_type";

alter table "public"."team_member" add column "avatar_id" character varying(40);

CREATE UNIQUE INDEX image_pkey ON public.image USING btree (id);

alter table "public"."image" add constraint "image_pkey" PRIMARY KEY using index "image_pkey";

alter table "public"."contributor" add constraint "contributor_avatar_id_fkey" FOREIGN KEY (avatar_id) REFERENCES image(id);

alter table "public"."organisation" add constraint "organisation_logo_id_fkey" FOREIGN KEY (logo_id) REFERENCES image(id);

alter table "public"."project" add constraint "project_image_id_fkey" FOREIGN KEY (image_id) REFERENCES image(id);

alter table "public"."team_member" add constraint "team_member_avatar_id_fkey" FOREIGN KEY (avatar_id) REFERENCES image(id);

set check_function_bodies = off;

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
		'{"Cache-Control": "max-age=259200"}]',
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

CREATE OR REPLACE FUNCTION public.sanitise_insert_image()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
-- create SHA-1 id based on provided data content
	NEW.id = encode(digest(NEW.data,'sha1'),'hex');
	NEW.created_at = LOCALTIMESTAMP;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.unique_persons()
 RETURNS TABLE(display_name text, affiliation character varying, orcid character varying, given_names character varying, family_names character varying, email_address character varying, avatar_id character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
		SELECT
			unique_contributors.display_name,
			unique_contributors.affiliation,
			unique_contributors.orcid,
			unique_contributors.given_names,
			unique_contributors.family_names,
			unique_contributors.email_address,
			unique_contributors.avatar_id
		FROM
			unique_contributors()
		UNION
		SELECT
			unique_team_members.display_name,
			unique_team_members.affiliation,
			unique_team_members.orcid,
			unique_team_members.given_names,
			unique_team_members.family_names,
			unique_team_members.email_address,
			unique_team_members.avatar_id
		FROM
			unique_team_members()
		ORDER BY
			display_name ASC;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, ror_id character varying, website character varying, is_tenant boolean, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, rsd_path character varying)
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
		organisation.logo_id,
		software_count_by_organisation.software_cnt,
		project_count_by_organisation.project_cnt,
		children_count_by_organisation.children_cnt,
		organisation_route.rsd_path
	FROM
		organisation
	-- LEFT JOIN
	-- 	logo_for_organisation ON logo_for_organisation.organisation = organisation.id
	LEFT JOIN
		software_count_by_organisation() ON software_count_by_organisation.organisation = organisation.id
	LEFT JOIN
		project_count_by_organisation() ON project_count_by_organisation.organisation = organisation.id
	LEFT JOIN
		children_count_by_organisation() ON children_count_by_organisation.parent = organisation.id
	LEFT JOIN
		maintainer_for_organisation ON maintainer_for_organisation.organisation = organisation.id
	LEFT JOIN
		organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
	WHERE
		maintainer_for_organisation.maintainer = maintainer_id OR organisation.primary_maintainer = maintainer_id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_of_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id character varying, status relation_status, role organisation_role, "position" integer, project uuid, parent uuid)
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
			organisation.logo_id,
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
	-- LEFT JOIN
	-- 	logo_for_organisation ON logo_for_organisation.organisation = organisation.id
	WHERE
		project.id = project_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_of_software(software_id uuid)
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id character varying, status relation_status, "position" integer, software uuid)
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
		organisation.logo_id,
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
	-- LEFT JOIN
	-- 	logo_for_organisation ON logo_for_organisation.organisation = organisation.id
	WHERE
		software.id = software_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, ror_id character varying, website character varying, is_tenant boolean, rsd_path character varying, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, score bigint)
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
		organisation.logo_id,
		software_count_by_organisation.software_cnt,
		project_count_by_organisation.project_cnt,
		children_count_by_organisation.children_cnt,
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
	-- LEFT JOIN
	-- 	logo_for_organisation ON logo_for_organisation.organisation = organisation.id
	;
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
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now() THEN 'Finished'::varchar
			ELSE 'Running'::varchar
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
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now() THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id
	FROM
		project
	-- LEFT JOIN
	-- 	image_for_project ON project.id = image_for_project.project
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
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now() THEN 'Finished'::varchar
			ELSE 'Running'::varchar
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
	-- LEFT JOIN
	-- 	image_for_project ON project.id = image_for_project.project
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
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now() THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project_for_project.status,
		project.image_id
	FROM
		project
	-- LEFT JOIN
	-- 	image_for_project ON image_for_project.project = project.id
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
			WHEN project.date_end IS NULL THEN 'Starting'::varchar
			WHEN project.date_end < now() THEN 'Finished'::varchar
			ELSE 'Running'::varchar
		END AS current_state,
		project.date_start,
		project.updated_at,
		project.is_published,
		project.image_contain,
		software_for_project.status,
		project.image_id
	FROM
		project
	-- LEFT JOIN
	-- 	image_for_project ON image_for_project.project = project.id
	INNER JOIN
		software_for_project ON project.id = software_for_project.project
	WHERE
		software_for_project.software = software_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.unique_contributors()
 RETURNS TABLE(display_name text, affiliation character varying, orcid character varying, given_names character varying, family_names character varying, email_address character varying, avatar_id character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
		SELECT DISTINCT
		(CONCAT(c.given_names,' ',c.family_names)) AS display_name,
		c.affiliation,
		c.orcid,
		c.given_names,
		c.family_names,
		c.email_address,
		c.avatar_id
	FROM
		contributor c
	ORDER BY
		display_name ASC;
END
$function$
;

CREATE OR REPLACE FUNCTION public.unique_team_members()
 RETURNS TABLE(display_name text, affiliation character varying, orcid character varying, given_names character varying, family_names character varying, email_address character varying, avatar_id character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
		SELECT DISTINCT
			(CONCAT(c.given_names,' ',c.family_names)) AS display_name,
			c.affiliation,
			c.orcid,
			c.given_names,
			c.family_names,
			c.email_address,
			c.avatar_id
		FROM
			team_member c
		ORDER BY
			display_name ASC;
END
$function$
;

create policy "admin_all_rights"
on "public"."image"
as permissive
for all
to rsd_admin
using (true)
with check true;


create policy "anyone_can_read"
on "public"."image"
as permissive
for select
to web_anon, rsd_user
using (true);


create policy "rsd_user_all_rights"
on "public"."image"
as permissive
for all
to rsd_user
using (true)
with check true;


CREATE TRIGGER sanitise_insert_image BEFORE INSERT ON public.image FOR EACH ROW EXECUTE FUNCTION sanitise_insert_image();

CREATE TRIGGER sanitise_update_image BEFORE UPDATE ON public.image FOR EACH ROW EXECUTE FUNCTION sanitise_insert_image();
