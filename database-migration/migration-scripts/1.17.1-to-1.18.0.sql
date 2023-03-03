---------- CREATED BY MIGRA ----------

drop policy "maintainer_delete" on "public"."invite_maintainer_for_organisation";

drop policy "maintainer_select" on "public"."invite_maintainer_for_organisation";

drop policy "maintainer_delete" on "public"."invite_maintainer_for_project";

drop policy "maintainer_select" on "public"."invite_maintainer_for_project";

drop policy "maintainer_delete" on "public"."invite_maintainer_for_software";

drop policy "maintainer_select" on "public"."invite_maintainer_for_software";

drop function if exists "public"."organisation_route"(id uuid, OUT organisation uuid, OUT rsd_path character varying, OUT parent_names character varying);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_account(account_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE account_authenticated UUID;
BEGIN
	IF
		account_id IS NULL
	THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide an account id';
	END IF;
	account_authenticated = uuid(current_setting('request.jwt.claims', TRUE)::json->>'account');
	IF
			CURRENT_USER IS DISTINCT FROM 'rsd_admin'
		AND
			(SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) IS DISTINCT FROM TRUE
		AND
			(
				account_authenticated IS NULL OR account_authenticated IS DISTINCT FROM account_id
			)
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this account';
	END IF;
	DELETE FROM maintainer_for_software WHERE maintainer = account_id;
	DELETE FROM maintainer_for_project WHERE maintainer = account_id;
	DELETE FROM maintainer_for_organisation WHERE maintainer = account_id;
	DELETE FROM invite_maintainer_for_software WHERE created_by = account_id OR claimed_by = account_id;
	DELETE FROM invite_maintainer_for_project WHERE created_by = account_id OR claimed_by = account_id;
	DELETE FROM invite_maintainer_for_organisation WHERE created_by = account_id OR claimed_by = account_id;
	UPDATE organisation SET primary_maintainer = NULL WHERE primary_maintainer = account_id;
	DELETE FROM login_for_account WHERE account = account_id;
	DELETE FROM account WHERE id = account_id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.organisation_route(id uuid)
 RETURNS TABLE(organisation uuid, rsd_path character varying, parent_names character varying)
 LANGUAGE sql
 STABLE
AS $function$
WITH RECURSIVE search_tree(slug, name, organisation_id, parent, reverse_depth) AS (
		SELECT o.slug, o.name, o.id, o.parent, 1
		FROM organisation o WHERE o.id = organisation_route.id
	UNION ALL
		SELECT o.slug, o.name, o.id, o.parent, st.reverse_depth + 1
		FROM organisation o, search_tree st
		WHERE o.id = st.parent
)
SELECT organisation_route.id, STRING_AGG(slug, '/' ORDER BY reverse_depth DESC), STRING_AGG(name, ' -> ' ORDER BY reverse_depth DESC) FROM search_tree;
$function$
;

create or replace view "public"."user_count_per_home_organisation" as  SELECT login_for_account.home_organisation,
    count(*) AS count
   FROM login_for_account
  GROUP BY login_for_account.home_organisation;


CREATE OR REPLACE FUNCTION public.children_count_by_organisation()
 RETURNS TABLE(parent uuid, children_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	organisation.parent, COUNT(*) AS children_cnt
FROM
	organisation
WHERE
	organisation.parent IS NOT NULL
GROUP BY
	organisation.parent
;
$function$
;

CREATE OR REPLACE FUNCTION public.homepage_counts(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT contributor_cnt bigint, OUT software_mention_cnt bigint)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	SELECT COUNT(id) FROM software INTO software_cnt;
	SELECT COUNT(id) FROM project INTO project_cnt;
	SELECT
		COUNT(id) AS organisation_cnt
	FROM
		organisations_overview(TRUE)
	WHERE
		organisations_overview.parent IS NULL AND organisations_overview.score>0
	INTO organisation_cnt;
	SELECT COUNT(display_name) FROM unique_contributors() INTO contributor_cnt;
	SELECT COUNT(mention) FROM mention_for_software INTO software_mention_cnt;
END
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_count_for_projects()
 RETURNS TABLE(id uuid, keyword citext, cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_count.cnt
	FROM
		keyword
	LEFT JOIN
		(SELECT
				keyword_for_project.keyword,
				COUNT(keyword_for_project.keyword) AS cnt
			FROM
				keyword_for_project
			GROUP BY keyword_for_project.keyword
		) AS keyword_count ON keyword.id = keyword_count.keyword
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_count_for_software()
 RETURNS TABLE(id uuid, keyword citext, cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_count.cnt
	FROM
		keyword
	LEFT JOIN
		(SELECT
				keyword_for_software.keyword,
				COUNT(keyword_for_software.keyword) AS cnt
			FROM
				keyword_for_software
			GROUP BY keyword_for_software.keyword
		) AS keyword_count ON keyword.id = keyword_count.keyword
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.list_child_organisations(parent_id uuid)
 RETURNS TABLE(organisation_id uuid, organisation_name character varying)
 LANGUAGE sql
 STABLE
AS $function$
WITH RECURSIVE search_tree(id, name) AS (
		SELECT o.id, o.name
		FROM organisation o WHERE id = parent_id
	UNION ALL
		SELECT o.id, o.name
		FROM organisation o, search_tree st
		WHERE o.parent = st.id
)
SELECT * FROM search_tree;
$function$
;

CREATE OR REPLACE FUNCTION public.list_parent_organisations(id uuid)
 RETURNS TABLE(slug character varying, organisation_id uuid)
 LANGUAGE sql
 STABLE
AS $function$
WITH RECURSIVE search_tree(slug, organisation_id, parent) AS (
		SELECT o.slug, o.id, o.parent
		FROM organisation o WHERE o.id = list_parent_organisations.id
	UNION ALL
		SELECT o.slug, o.id, o.parent
		FROM organisation o, search_tree st
		WHERE o.id = st.parent
)
SELECT slug, organisation_id FROM search_tree;
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, ror_id character varying, website character varying, is_tenant boolean, rsd_path character varying, parent_names character varying, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, release_cnt bigint, score bigint)
 LANGUAGE sql
 STABLE
AS $function$
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
			ARRAY_AGG(p_lang)
		FROM
			JSONB_OBJECT_KEYS(repository_url.languages) p_lang
		) AS "prog_lang"
	FROM
		repository_url
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, project_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	list_parent_organisations.organisation_id,
	COUNT(DISTINCT project_for_organisation.project) AS project_cnt
FROM
	project_for_organisation
CROSS JOIN list_parent_organisations(project_for_organisation.organisation)
WHERE
		(NOT public)
	OR
		(
			status = 'approved'
		AND
			project IN (SELECT id FROM project WHERE is_published)
		)
GROUP BY list_parent_organisations.organisation_id;
$function$
;

CREATE OR REPLACE FUNCTION public.release_cnt_by_organisation()
 RETURNS TABLE(organisation_id uuid, release_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.releases_by_organisation()
 RETURNS TABLE(organisation_id uuid, software_id uuid, software_slug character varying, software_name character varying, release_doi citext, release_tag character varying, release_date timestamp with time zone, release_year smallint, release_authors character varying)
 LANGUAGE sql
 STABLE
AS $function$
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
$function$
;

CREATE OR REPLACE FUNCTION public.research_domain_count_for_projects()
 RETURNS TABLE(id uuid, key character varying, name character varying, cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		research_domain.id,
		research_domain.key,
		research_domain.name,
		research_domain_count.cnt
	FROM
		research_domain
	LEFT JOIN
		(SELECT
				research_domain_for_project.research_domain,
				COUNT(research_domain_for_project.research_domain) AS cnt
			FROM
				research_domain_for_project
			GROUP BY research_domain_for_project.research_domain
		) AS research_domain_count ON research_domain.id = research_domain_count.research_domain
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, software_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	list_parent_organisations.organisation_id,
	COUNT(DISTINCT software_for_organisation.software) AS software_cnt
FROM
	software_for_organisation
CROSS JOIN list_parent_organisations(software_for_organisation.organisation)
WHERE
		(NOT public)
	OR
		(
			software_for_organisation.status = 'approved'
		AND
		 	software IN (SELECT id FROM software WHERE is_published)
		)
GROUP BY list_parent_organisations.organisation_id;
$function$
;

create policy "maintainer_delete"
on "public"."invite_maintainer_for_organisation"
as permissive
for delete
to rsd_user
using (((organisation IN ( SELECT organisations_of_current_maintainer.organisations_of_current_maintainer
   FROM organisations_of_current_maintainer() organisations_of_current_maintainer(organisations_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


create policy "maintainer_select"
on "public"."invite_maintainer_for_organisation"
as permissive
for select
to rsd_user
using (((organisation IN ( SELECT organisations_of_current_maintainer.organisations_of_current_maintainer
   FROM organisations_of_current_maintainer() organisations_of_current_maintainer(organisations_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


create policy "maintainer_delete"
on "public"."invite_maintainer_for_project"
as permissive
for delete
to rsd_user
using (((project IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


create policy "maintainer_select"
on "public"."invite_maintainer_for_project"
as permissive
for select
to rsd_user
using (((project IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


create policy "maintainer_delete"
on "public"."invite_maintainer_for_software"
as permissive
for delete
to rsd_user
using (((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


create policy "maintainer_select"
on "public"."invite_maintainer_for_software"
as permissive
for select
to rsd_user
using (((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


