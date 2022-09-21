---------- CREATED BY MIGRA ----------

drop function if exists "public"."organisations_of_project"();

drop function if exists "public"."organisations_of_software"();

drop function if exists "public"."software_by_organisation"();

create table "public"."oaipmh" (
    "id" boolean not null default true,
    "data" character varying,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."oaipmh" enable row level security;

CREATE UNIQUE INDEX oaipmh_pkey ON public.oaipmh USING btree (id);

alter table "public"."oaipmh" add constraint "oaipmh_pkey" PRIMARY KEY using index "oaipmh_pkey";

alter table "public"."oaipmh" add constraint "oaipmh_id_check" CHECK (id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.list_child_organisations(parent_id uuid)
 RETURNS TABLE(organisation_id uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE child_organisations UUID[];
DECLARE search_child_organisations UUID[];
DECLARE current_organisation UUID;
BEGIN
-- breadth-first search to find all child organisations
	search_child_organisations = search_child_organisations || parent_id;
	WHILE CARDINALITY(search_child_organisations) > 0 LOOP
		current_organisation = search_child_organisations[CARDINALITY(search_child_organisations)];
		child_organisations = child_organisations || current_organisation;
		search_child_organisations = trim_array(search_child_organisations, 1);
		search_child_organisations = search_child_organisations || (SELECT ARRAY(SELECT organisation.id FROM organisation WHERE parent = current_organisation));
	END LOOP;
	RETURN QUERY SELECT UNNEST(child_organisations);
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_of_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id uuid, status relation_status, role organisation_role, project uuid, parent uuid)
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
 RETURNS TABLE(id uuid, slug character varying, primary_maintainer uuid, name character varying, ror_id character varying, is_tenant boolean, website character varying, rsd_path character varying, logo_id uuid, status relation_status, software uuid)
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

CREATE OR REPLACE FUNCTION public.sanitise_insert_oaipmh()
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

CREATE OR REPLACE FUNCTION public.sanitise_update_oaipmh()
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
	WHERE software_for_organisation.organisation IN (SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id))
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_filter_for_project()
 RETURNS TABLE(project uuid, keywords citext[])
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		keyword_for_project.project AS project,
		array_agg(
			keyword.value
			ORDER BY value
		) AS keywords
	FROM
		keyword_for_project
	INNER JOIN
		keyword ON keyword.id = keyword_for_project.keyword
	GROUP BY keyword_for_project.project
;
END
$function$
;

CREATE OR REPLACE FUNCTION public.maintainers_of_organisation(organisation_id uuid)
 RETURNS TABLE(maintainer uuid, name character varying[], email character varying[], affiliation character varying[], is_primary boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE account_authenticated UUID;
BEGIN
	account_authenticated = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
	IF account_authenticated IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please login first';
	END IF;

	IF organisation_id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide a organisation id';
	END IF;

	IF NOT organisation_id IN (SELECT * FROM organisations_of_current_maintainer()) AND
		CURRENT_USER IS DISTINCT FROM 'rsd_admin' AND (
			SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER
		) IS DISTINCT FROM TRUE THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not a maintainer of this organisation';
	END IF;

	RETURN QUERY
	-- primary maintainer of organisation
	SELECT
		organisation.primary_maintainer AS maintainer,
		ARRAY_AGG(login_for_account."name") AS name,
		ARRAY_AGG(login_for_account.email) AS email,
		ARRAY_AGG(login_for_account.home_organisation) AS affiliation,
		TRUE AS is_primary
	FROM
		organisation
	INNER JOIN
		login_for_account ON organisation.primary_maintainer = login_for_account.account
	WHERE
		organisation.id = organisation_id
	GROUP BY
		organisation.id,organisation.primary_maintainer
	-- append second selection
	UNION
	-- other maintainers of organisation
	SELECT
		maintainer_for_organisation.maintainer,
		ARRAY_AGG(login_for_account."name") AS name,
		ARRAY_AGG(login_for_account.email) AS email,
		ARRAY_AGG(login_for_account.home_organisation) AS affiliation,
		FALSE AS is_primary
	FROM
		maintainer_for_organisation
	INNER JOIN
		login_for_account ON maintainer_for_organisation.maintainer = login_for_account.account
	WHERE
		maintainer_for_organisation.organisation = organisation_id
	GROUP BY
		maintainer_for_organisation.organisation, maintainer_for_organisation.maintainer
	-- primary as first record
	ORDER BY is_primary DESC;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, project_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	IF (public) THEN
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT project_for_organisation.project) AS project_cnt
		FROM
			project_for_organisation
		CROSS JOIN list_parent_organisations(project_for_organisation.organisation)
		WHERE
			status = 'approved' AND
			project IN (
				SELECT id FROM project WHERE is_published=TRUE
			)
		GROUP BY list_parent_organisations.organisation_id;
	ELSE
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT project_for_organisation.project) AS project_cnt
		FROM
			project_for_organisation
		CROSS JOIN list_parent_organisations(software_for_organisation.organisation)
		GROUP BY list_parent_organisations.organisation_id;
	END IF;
END
$function$
;

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
			WHEN project.date_end < now() THEN 'Finished'::varchar
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
			WHEN project.date_end < now() THEN 'Finished'::varchar
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
		project_for_organisation.organisation IN (SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id))
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
			WHEN project.date_end < now() THEN 'Finished'::varchar
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
			WHEN project.date_end < now() THEN 'Finished'::varchar
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

CREATE OR REPLACE FUNCTION public.software_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, software_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	IF (public) THEN
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT software_for_organisation.software) AS software_cnt
		FROM
			software_for_organisation
		INNER JOIN list_parent_organisations(software_for_organisation.organisation)
			ON list_parent_organisations.organisation_id IN (SELECT organisation_ID FROM list_parent_organisations(software_for_organisation.organisation))
		WHERE
			software_for_organisation.status = 'approved' AND
			software IN (
				SELECT id FROM software WHERE is_published=TRUE
			)
		GROUP BY list_parent_organisations.organisation_id;
	ELSE
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT software_for_organisation.software) AS software_cnt
		FROM
			software_for_organisation
		INNER JOIN list_parent_organisations(software_for_organisation.organisation)
			ON list_parent_organisations.organisation_id IN (SELECT organisation_ID FROM list_parent_organisations(software_for_organisation.organisation))
		GROUP BY list_parent_organisations.organisation_id;
	END IF;
END
$function$
;

create policy "admin_all_rights"
on "public"."oaipmh"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."oaipmh"
as permissive
for select
to web_anon, rsd_user
using (true);


CREATE TRIGGER sanitise_insert_oaipmh BEFORE INSERT ON public.oaipmh FOR EACH ROW EXECUTE FUNCTION sanitise_insert_oaipmh();

CREATE TRIGGER sanitise_update_oaipmh BEFORE UPDATE ON public.oaipmh FOR EACH ROW EXECUTE FUNCTION sanitise_update_oaipmh();
