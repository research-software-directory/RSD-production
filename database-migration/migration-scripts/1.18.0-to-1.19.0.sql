---------- CREATED BY MIGRA ----------

create type "public"."package_manager_type" as enum ('anaconda', 'cran', 'dockerhub', 'maven', 'npm', 'pypi', 'other');

create table "public"."package_manager" (
    "id" uuid not null,
    "software" uuid not null,
    "url" character varying(200) not null,
    "package_manager" package_manager_type not null default 'other'::package_manager_type,
    "download_count" bigint,
    "download_count_scraped_at" timestamp with time zone,
    "reverse_dependency_count" integer,
    "reverse_dependency_count_scraped_at" timestamp with time zone,
    "position" integer,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."package_manager" enable row level security;

alter table "public"."repository_url" drop column "license_scraped_at";

alter table "public"."repository_url" add column "basic_data_scraped_at" timestamp with time zone;

alter table "public"."repository_url" add column "contributor_count" integer;

alter table "public"."repository_url" add column "contributor_count_scraped_at" timestamp with time zone;

alter table "public"."repository_url" add column "fork_count" integer;

alter table "public"."repository_url" add column "open_issue_count" integer;

alter table "public"."repository_url" add column "star_count" bigint;

CREATE UNIQUE INDEX package_manager_pkey ON public.package_manager USING btree (id);

alter table "public"."package_manager" add constraint "package_manager_pkey" PRIMARY KEY using index "package_manager_pkey";

alter table "public"."package_manager" add constraint "package_manager_software_fkey" FOREIGN KEY (software) REFERENCES software(id);

alter table "public"."package_manager" add constraint "package_manager_url_check" CHECK (((url)::text ~ '^https?://'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.count_project_impact()
 RETURNS TABLE(project uuid, impact_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	impact_for_project.project,
	COUNT(impact_for_project.mention)
FROM
	impact_for_project
GROUP BY
	impact_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.count_project_keywords()
 RETURNS TABLE(project uuid, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	keyword_for_project.project,
	COUNT(keyword_for_project.keyword)
FROM
	keyword_for_project
GROUP BY
	keyword_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.count_project_organisations()
 RETURNS TABLE(project uuid, participating_org_cnt integer, funding_org_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project_for_organisation.project,
	COUNT(CASE WHEN project_for_organisation.role = 'participating' THEN 1 END),
	COUNT(CASE WHEN project_for_organisation.role = 'funding' THEN 1 END)
FROM
	project_for_organisation
WHERE
	project_for_organisation.status = 'approved'
GROUP BY
	project_for_organisation.project;
$function$
;

CREATE OR REPLACE FUNCTION public.count_project_output()
 RETURNS TABLE(project uuid, output_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	output_for_project.project,
	COUNT(output_for_project.mention)
FROM
	output_for_project
GROUP BY
	output_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.count_project_research_domains()
 RETURNS TABLE(project uuid, research_domain_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	research_domain_for_project.project,
	COUNT(research_domain_for_project.research_domain)
FROM
	research_domain_for_project
GROUP BY
	research_domain_for_project.project;
$function$
;

CREATE OR REPLACE FUNCTION public.count_project_team_members()
 RETURNS TABLE(project uuid, team_member_cnt integer, has_contact_person boolean)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	team_member.project,
	COUNT(team_member.id),
	BOOL_OR(team_member.is_contact_person)
FROM
	team_member
GROUP BY
	team_member.project;
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_cnt()
 RETURNS TABLE(id uuid, keyword citext, software_cnt bigint, projects_cnt bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
SELECT
	keyword.id,
	keyword.value AS keyword,
	keyword_count_for_software.cnt AS software_cnt,
	keyword_count_for_projects.cnt AS projects_cnt
FROM
	keyword
LEFT JOIN
	keyword_count_for_software() ON keyword.value = keyword_count_for_software.keyword
LEFT JOIN
	keyword_count_for_projects() ON keyword.value = keyword_count_for_projects.keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.new_accounts_count_since_timestamp(timestmp timestamp with time zone)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
SELECT
	COUNT(account.created_at)
FROM
	account
WHERE
	created_at > timestmp;
$function$
;

CREATE OR REPLACE FUNCTION public.project_quality(show_all boolean DEFAULT false)
 RETURNS TABLE(slug character varying, title character varying, has_subtitle boolean, is_published boolean, has_start_date boolean, has_end_date boolean, has_image boolean, team_member_cnt integer, has_contact_person boolean, participating_org_cnt integer, funding_org_cnt integer, keyword_cnt integer, research_domain_cnt integer, impact_cnt integer, output_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.slug,
	project.title,
	project.subtitle IS NOT NULL,
	project.is_published,
	project.date_start IS NOT NULL,
	project.date_end IS NOT NULL,
	project.image_id IS NOT NULL,
	COALESCE(count_project_team_members.team_member_cnt, 0),
	COALESCE(count_project_team_members.has_contact_person, FALSE),
	COALESCE(count_project_organisations.participating_org_cnt, 0),
	COALESCE(count_project_organisations.funding_org_cnt, 0),
	COALESCE(count_project_keywords.keyword_cnt, 0),
	COALESCE(count_project_research_domains.research_domain_cnt, 0),
	COALESCE(count_project_impact.impact_cnt, 0),
	COALESCE(count_project_output.output_cnt, 0)
FROM
	project
LEFT JOIN
	count_project_team_members() ON project.id = count_project_team_members.project
LEFT JOIN
	count_project_organisations() ON project.id = count_project_organisations.project
LEFT JOIN
	count_project_keywords() ON project.id = count_project_keywords.project
LEFT JOIN
	count_project_research_domains() ON project.id = count_project_research_domains.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
WHERE
	CASE WHEN show_all IS TRUE THEN TRUE ELSE project.id IN (SELECT * FROM projects_of_current_maintainer()) END;
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_package_manager()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_package_manager()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.software = old.software;
	-- NEW.url = old.url;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
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
$function$
;

CREATE OR REPLACE FUNCTION public.releases_by_organisation()
 RETURNS TABLE(organisation_id uuid, software_id uuid, software_slug character varying, software_name character varying, release_doi citext, release_tag character varying, release_date timestamp with time zone, release_year smallint, release_authors character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT
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

create policy "admin_all_rights"
on "public"."package_manager"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."package_manager"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "maintainer_all_rights"
on "public"."package_manager"
as permissive
for all
to rsd_user
using ((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))))
with check (software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer)));


CREATE TRIGGER check_package_manager_before_delete BEFORE DELETE ON public.package_manager FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_package_manager_before_insert BEFORE INSERT ON public.package_manager FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_package_manager_before_update BEFORE UPDATE ON public.package_manager FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_package_manager BEFORE INSERT ON public.package_manager FOR EACH ROW EXECUTE FUNCTION sanitise_insert_package_manager();

CREATE TRIGGER sanitise_update_package_manager BEFORE UPDATE ON public.package_manager FOR EACH ROW EXECUTE FUNCTION sanitise_update_package_manager();
