---------- CREATED BY MIGRA ----------

drop materialized view if exists "public"."count_software_mentions_cached";

drop function if exists "public"."project_quality"(show_all boolean);

alter table "public"."package_manager" alter column "package_manager" drop default;

alter table "public"."repository_url" alter column "code_platform" drop default;

alter type "public"."package_manager_type" rename to "package_manager_type__old_version_to_be_dropped";

create type "public"."package_manager_type" as enum ('anaconda', 'bioconductor', 'chocolatey', 'cran', 'crates', 'debian', 'dockerhub', 'fourtu', 'ghcr', 'github', 'gitlab', 'golang', 'julia', 'maven', 'npm', 'pixi', 'pypi', 'snapcraft', 'sonatype', 'other');

alter type "public"."platform_type" rename to "platform_type__old_version_to_be_dropped";

create type "public"."platform_type" as enum ('github', 'gitlab', 'bitbucket', '4tu', 'codeberg', 'other');

alter table "public"."package_manager" alter column package_manager type "public"."package_manager_type" using package_manager::text::"public"."package_manager_type";

alter table "public"."repository_url" alter column code_platform type "public"."platform_type" using code_platform::text::"public"."platform_type";

alter table "public"."package_manager" alter column "package_manager" set default 'other'::package_manager_type;

alter table "public"."repository_url" alter column "code_platform" set default 'other'::platform_type;

drop type "public"."package_manager_type__old_version_to_be_dropped";

drop type "public"."platform_type__old_version_to_be_dropped";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.count_project_categories()
 RETURNS TABLE(project uuid, category_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
WITH project_category_paths AS (
	SELECT *
	FROM
		category_for_project
	INNER JOIN category_path(category_for_project.category_id) ON TRUE
)
SELECT
	category_for_project.project_id,
	COUNT(category_for_project.category_id)
FROM
	category_for_project
WHERE
	NOT EXISTS (SELECT * FROM project_category_paths WHERE project_category_paths.parent = category_for_project.category_id AND project_category_paths.project_id = category_for_project.project_id)
GROUP BY category_for_project.project_id
$function$
;

create materialized view "public"."count_software_mentions_cached" as  SELECT count_software_mentions.software,
    count_software_mentions.mention_cnt
   FROM count_software_mentions() count_software_mentions(software, mention_cnt);


CREATE OR REPLACE FUNCTION public.project_quality(show_all boolean DEFAULT false)
 RETURNS TABLE(slug character varying, title character varying, has_subtitle boolean, is_published boolean, date_start date, date_end date, grant_id character varying, has_image boolean, team_member_cnt integer, has_contact_person boolean, participating_org_cnt integer, funding_org_cnt integer, software_cnt integer, project_cnt integer, keyword_cnt integer, research_domain_cnt integer, impact_cnt integer, output_cnt integer, category_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project.slug,
	project.title,
	project.subtitle IS NOT NULL,
	project.is_published,
	project.date_start,
	project.date_end,
	project.grant_id,
	project.image_id IS NOT NULL,
	COALESCE(count_project_team_members.team_member_cnt, 0),
	COALESCE(count_project_team_members.has_contact_person, FALSE),
	COALESCE(count_project_organisations.participating_org_cnt, 0),
	COALESCE(count_project_organisations.funding_org_cnt, 0),
	COALESCE(count_project_related_software.software_cnt, 0),
	COALESCE(count_project_related_projects.project_cnt, 0),
	COALESCE(count_project_keywords.keyword_cnt, 0),
	COALESCE(count_project_research_domains.research_domain_cnt, 0),
	COALESCE(count_project_impact.impact_cnt, 0),
	COALESCE(count_project_output.output_cnt, 0),
	COALESCE(count_project_categories.category_cnt, 0)
FROM
	project
LEFT JOIN
	count_project_team_members() ON project.id = count_project_team_members.project
LEFT JOIN
	count_project_organisations() ON project.id = count_project_organisations.project
LEFT JOIN
	count_project_related_software() ON project.id = count_project_related_software.project
LEFT JOIN
	count_project_related_projects() ON project.id = count_project_related_projects.project
LEFT JOIN
	count_project_keywords() ON project.id = count_project_keywords.project
LEFT JOIN
	count_project_research_domains() ON project.id = count_project_research_domains.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
LEFT JOIN
	count_project_categories() ON project.id = count_project_categories.project
WHERE
	CASE WHEN show_all IS TRUE THEN TRUE ELSE project.id IN (SELECT * FROM projects_of_current_maintainer()) END;
$function$
;

create or replace view "public"."user_count_per_home_organisation" as  SELECT login_for_account.home_organisation,
    count(*) AS count
   FROM login_for_account
  GROUP BY login_for_account.home_organisation;


