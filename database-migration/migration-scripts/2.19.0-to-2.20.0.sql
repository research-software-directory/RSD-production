---------- CREATED BY MIGRA ----------

drop function if exists "public"."category_path"(category_id uuid);

create table "public"."testimonial_for_project" (
    "id" uuid not null default gen_random_uuid(),
    "project" uuid not null,
    "message" character varying(500) not null,
    "source" character varying(200) not null,
    "position" integer
);


CREATE UNIQUE INDEX testimonial_for_project_pkey ON public.testimonial_for_project USING btree (id);

alter table "public"."testimonial_for_project" add constraint "testimonial_for_project_pkey" PRIMARY KEY using index "testimonial_for_project_pkey";

alter table "public"."testimonial_for_project" add constraint "testimonial_for_project_project_fkey" FOREIGN KEY (project) REFERENCES project(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_community(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the community to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this community';
	END IF;

	DELETE FROM category WHERE category.community = delete_community.id;
	DELETE FROM invite_maintainer_for_community WHERE invite_maintainer_for_community.community = delete_community.id;
	DELETE FROM keyword_for_community WHERE keyword_for_community.community = delete_community.id;
	DELETE FROM maintainer_for_community WHERE maintainer_for_community.community = delete_community.id;
	DELETE FROM software_for_community WHERE software_for_community.community = delete_community.id;

	DELETE FROM community WHERE community.id = delete_community.id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.delete_organisation(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE child_id UUID;
DECLARE child_ids UUID[];
BEGIN
	IF id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the organisation to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this organisation';
	END IF;

	child_ids := ARRAY_REMOVE(ARRAY_AGG((SELECT organisation.id FROM organisation WHERE organisation.parent = delete_organisation.id)), NULL);

	FOREACH child_id IN ARRAY child_ids LOOP
		PERFORM delete_organisation(child_id);
	END LOOP;

	DELETE FROM invite_maintainer_for_organisation WHERE invite_maintainer_for_organisation.organisation = delete_organisation.id;
	DELETE FROM maintainer_for_organisation WHERE maintainer_for_organisation.organisation = delete_organisation.id;
	DELETE FROM project_for_organisation WHERE project_for_organisation.organisation = delete_organisation.id;
	DELETE FROM software_for_organisation WHERE software_for_organisation.organisation = delete_organisation.id;

	DELETE FROM organisation WHERE organisation.id = delete_organisation.id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.delete_project(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the project to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this project';
	END IF;

	DELETE FROM impact_for_project WHERE impact_for_project.project = delete_project.id;
	DELETE FROM invite_maintainer_for_project WHERE invite_maintainer_for_project.project = delete_project.id;
	DELETE FROM keyword_for_project WHERE keyword_for_project.project = delete_project.id;
	DELETE FROM maintainer_for_project WHERE maintainer_for_project.project = delete_project.id;
	DELETE FROM output_for_project WHERE output_for_project.project = delete_project.id;
	DELETE FROM project_for_organisation WHERE project_for_organisation.project = delete_project.id;
	DELETE FROM project_for_project WHERE project_for_project.origin = delete_project.id OR project_for_project.relation = delete_project.id;
	DELETE FROM research_domain_for_project WHERE research_domain_for_project.project = delete_project.id;
	DELETE FROM software_for_project WHERE software_for_project.project = delete_project.id;
	DELETE FROM team_member WHERE team_member.project = delete_project.id;
	DELETE FROM url_for_project WHERE url_for_project.project = delete_project.id;

	DELETE FROM project WHERE project.id = delete_project.id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.delete_software(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the software to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this software';
	END IF;

	DELETE FROM category_for_software WHERE category_for_software.software_id = delete_software.id;
	DELETE FROM contributor WHERE contributor.software = delete_software.id;
	DELETE FROM invite_maintainer_for_software WHERE invite_maintainer_for_software.software = delete_software.id;
	DELETE FROM keyword_for_software WHERE keyword_for_software.software = delete_software.id;
	DELETE FROM license_for_software WHERE license_for_software.software = delete_software.id;
	DELETE FROM maintainer_for_software WHERE maintainer_for_software.software = delete_software.id;
	DELETE FROM mention_for_software WHERE mention_for_software.software = delete_software.id;
	DELETE FROM package_manager WHERE package_manager.software = delete_software.id;
	DELETE FROM reference_paper_for_software WHERE reference_paper_for_software.software = delete_software.id;
	DELETE FROM release_version WHERE release_version.release_id = delete_software.id;
	DELETE FROM release WHERE release.software = delete_software.id;
	DELETE FROM repository_url WHERE repository_url.software = delete_software.id;
	DELETE FROM software_for_community WHERE software_for_community.software = delete_software.id;
	DELETE FROM software_for_organisation WHERE software_for_organisation.software = delete_software.id;
	DELETE FROM software_for_project WHERE software_for_project.software = delete_software.id;
	DELETE FROM software_for_software WHERE software_for_software.origin = delete_software.id OR software_for_software.relation = delete_software.id;
	DELETE FROM software_highlight WHERE software_highlight.software = delete_software.id;
	DELETE FROM testimonial WHERE testimonial.software = delete_software.id;

	DELETE FROM software WHERE software.id = delete_software.id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_testimonial_for_project()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_testimonial_for_project()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.category_path(category_id uuid)
 RETURNS TABLE(id uuid, parent uuid, community uuid, short_name character varying, name character varying, properties jsonb, provenance_iri character varying)
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
	SELECT id, parent, community, short_name, name, properties, provenance_iri
	FROM cat_path
	ORDER BY r_index DESC;
$function$
;

CREATE TRIGGER check_testimonial_for_project_before_delete BEFORE DELETE ON public.testimonial_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_testimonial_for_project_before_insert BEFORE INSERT ON public.testimonial_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_testimonial_for_project_before_update BEFORE UPDATE ON public.testimonial_for_project FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_testimonial_for_project BEFORE INSERT ON public.testimonial_for_project FOR EACH ROW EXECUTE FUNCTION sanitise_insert_testimonial_for_project();

CREATE TRIGGER sanitise_update_testimonial_for_project BEFORE UPDATE ON public.testimonial_for_project FOR EACH ROW EXECUTE FUNCTION sanitise_update_testimonial_for_project();

