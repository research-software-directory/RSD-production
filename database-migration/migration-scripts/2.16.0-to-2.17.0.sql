---------- CREATED BY MIGRA ----------

alter table "public"."category" drop constraint "unique_name";

alter table "public"."category" drop constraint "unique_short_name";

drop function if exists "public"."available_categories_expanded"();

drop function if exists "public"."counts_by_maintainer"(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint);

drop function if exists "public"."organisations_by_maintainer"(maintainer_id uuid);

drop function if exists "public"."software_by_maintainer"(maintainer_id uuid);

drop index if exists "public"."unique_name";

drop index if exists "public"."unique_short_name";

alter table "public"."category" add column "community" uuid;

alter table "public"."category" alter column "name" set data type character varying(250) using "name"::character varying(250);

alter table "public"."category" alter column "provenance_iri" set default NULL::character varying;

alter table "public"."category" alter column "provenance_iri" set data type character varying(250) using "provenance_iri"::character varying(250);

alter table "public"."category" alter column "short_name" set data type character varying(100) using "short_name"::character varying(100);

CREATE INDEX category_community_idx ON public.category USING btree (community);

CREATE INDEX category_parent_idx ON public.category USING btree (parent);

CREATE UNIQUE INDEX unique_name ON public.category USING btree (parent, name, community) NULLS NOT DISTINCT;

CREATE UNIQUE INDEX unique_short_name ON public.category USING btree (parent, short_name, community) NULLS NOT DISTINCT;

alter table "public"."category" add constraint "category_community_fkey" FOREIGN KEY (community) REFERENCES community(id);

alter table "public"."category" add constraint "unique_name" UNIQUE using index "unique_name";

alter table "public"."category" add constraint "unique_short_name" UNIQUE using index "unique_short_name";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.communities_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, name character varying, short_description character varying, logo_id character varying, primary_maintainer uuid, software_cnt bigint, pending_cnt bigint, rejected_cnt bigint, keywords citext[], description character varying, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (community.id)
	community.id,
	community.slug,
	community."name",
	community.short_description,
	community.logo_id,
	community.primary_maintainer,
	software_count_by_community.software_cnt,
	pending_count_by_community.pending_cnt,
	rejected_count_by_community.rejected_cnt,
	keyword_filter_for_community.keywords,
	community.description,
	community.created_at
FROM
	community
LEFT JOIN
	software_count_by_community() ON community.id = software_count_by_community.community
LEFT JOIN
	pending_count_by_community() ON community.id = pending_count_by_community.community
LEFT JOIN
	rejected_count_by_community() ON community.id = rejected_count_by_community.community
LEFT JOIN
	keyword_filter_for_community() ON community.id = keyword_filter_for_community.community
LEFT JOIN
	maintainer_for_community ON maintainer_for_community.community = community.id
WHERE
	maintainer_for_community.maintainer = maintainer_id OR community.primary_maintainer = maintainer_id;
;
$function$
;

CREATE OR REPLACE FUNCTION public.counts_by_maintainer(OUT software_cnt bigint, OUT project_cnt bigint, OUT organisation_cnt bigint, OUT community_cnt bigint)
 RETURNS record
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	SELECT COUNT(*) FROM software_of_current_maintainer() INTO software_cnt;
	SELECT COUNT(*) FROM projects_of_current_maintainer() INTO project_cnt;
	SELECT COUNT(DISTINCT organisations_of_current_maintainer)
		FROM organisations_of_current_maintainer() INTO organisation_cnt;
	SELECT COUNT(*) FROM communities_of_current_maintainer() INTO community_cnt;
END
$function$
;

CREATE OR REPLACE FUNCTION public.category_path(category_id uuid)
 RETURNS TABLE("like" category)
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

CREATE OR REPLACE FUNCTION public.organisations_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, short_description character varying, ror_id character varying, website character varying, is_tenant boolean, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, rsd_path character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (organisation.id)
	organisation.id,
	organisation.slug,
	organisation.parent,
	organisation.primary_maintainer,
	organisation.name,
	organisation.short_description,
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
	RETURN NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, is_published boolean, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.is_published,
		software.image_id,
		software.updated_at,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt
	FROM
		software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	INNER JOIN
		maintainer_for_software ON software.id=maintainer_for_software.software
	WHERE
		maintainer_for_software.maintainer=maintainer_id;
$function$
;

create policy "maintainer_all_rights"
on "public"."category"
as permissive
for all
to rsd_user
using ((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))));


CREATE TRIGGER check_community_before_delete BEFORE DELETE ON public.community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_community_before_insert BEFORE INSERT ON public.community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_community_before_update BEFORE UPDATE ON public.community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_community_before_delete BEFORE DELETE ON public.invite_maintainer_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_invite_maintainer_for_community_before_insert BEFORE INSERT ON public.invite_maintainer_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_invite_maintainer_for_community_before_update BEFORE UPDATE ON public.invite_maintainer_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_for_community_before_delete BEFORE DELETE ON public.keyword_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_keyword_for_community_before_insert BEFORE INSERT ON public.keyword_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_keyword_for_community_before_update BEFORE UPDATE ON public.keyword_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_community_before_delete BEFORE DELETE ON public.maintainer_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_maintainer_for_community_before_insert BEFORE INSERT ON public.maintainer_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_maintainer_for_community_before_update BEFORE UPDATE ON public.maintainer_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_community_before_delete BEFORE DELETE ON public.software_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_software_for_community_before_insert BEFORE INSERT ON public.software_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_software_for_community_before_update BEFORE UPDATE ON public.software_for_community FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

