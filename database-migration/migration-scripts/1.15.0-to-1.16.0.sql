---------- CREATED BY MIGRA ----------

drop trigger if exists "sanitise_insert_release" on "public"."release";

drop trigger if exists "sanitise_update_release" on "public"."release";

drop trigger if exists "sanitise_insert_release_content" on "public"."release_content";

drop trigger if exists "sanitise_update_release_content" on "public"."release_content";

drop policy "admin_all_rights" on "public"."release_content";

drop policy "anyone_can_read" on "public"."release_content";

drop policy "maintainer_select" on "public"."release_content";

drop policy "anyone_can_read" on "public"."mention";

alter table "public"."release" drop constraint "release_software_key";

alter table "public"."release_content" drop constraint "release_content_doi_check";

alter table "public"."release_content" drop constraint "release_content_doi_key";

alter table "public"."release_content" drop constraint "release_content_release_id_fkey";

drop function if exists "public"."organisation_route"(id uuid, OUT organisation uuid, OUT rsd_path character varying);

drop function if exists "public"."sanitise_insert_release"();

drop function if exists "public"."sanitise_insert_release_content"();

drop function if exists "public"."sanitise_update_release"();

drop function if exists "public"."sanitise_update_release_content"();

drop function if exists "public"."list_child_organisations"(parent_id uuid);

drop function if exists "public"."organisations_overview"(public boolean);

drop function if exists "public"."software_join_release"();

alter table "public"."release_content" drop constraint "release_content_pkey";

alter table "public"."release" drop constraint "release_pkey";

drop index if exists "public"."release_content_doi_key";

drop index if exists "public"."release_content_pkey";

drop index if exists "public"."release_software_key";

drop index if exists "public"."release_pkey";

drop table "public"."release_content";

create table "public"."release_version" (
    "release_id" uuid not null,
    "mention_id" uuid not null
);


alter table "public"."release_version" enable row level security;

alter table "public"."account" add column "agree_terms" boolean not null default false;

alter table "public"."account" add column "agree_terms_updated_at" timestamp with time zone;

alter table "public"."account" add column "notice_privacy_statement" boolean not null default false;

alter table "public"."account" add column "notice_privacy_statement_updated_at" timestamp with time zone;

alter table "public"."mention" add column "publication_date" date;

alter table "public"."mention" add column "version" character varying(100);

alter table "public"."release" drop column "created_at";

alter table "public"."release" drop column "id";

alter table "public"."release" drop column "is_citable";

alter table "public"."release" drop column "latest_schema_dot_org";

alter table "public"."release" drop column "updated_at";

drop type "public"."citability";

CREATE UNIQUE INDEX release_version_pkey ON public.release_version USING btree (release_id, mention_id);

CREATE UNIQUE INDEX release_pkey ON public.release USING btree (software);

alter table "public"."release_version" add constraint "release_version_pkey" PRIMARY KEY using index "release_version_pkey";

alter table "public"."release" add constraint "release_pkey" PRIMARY KEY using index "release_pkey";

alter table "public"."release_version" add constraint "release_version_mention_id_fkey" FOREIGN KEY (mention_id) REFERENCES mention(id);

alter table "public"."release_version" add constraint "release_version_release_id_fkey" FOREIGN KEY (release_id) REFERENCES release(software);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.check_user_agreement_on_action()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	IF
		CURRENT_USER <> 'rsd_admin' AND NOT
		(SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) AND
		(SELECT * FROM user_agreements_stored(uuid(current_setting('request.jwt.claims', FALSE)::json->>'account'))) = FALSE
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You need to agree to our Terms of Service and the Privacy Statement before proceeding. Please open your user profile settings to agree.';
	ELSE
		RETURN NEW;
	END IF;
END
$function$
;

CREATE OR REPLACE FUNCTION public.check_user_agreement_on_delete_action()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	IF
		CURRENT_USER <> 'rsd_admin' AND NOT
		(SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) AND
		(SELECT * FROM user_agreements_stored(uuid(current_setting('request.jwt.claims', FALSE)::json->>'account'))) = FALSE
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You need to agree to our Terms of Service and the Privacy Statement before proceeding. Please open your user profile settings to agree.';
	ELSE
		RETURN OLD;
	END IF;
END
$function$
;

CREATE OR REPLACE PROCEDURE public.check_user_agreement_on_delete_all_tables()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
	_sql VARCHAR;
BEGIN
	FOR _sql IN SELECT CONCAT (
		'CREATE TRIGGER check_',
		quote_ident(table_name),
		'_before_delete BEFORE DELETE ON ',
		quote_ident(table_name),
		' FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();'
	)
	FROM
		information_schema.tables
	WHERE
		table_schema = 'public' AND
		table_name NOT IN ('account', 'login_for_account')
	LOOP
		EXECUTE _sql;
	END LOOP;
END
$procedure$
;

CREATE OR REPLACE PROCEDURE public.check_user_agreement_on_insert_all_tables()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
	_sql VARCHAR;
BEGIN
	FOR _sql IN SELECT CONCAT (
		'CREATE TRIGGER check_',
		quote_ident(table_name),
		'_before_insert BEFORE INSERT ON ',
		quote_ident(table_name),
		' FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();'
	)
	FROM
		information_schema.tables
	WHERE
		table_schema = 'public' AND
		table_name NOT IN ('account', 'login_for_account')
	LOOP
		EXECUTE _sql;
	END LOOP;
END
$procedure$
;

CREATE OR REPLACE PROCEDURE public.check_user_agreement_on_update_all_tables()
 LANGUAGE plpgsql
AS $procedure$
DECLARE
	_sql VARCHAR;
BEGIN
	FOR _sql IN SELECT CONCAT (
		'CREATE TRIGGER check_',
		quote_ident(table_name),
		'_before_update BEFORE UPDATE ON ',
		quote_ident(table_name),
		' FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();'
	)
	FROM
		information_schema.tables
	WHERE
		table_schema = 'public' AND
		table_name NOT IN ('account', 'login_for_account')
	LOOP
		EXECUTE _sql;
	END LOOP;
END
$procedure$
;

CREATE OR REPLACE FUNCTION public.organisation_route(id uuid, OUT organisation uuid, OUT rsd_path character varying, OUT parent_names character varying)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
	current_org UUID := id;
	route VARCHAR := '';
	slug VARCHAR;
	names VARCHAR :=  '';
	current_name VARCHAR;
BEGIN
	WHILE current_org IS NOT NULL LOOP
		SELECT
			organisation.slug,
			organisation.parent,
			organisation.name
		FROM
			organisation
		WHERE
			organisation.id = current_org
		INTO slug, current_org, current_name;
--	combine paths in reverse order
		route := CONCAT(slug, '/', route);
		names := CONCAT(current_name, ' -> ', names);
	END LOOP;
	SELECT id, route, LEFT(names, -4) INTO organisation, rsd_path, parent_names;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.release_cnt_by_organisation()
 RETURNS TABLE(id uuid, slug character varying, release_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	SELECT
		organisations_of_software.id,
		organisations_of_software.slug,
		COUNT(*) AS release_cnt
	FROM
		"release"
	INNER JOIN
		release_version ON release_version.release_id="release".software
	INNER JOIN
		organisations_of_software("release".software) ON "release".software = organisations_of_software.software
	GROUP BY
		organisations_of_software.id, organisations_of_software.slug
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_release()
 RETURNS TABLE(software_id uuid, software_slug character varying, software_name character varying, release_doi citext, release_tag character varying, release_date date, release_year smallint, release_authors character varying, organisation_slug character varying[])
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN RETURN QUERY
	SELECT
		software.id AS software_id,
		software.slug AS software_slug,
		software.brand_name AS software_name,
		mention.doi AS release_doi,
		mention.version AS release_tag,
		mention.publication_date AS release_date,
		mention.publication_year AS release_year,
		mention.authors AS release_authors,
		ARRAY_AGG(organisations_of_software.slug) AS organisation_slug
	FROM
		release_version
	INNER JOIN
		"release" ON "release".software = release_version.release_id
	INNER JOIN
		software ON software.id = "release".software
	INNER JOIN
		mention ON mention.id = release_version.mention_id
	LEFT JOIN
		organisations_of_software(software.id) ON software.id = organisations_of_software.software
	GROUP BY
		software_id, release_doi, release_tag, release_date, release_year, release_authors
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.user_agreements_stored(account_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN (
		SELECT (
			account.agree_terms = TRUE AND
			account.notice_privacy_statement = TRUE
		)
		FROM
			account
		WHERE
			account.id = account_id
	);
END
$function$
;

CREATE OR REPLACE FUNCTION public.list_child_organisations(parent_id uuid)
 RETURNS TABLE(organisation_id uuid, organisation_name character varying)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE child_organisations UUID[];
DECLARE child_names VARCHAR[];
DECLARE search_child_organisations UUID[]; -- used as a stack
DECLARE current_organisation UUID;
BEGIN
-- depth-first search to find all child organisations
	search_child_organisations = search_child_organisations || parent_id;
	WHILE CARDINALITY(search_child_organisations) > 0 LOOP
		current_organisation = search_child_organisations[CARDINALITY(search_child_organisations)];
		child_organisations = child_organisations || current_organisation;
		child_names = child_names || (SELECT name FROM organisation WHERE id = current_organisation);
		search_child_organisations = trim_array(search_child_organisations, 1);
		search_child_organisations = search_child_organisations || (SELECT ARRAY(SELECT organisation.id FROM organisation WHERE parent = current_organisation));
	END LOOP;
	RETURN QUERY SELECT * FROM UNNEST(child_organisations, child_names);
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
		release_cnt_by_organisation() ON release_cnt_by_organisation.id = organisation.id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_account()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	NEW.agree_terms_updated_at = NEW.created_at;
	NEW.notice_privacy_statement_updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_account()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	IF NEW.agree_terms != OLD.agree_terms THEN
		NEW.agree_terms_updated_at = NEW.updated_at;
	END IF;
	IF NEW.notice_privacy_statement != OLD.notice_privacy_statement THEN
		NEW.notice_privacy_statement_updated_at = NEW.updated_at;
	END IF;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_join_release()
 RETURNS TABLE(software_id uuid, slug character varying, concept_doi citext, versioned_dois citext[], releases_scraped_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
		SELECT software.id AS software_id, software.slug, software.concept_doi, ARRAY_AGG(mention.doi), release.releases_scraped_at
		FROM software
		LEFT JOIN release ON software.id = release.software
		LEFT JOIN release_version ON release_version.release_id = release.software
		LEFT JOIN mention ON release_version.mention_id = mention.id
		GROUP BY software.id, software.slug, software.concept_doi, release.software, release.releases_scraped_at;
	RETURN;
END
$function$
;

create policy "admin_all_rights"
on "public"."release_version"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."release_version"
as permissive
for select
to rsd_web_anon, rsd_user
using ((release_id IN ( SELECT release.software
   FROM release)));


create policy "maintainer_select"
on "public"."release_version"
as permissive
for select
to rsd_user
using ((release_id IN ( SELECT release.software
   FROM release)));


create policy "anyone_can_read"
on "public"."mention"
as permissive
for select
to rsd_web_anon, rsd_user
using (((id IN ( SELECT mention_for_software.mention
   FROM mention_for_software)) OR (id IN ( SELECT output_for_project.mention
   FROM output_for_project)) OR (id IN ( SELECT impact_for_project.mention
   FROM impact_for_project)) OR (id IN ( SELECT release_version.mention_id
   FROM release_version))));


CREATE TRIGGER check_contributor_before_delete BEFORE DELETE ON public.contributor FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_contributor_before_insert BEFORE INSERT ON public.contributor FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_contributor_before_update BEFORE UPDATE ON public.contributor FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_image_before_delete BEFORE DELETE ON public.image FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_image_before_insert BEFORE INSERT ON public.image FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_image_before_update BEFORE UPDATE ON public.image FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_impact_for_project_before_delete BEFORE DELETE ON public.impact_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_impact_for_project_before_insert BEFORE INSERT ON public.impact_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_impact_for_project_before_update BEFORE UPDATE ON public.impact_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_organisation_before_delete BEFORE DELETE ON public.invite_maintainer_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_invite_maintainer_for_organisation_before_insert BEFORE INSERT ON public.invite_maintainer_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_organisation_before_update BEFORE UPDATE ON public.invite_maintainer_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_project_before_delete BEFORE DELETE ON public.invite_maintainer_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_invite_maintainer_for_project_before_insert BEFORE INSERT ON public.invite_maintainer_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_project_before_update BEFORE UPDATE ON public.invite_maintainer_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_software_before_delete BEFORE DELETE ON public.invite_maintainer_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_invite_maintainer_for_software_before_insert BEFORE INSERT ON public.invite_maintainer_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_software_before_update BEFORE UPDATE ON public.invite_maintainer_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_before_delete BEFORE DELETE ON public.keyword FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_keyword_before_insert BEFORE INSERT ON public.keyword FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_before_update BEFORE UPDATE ON public.keyword FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_for_project_before_delete BEFORE DELETE ON public.keyword_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_keyword_for_project_before_insert BEFORE INSERT ON public.keyword_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_for_project_before_update BEFORE UPDATE ON public.keyword_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_for_software_before_delete BEFORE DELETE ON public.keyword_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_keyword_for_software_before_insert BEFORE INSERT ON public.keyword_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_for_software_before_update BEFORE UPDATE ON public.keyword_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_license_for_software_before_delete BEFORE DELETE ON public.license_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_license_for_software_before_insert BEFORE INSERT ON public.license_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_license_for_software_before_update BEFORE UPDATE ON public.license_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_organisation_before_delete BEFORE DELETE ON public.maintainer_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_maintainer_for_organisation_before_insert BEFORE INSERT ON public.maintainer_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_organisation_before_update BEFORE UPDATE ON public.maintainer_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_project_before_delete BEFORE DELETE ON public.maintainer_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_maintainer_for_project_before_insert BEFORE INSERT ON public.maintainer_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_project_before_update BEFORE UPDATE ON public.maintainer_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_software_before_delete BEFORE DELETE ON public.maintainer_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_maintainer_for_software_before_insert BEFORE INSERT ON public.maintainer_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_software_before_update BEFORE UPDATE ON public.maintainer_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_mention_before_delete BEFORE DELETE ON public.mention FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_mention_before_insert BEFORE INSERT ON public.mention FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_mention_before_update BEFORE UPDATE ON public.mention FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_mention_for_software_before_delete BEFORE DELETE ON public.mention_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_mention_for_software_before_insert BEFORE INSERT ON public.mention_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_mention_for_software_before_update BEFORE UPDATE ON public.mention_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_meta_pages_before_delete BEFORE DELETE ON public.meta_pages FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_meta_pages_before_insert BEFORE INSERT ON public.meta_pages FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_meta_pages_before_update BEFORE UPDATE ON public.meta_pages FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_oaipmh_before_delete BEFORE DELETE ON public.oaipmh FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_oaipmh_before_insert BEFORE INSERT ON public.oaipmh FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_oaipmh_before_update BEFORE UPDATE ON public.oaipmh FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_orcid_whitelist_before_delete BEFORE DELETE ON public.orcid_whitelist FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_orcid_whitelist_before_insert BEFORE INSERT ON public.orcid_whitelist FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_orcid_whitelist_before_update BEFORE UPDATE ON public.orcid_whitelist FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_organisation_before_delete BEFORE DELETE ON public.organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_organisation_before_insert BEFORE INSERT ON public.organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_organisation_before_update BEFORE UPDATE ON public.organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_output_for_project_before_delete BEFORE DELETE ON public.output_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_output_for_project_before_insert BEFORE INSERT ON public.output_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_output_for_project_before_update BEFORE UPDATE ON public.output_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_project_before_delete BEFORE DELETE ON public.project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_project_before_insert BEFORE INSERT ON public.project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_project_before_update BEFORE UPDATE ON public.project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_project_for_organisation_before_delete BEFORE DELETE ON public.project_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_project_for_organisation_before_insert BEFORE INSERT ON public.project_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_project_for_organisation_before_update BEFORE UPDATE ON public.project_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_project_for_project_before_delete BEFORE DELETE ON public.project_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_project_for_project_before_insert BEFORE INSERT ON public.project_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_project_for_project_before_update BEFORE UPDATE ON public.project_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_release_before_delete BEFORE DELETE ON public.release FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_release_before_insert BEFORE INSERT ON public.release FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_release_before_update BEFORE UPDATE ON public.release FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_release_version_before_delete BEFORE DELETE ON public.release_version FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_release_version_before_insert BEFORE INSERT ON public.release_version FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_release_version_before_update BEFORE UPDATE ON public.release_version FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_repository_url_before_delete BEFORE DELETE ON public.repository_url FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_repository_url_before_insert BEFORE INSERT ON public.repository_url FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_repository_url_before_update BEFORE UPDATE ON public.repository_url FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_research_domain_before_delete BEFORE DELETE ON public.research_domain FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_research_domain_before_insert BEFORE INSERT ON public.research_domain FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_research_domain_before_update BEFORE UPDATE ON public.research_domain FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_research_domain_for_project_before_delete BEFORE DELETE ON public.research_domain_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_research_domain_for_project_before_insert BEFORE INSERT ON public.research_domain_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_research_domain_for_project_before_update BEFORE UPDATE ON public.research_domain_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_before_delete BEFORE DELETE ON public.software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_software_before_insert BEFORE INSERT ON public.software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_before_update BEFORE UPDATE ON public.software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_organisation_before_delete BEFORE DELETE ON public.software_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_software_for_organisation_before_insert BEFORE INSERT ON public.software_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_organisation_before_update BEFORE UPDATE ON public.software_for_organisation FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_project_before_delete BEFORE DELETE ON public.software_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_software_for_project_before_insert BEFORE INSERT ON public.software_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_project_before_update BEFORE UPDATE ON public.software_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_software_before_delete BEFORE DELETE ON public.software_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_software_for_software_before_insert BEFORE INSERT ON public.software_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_software_before_update BEFORE UPDATE ON public.software_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_team_member_before_delete BEFORE DELETE ON public.team_member FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_team_member_before_insert BEFORE INSERT ON public.team_member FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_team_member_before_update BEFORE UPDATE ON public.team_member FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_testimonial_before_delete BEFORE DELETE ON public.testimonial FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_testimonial_before_insert BEFORE INSERT ON public.testimonial FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_testimonial_before_update BEFORE UPDATE ON public.testimonial FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_url_for_project_before_delete BEFORE DELETE ON public.url_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_url_for_project_before_insert BEFORE INSERT ON public.url_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_url_for_project_before_update BEFORE UPDATE ON public.url_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

