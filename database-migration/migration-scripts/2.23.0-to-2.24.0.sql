---------- CREATED BY MIGRA ----------

alter table "public"."organisation" add column "lat" double precision;

alter table "public"."organisation" add column "lon" double precision;

alter table "public"."organisation" add column "ror_types" character varying(100)[];

alter table "public"."organisation" add column "wikipedia_url" character varying(300);

alter table "public"."organisation" add constraint "organisation_ror_id_check" CHECK (((ror_id)::text ~ '^https://ror\.org/(0[a-hj-km-np-tv-z|0-9]{6}[0-9]{2})$'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_category_node(category_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE child_id UUID;
DECLARE child_ids UUID[];
BEGIN
	IF category_id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the category to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
			AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this category';
	END IF;

	child_ids := (SELECT COALESCE((SELECT ARRAY_AGG(category.id) FROM category WHERE category.parent = delete_category_node.category_id), '{}'));

	FOREACH child_id IN ARRAY child_ids LOOP
		PERFORM delete_category_node(child_id);
	END LOOP;

	DELETE FROM category_for_software WHERE category_for_software.category_id = delete_category_node.category_id;
	DELETE FROM category_for_project WHERE category_for_project.category_id = delete_category_node.category_id;

	DELETE FROM category WHERE category.id = delete_category_node.category_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_organisation(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE child_id UUID;
DECLARE child_ids UUID[];
DECLARE category_id UUID;
DECLARE category_ids UUID[];
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

	child_ids := (SELECT COALESCE((SELECT ARRAY_AGG(organisation.id) FROM organisation WHERE organisation.parent = delete_organisation.id), '{}'));

	FOREACH child_id IN ARRAY child_ids LOOP
		PERFORM delete_organisation(child_id);
	END LOOP;

	category_ids := (SELECT COALESCE((SELECT ARRAY_AGG(category.id) FROM category WHERE category.organisation = delete_organisation.id), '{}'));

	FOREACH category_id IN ARRAY category_ids LOOP
		PERFORM delete_category_node(category_id);
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

	DELETE FROM category_for_project WHERE category_for_project.project_id = delete_project.id;
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
	DELETE FROM testimonial_for_project WHERE testimonial_for_project.project = delete_project.id;
	DELETE FROM url_for_project WHERE url_for_project.project = delete_project.id;

	DELETE FROM project WHERE project.id = delete_project.id;
END
$function$
;

