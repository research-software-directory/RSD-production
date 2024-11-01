---------- CREATED BY MIGRA ----------

drop policy "maintainer_all_rights" on "public"."category";

drop policy "anyone_can_read" on "public"."category_for_software";

alter table "public"."category" drop constraint "unique_name";

alter table "public"."category" drop constraint "unique_short_name";

drop index if exists "public"."unique_name";

drop index if exists "public"."unique_short_name";

create table "public"."category_for_project" (
    "project_id" uuid not null,
    "category_id" uuid not null
);


alter table "public"."category_for_project" enable row level security;

alter table "public"."category" add column "allow_projects" boolean not null default false;

alter table "public"."category" add column "allow_software" boolean not null default false;

alter table "public"."category" add column "organisation" uuid;

CREATE INDEX category_for_project_category_id_idx ON public.category_for_project USING btree (category_id);

CREATE UNIQUE INDEX category_for_project_pkey ON public.category_for_project USING btree (project_id, category_id);

CREATE INDEX category_organisation_idx ON public.category USING btree (organisation);

CREATE UNIQUE INDEX unique_name ON public.category USING btree (parent, name, community, organisation) NULLS NOT DISTINCT;

CREATE UNIQUE INDEX unique_short_name ON public.category USING btree (parent, short_name, community, organisation) NULLS NOT DISTINCT;

alter table "public"."category_for_project" add constraint "category_for_project_pkey" PRIMARY KEY using index "category_for_project_pkey";

alter table "public"."category" add constraint "category_organisation_fkey" FOREIGN KEY (organisation) REFERENCES organisation(id);

alter table "public"."category" add constraint "only_one_entity" CHECK (((community IS NULL) OR (organisation IS NULL)));

alter table "public"."category_for_project" add constraint "category_for_project_category_id_fkey" FOREIGN KEY (category_id) REFERENCES category(id);

alter table "public"."category_for_project" add constraint "category_for_project_project_id_fkey" FOREIGN KEY (project_id) REFERENCES project(id);

alter table "public"."category" add constraint "unique_name" UNIQUE using index "unique_name";

alter table "public"."category" add constraint "unique_short_name" UNIQUE using index "unique_short_name";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.category_paths_by_project_expanded(project_id uuid)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
	WITH
		cat_ids AS
		(SELECT
			category_id
		FROM
			category_for_project
		WHERE
			category_for_project.project_id = category_paths_by_project_expanded.project_id
		),
		paths AS
		(
			SELECT
				category_path_expanded(category_id) AS path
			FROM cat_ids
		)
	SELECT
		CASE
			WHEN EXISTS(
				SELECT 1 FROM cat_ids
			) THEN (
				SELECT json_agg(path) FROM paths
			)
			ELSE '[]'::json
		END AS result
$function$
;

CREATE OR REPLACE FUNCTION public.delete_organisation_categories_from_project(project_id uuid, organisation_id uuid)
 RETURNS void
 LANGUAGE sql
AS $function$
DELETE FROM category_for_project
	USING
		category
	WHERE
		category_for_project.category_id = category.id AND
		category_for_project.project_id = delete_organisation_categories_from_project.project_id AND
		category.organisation = delete_organisation_categories_from_project.organisation_id;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_organisation_categories_from_software(software_id uuid, organisation_id uuid)
 RETURNS void
 LANGUAGE sql
AS $function$
DELETE FROM category_for_software
	USING
		category
	WHERE
		category_for_software.category_id = category.id AND
		category_for_software.software_id = delete_organisation_categories_from_software.software_id AND
		category.organisation = delete_organisation_categories_from_software.organisation_id;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_community_categories_from_software(software_id uuid, community_id uuid)
 RETURNS void
 LANGUAGE sql
AS $function$
DELETE FROM category_for_software
	USING
		category
	WHERE
		category_for_software.category_id = category.id AND
		category_for_software.software_id = delete_community_categories_from_software.software_id AND
		category.community = delete_community_categories_from_software.community_id;
$function$
;

CREATE OR REPLACE FUNCTION public.homepage_counts(OUT software_cnt bigint, OUT open_software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT contributor_cnt bigint, OUT software_mention_cnt bigint)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	SELECT COUNT(*) FROM software INTO software_cnt;
	SELECT COUNT(*) FROM software WHERE NOT closed_source INTO open_software_cnt;
	SELECT COUNT(*) FROM project INTO project_cnt;
	SELECT
		COUNT(*) AS organisation_cnt
	FROM
		organisations_overview(TRUE)
	WHERE
		organisations_overview.parent IS NULL AND organisations_overview.score>0
	INTO organisation_cnt;
	SELECT COUNT(DISTINCT(orcid,given_names,family_names)) FROM contributor INTO contributor_cnt;
	SELECT COUNT(*) FROM mentions_by_software() INTO software_mention_cnt;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_category()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.id IS NOT NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'The category id is generated automatically and may not be set.';
	END IF;
	IF NEW.parent IS NOT NULL AND (SELECT community FROM category WHERE id = NEW.parent) IS DISTINCT FROM NEW.community THEN
		RAISE EXCEPTION USING MESSAGE = 'The community must be the same as of its parent.';
	END IF;
	IF NEW.parent IS NOT NULL AND (SELECT organisation FROM category WHERE id = NEW.parent) IS DISTINCT FROM NEW.organisation THEN
		RAISE EXCEPTION USING MESSAGE = 'The organisation must be the same as of its parent.';
	END IF;
	NEW.id = gen_random_uuid();
	RETURN NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_category()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF NEW.id != OLD.id THEN
		RAISE EXCEPTION USING MESSAGE = 'The category id may not be changed.';
	END IF;
	IF NEW.community IS DISTINCT FROM OLD.community THEN
		RAISE EXCEPTION USING MESSAGE = 'The community this category belongs to may not be changed.';
	END IF;
	IF NEW.parent IS NOT NULL AND (SELECT community FROM category WHERE id = NEW.parent) IS DISTINCT FROM NEW.community THEN
		RAISE EXCEPTION USING MESSAGE = 'The community must be the same as of its parent.';
	END IF;
	IF NEW.organisation IS DISTINCT FROM OLD.organisation THEN
		RAISE EXCEPTION USING MESSAGE = 'The organisation this category belongs to may not be changed.';
	END IF;
	IF NEW.parent IS NOT NULL AND (SELECT organisation FROM category WHERE id = NEW.parent) IS DISTINCT FROM NEW.organisation THEN
		RAISE EXCEPTION USING MESSAGE = 'The organisation must be the same as of its parent.';
	END IF;
	RETURN NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.suggested_roles()
 RETURNS character varying[]
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
	ARRAY_AGG("role")
	FROM (
		SELECT
			"role"
		FROM
			contributor
		WHERE
			"role" IS NOT NULL
		UNION
		SELECT
			"role"
		FROM
			team_member
		WHERE
		"role" IS NOT NULL
	) roles;
$function$
;

create policy "admin_all_rights"
on "public"."category_for_project"
as permissive
for all
to rsd_admin
using (true);


create policy "anyone_can_read"
on "public"."category_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project_id IN ( SELECT project.id
   FROM project)));


create policy "maintainer_all_rights"
on "public"."category_for_project"
as permissive
for all
to rsd_user
using ((project_id IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))));


create policy "maintainer_all_rights"
on "public"."category"
as permissive
for all
to rsd_user
using ((((community IS NOT NULL) AND (community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer)))) OR ((organisation IS NOT NULL) AND (organisation IN ( SELECT organisations_of_current_maintainer.organisations_of_current_maintainer
   FROM organisations_of_current_maintainer() organisations_of_current_maintainer(organisations_of_current_maintainer))))));


create policy "anyone_can_read"
on "public"."category_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software_id IN ( SELECT software.id
   FROM software)));


CREATE TRIGGER check_category_for_project_before_delete BEFORE DELETE ON public.category_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_category_for_project_before_insert BEFORE INSERT ON public.category_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_category_for_project_before_update BEFORE UPDATE ON public.category_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

