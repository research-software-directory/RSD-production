---------- CREATED BY MIGRA ----------

-- manually added

UPDATE contributor SET role = NULL WHERE role ~ '^\s*$';
UPDATE team_member SET role = NULL WHERE role ~ '^\s*$';
UPDATE contributor SET role = regexp_replace(role, '\s{2,}', ' ', 'g') WHERE NOT role ~ '^\S+( \S+)*$';
UPDATE team_member SET role = regexp_replace(role, '\s{2,}', ' ', 'g') WHERE NOT role ~ '^\S+( \S+)*$';
UPDATE contributor SET role = regexp_replace(role, '^\s+', '', 'g') WHERE NOT role ~ '^\S+( \S+)*$';
UPDATE team_member SET role = regexp_replace(role, '^\s+', '', 'g') WHERE NOT role ~ '^\S+( \S+)*$';
UPDATE contributor SET role = regexp_replace(role, '\s+$', '', 'g') WHERE NOT role ~ '^\S+( \S+)*$';
UPDATE team_member SET role = regexp_replace(role, '\s+$', '', 'g') WHERE NOT role ~ '^\S+( \S+)*$';

UPDATE contributor SET affiliation = NULL WHERE affiliation ~ '^\s*$';
UPDATE team_member SET affiliation = NULL WHERE affiliation ~ '^\s*$';
UPDATE contributor SET affiliation = regexp_replace(affiliation, '\s{2,}', ' ', 'g') WHERE NOT affiliation ~ '^\S+( \S+)*$';
UPDATE team_member SET affiliation = regexp_replace(affiliation, '\s{2,}', ' ', 'g') WHERE NOT affiliation ~ '^\S+( \S+)*$';
UPDATE contributor SET affiliation = regexp_replace(affiliation, '^\s+', '', 'g') WHERE NOT affiliation ~ '^\S+( \S+)*$';
UPDATE team_member SET affiliation = regexp_replace(affiliation, '^\s+', '', 'g') WHERE NOT affiliation ~ '^\S+( \S+)*$';
UPDATE contributor SET affiliation = regexp_replace(affiliation, '\s+$', '', 'g') WHERE NOT affiliation ~ '^\S+( \S+)*$';
UPDATE team_member SET affiliation = regexp_replace(affiliation, '\s+$', '', 'g') WHERE NOT affiliation ~ '^\S+( \S+)*$';

drop function if exists "public"."category_paths_by_project_expanded"(project_id uuid);

drop function if exists "public"."category_paths_by_software_expanded"(software_id uuid);

-- end manually added

drop function if exists "public"."category_path_expanded"(category_id uuid);

drop function if exists "public"."software_keywords_filter"(search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."software_languages_filter"(search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."software_licenses_filter"(search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."category_path"(category_id uuid);

alter table "public"."contributor" add constraint "contributor_affiliation_check" CHECK (((affiliation)::text ~ '^\S+( \S+)*$'::text));

alter table "public"."contributor" add constraint "contributor_role_check" CHECK (((role)::text ~ '^\S+( \S+)*$'::text));

alter table "public"."team_member" add constraint "team_member_affiliation_check" CHECK (((affiliation)::text ~ '^\S+( \S+)*$'::text));

alter table "public"."team_member" add constraint "team_member_role_check" CHECK (((role)::text ~ '^\S+( \S+)*$'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.category_for_project_status(project_id uuid, category_id uuid)
 RETURNS character varying
 LANGUAGE sql
 STABLE
AS $function$
WITH
	category_data AS (SELECT organisation FROM category WHERE category.id = category_id)
SELECT
	CASE
		WHEN (SELECT organisation FROM category_data) IS NULL THEN 'global'
		WHEN (SELECT organisation FROM category_data AS organisation_id) IS NOT NULL THEN (SELECT status FROM project_for_organisation WHERE project_for_organisation.project = project_id AND project_for_organisation.organisation = (SELECT organisation FROM category_data AS organisation_id))::VARCHAR
		ELSE 'other'
		END
$function$
;

CREATE OR REPLACE FUNCTION public.category_for_software_status(software_id uuid, category_id uuid)
 RETURNS character varying
 LANGUAGE sql
 STABLE
AS $function$
WITH
	category_data AS (SELECT organisation, community FROM category WHERE category.id = category_id)
SELECT
	CASE
		WHEN (SELECT organisation FROM category_data) IS NULL AND (SELECT community FROM category_data) IS NULL THEN 'global'
		WHEN (SELECT organisation FROM category_data AS organisation_id) IS NOT NULL THEN (SELECT status FROM software_for_organisation WHERE software_for_organisation.software = software_id AND software_for_organisation.organisation = (SELECT organisation FROM category_data AS organisation_id))::VARCHAR
		WHEN (SELECT community FROM category_data) IS NOT NULL THEN (SELECT status FROM software_for_community WHERE software_for_community.software = software_id AND software_for_community.community = (SELECT community FROM category_data))::VARCHAR
		ELSE 'other'
		END
$function$
;

CREATE OR REPLACE FUNCTION public.category_path(category_id uuid)
 RETURNS TABLE(id uuid, parent uuid, community uuid, organisation uuid, short_name character varying, name character varying, properties jsonb, provenance_iri character varying)
 LANGUAGE sql
 STABLE
AS $function$
	WITH RECURSIVE cat_path AS (
		SELECT *, 1 AS r_index
			FROM category WHERE id = category_id
	UNION ALL
		SELECT category.*, cat_path.r_index+1
			FROM category
			JOIN cat_path
		ON category.id = cat_path.parent
	)
	-- 1. How can we reverse the output rows without injecting a new column (r_index)?
	-- 2. How a table row "type" could be used here Now we have to list all columns of `category` explicitly
	--    I want to have something like `* without 'r_index'` to be independent from modifications of `category`
	-- 3. Maybe this could be improved by using SEARCH keyword.
	SELECT id, parent, community, organisation, short_name, name, properties, provenance_iri
	FROM cat_path
	ORDER BY r_index DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.category_paths_by_project_expanded(project_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT COALESCE(jsonb_agg(paths.content),  jsonb_build_array())::JSONB FROM (
	SELECT ARRAY_AGG(rows) AS content FROM (
		SELECT category_for_project.category_id, category_path.*, category_for_project_status AS status
		FROM category_for_project
		INNER JOIN category_path(category_for_project.category_id) ON TRUE
		INNER JOIN category_for_project_status(category_paths_by_project_expanded.project_id, category_path.id) ON TRUE
		WHERE category_for_project.project_id = category_paths_by_project_expanded.project_id
	) AS rows
	GROUP BY rows.category_id
) AS paths
$function$
;

CREATE OR REPLACE FUNCTION public.category_paths_by_software_expanded(software_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
SELECT COALESCE(jsonb_agg(paths.content),  jsonb_build_array())::JSONB FROM (
	SELECT ARRAY_AGG(rows) AS content FROM (
		SELECT category_for_software.category_id, category_path.*, category_for_software_status AS status
		FROM category_for_software
		INNER JOIN category_path(category_for_software.category_id) ON TRUE
		INNER JOIN category_for_software_status(category_paths_by_software_expanded.software_id, category_path.id) ON TRUE
		WHERE category_for_software.software_id = category_paths_by_software_expanded.software_id
	) AS rows
	GROUP BY rows.category_id
) AS paths
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_categories(community_id uuid)
 RETURNS TABLE(software uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_software.software_id AS software,
		ARRAY_AGG(
			DISTINCT category_path.short_name
			ORDER BY category_path.short_name
		) AS category
	FROM
		category_for_software
	INNER JOIN
		category_path(category_for_software.category_id) ON TRUE
	WHERE
		category_path.community = community_id
	GROUP BY
		category_for_software.software_id;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_categories(organisation_id uuid)
 RETURNS TABLE(project uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_project.project_id AS project,
		ARRAY_AGG(
			DISTINCT category_path.short_name
			ORDER BY category_path.short_name
		) AS category
	FROM
		category_for_project
	INNER JOIN
		category_path(category_for_project.category_id) ON TRUE
	WHERE
		category_path.organisation = organisation_id
	GROUP BY
		category_for_project.project_id;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_categories(organisation_id uuid)
 RETURNS TABLE(software uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_software.software_id AS software,
		ARRAY_AGG(
			DISTINCT category_path.short_name
			ORDER BY category_path.short_name
		) AS category
	FROM
		category_for_software
	INNER JOIN
		category_path(category_for_software.category_id) ON TRUE
	WHERE
		category_path.organisation = organisation_id
	GROUP BY
		category_for_software.software_id;
$function$
;

CREATE OR REPLACE FUNCTION public.software_categories()
 RETURNS TABLE(software uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_software.software_id AS software,
		ARRAY_AGG(
			DISTINCT category_path.short_name
			ORDER BY category_path.short_name
		) AS category
	FROM
		category_for_software
	INNER JOIN
		category_path(category_for_software.category_id) ON TRUE
	WHERE
	-- FILTER FOR GLOBAL CATEGORIES
		category_path.community IS NULL AND category_path.organisation IS NULL
	GROUP BY
		category_for_software.software_id;
$function$
;

