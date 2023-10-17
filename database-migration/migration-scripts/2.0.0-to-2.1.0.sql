---------- CREATED BY MIGRA ----------

drop policy "maintainer_can_read" on "public"."mention";

drop policy "anyone_can_read" on "public"."mention";

create table "public"."category" (
    "id" uuid not null,
    "parent" uuid,
    "short_name" character varying not null,
    "name" character varying not null,
    "icon" character varying
);


alter table "public"."category" enable row level security;

create table "public"."category_for_software" (
    "software_id" uuid not null,
    "category_id" uuid not null
);


alter table "public"."category_for_software" enable row level security;

create table "public"."citation_for_mention" (
    "mention" uuid not null,
    "citation" uuid not null
);


alter table "public"."citation_for_mention" enable row level security;

create table "public"."reference_paper_for_software" (
    "mention" uuid not null,
    "software" uuid not null
);


alter table "public"."reference_paper_for_software" enable row level security;

alter table "public"."mention" add column "citations_scraped_at" timestamp with time zone;

alter table "public"."mention" add column "external_id" character varying(500);

CREATE UNIQUE INDEX category_for_software_pkey ON public.category_for_software USING btree (software_id, category_id);

CREATE UNIQUE INDEX category_pkey ON public.category USING btree (id);

CREATE UNIQUE INDEX citation_for_mention_pkey ON public.citation_for_mention USING btree (mention, citation);

CREATE UNIQUE INDEX mention_external_id_source_key ON public.mention USING btree (external_id, source);

CREATE UNIQUE INDEX reference_paper_for_software_pkey ON public.reference_paper_for_software USING btree (mention, software);

CREATE UNIQUE INDEX unique_name ON public.category USING btree (parent, name) NULLS NOT DISTINCT;

CREATE UNIQUE INDEX unique_short_name ON public.category USING btree (parent, short_name) NULLS NOT DISTINCT;

alter table "public"."category" add constraint "category_pkey" PRIMARY KEY using index "category_pkey";

alter table "public"."category_for_software" add constraint "category_for_software_pkey" PRIMARY KEY using index "category_for_software_pkey";

alter table "public"."citation_for_mention" add constraint "citation_for_mention_pkey" PRIMARY KEY using index "citation_for_mention_pkey";

alter table "public"."reference_paper_for_software" add constraint "reference_paper_for_software_pkey" PRIMARY KEY using index "reference_paper_for_software_pkey";

alter table "public"."category" add constraint "category_parent_fkey" FOREIGN KEY (parent) REFERENCES category(id);

alter table "public"."category" add constraint "unique_name" UNIQUE using index "unique_name";

alter table "public"."category" add constraint "unique_short_name" UNIQUE using index "unique_short_name";

alter table "public"."category_for_software" add constraint "category_for_software_category_id_fkey" FOREIGN KEY (category_id) REFERENCES category(id);

alter table "public"."category_for_software" add constraint "category_for_software_software_id_fkey" FOREIGN KEY (software_id) REFERENCES software(id);

alter table "public"."citation_for_mention" add constraint "citation_for_mention_citation_fkey" FOREIGN KEY (citation) REFERENCES mention(id);

alter table "public"."citation_for_mention" add constraint "citation_for_mention_mention_fkey" FOREIGN KEY (mention) REFERENCES mention(id);

alter table "public"."mention" add constraint "mention_external_id_source_key" UNIQUE using index "mention_external_id_source_key";

alter table "public"."reference_paper_for_software" add constraint "reference_paper_for_software_mention_fkey" FOREIGN KEY (mention) REFERENCES mention(id);

alter table "public"."reference_paper_for_software" add constraint "reference_paper_for_software_software_fkey" FOREIGN KEY (software) REFERENCES software(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.available_categories_expanded()
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
	WITH
	cat_ids AS
		(SELECT id AS category_id FROM category AS node WHERE NOT EXISTS (SELECT 1 FROM category AS sub WHERE node.id = sub.parent)),
	paths AS
		(SELECT category_path_expanded(category_id) AS path FROM cat_ids)
	SELECT
		CASE WHEN EXISTS(SELECT 1 FROM cat_ids) THEN (SELECT json_agg(path) AS result FROM paths)
		ELSE '[]'::json
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
	-- 2. How a table row "type" could be used here Now we have to list all columns of `category` explicitely
	--    I want to have something like `* without 'r_index'` to be independant from modifications of `category`
	-- 3. Maybe this could be improved by using SEARCH keyword.
	SELECT id, parent, short_name, name, icon
	FROM cat_path
	ORDER BY r_index DESC;
$function$
;

CREATE OR REPLACE FUNCTION public.category_path_expanded(category_id uuid)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
	SELECT json_agg(row_to_json) AS path FROM (SELECT row_to_json(category_path(category_id))) AS cats;
$function$
;

CREATE OR REPLACE FUNCTION public.category_paths_by_software_expanded(software_id uuid)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
	WITH
		cat_ids AS
		(SELECT category_id FROM category_for_software AS c4s WHERE c4s.software_id = category_paths_by_software_expanded.software_id),
	paths AS
		(SELECT category_path_expanded(category_id) AS path FROM cat_ids)
	SELECT
		CASE WHEN EXISTS(SELECT 1 FROM cat_ids) THEN (SELECT json_agg(path) FROM paths)
		ELSE '[]'::json
		END AS result
$function$
;

CREATE OR REPLACE FUNCTION public.check_cycle_categories()
 RETURNS trigger
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
	DECLARE first_id UUID = NEW.id;
	DECLARE current_id UUID = NEW.parent;
BEGIN
	WHILE current_id IS NOT NULL LOOP
		IF current_id = first_id THEN
			RAISE EXCEPTION USING MESSAGE = 'Cycle detected for category with id ' || NEW.id;
		END IF;
		SELECT parent FROM category WHERE id = current_id INTO current_id;
	END LOOP;
	RETURN NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.citation_by_software()
 RETURNS TABLE(software uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying, reference_papers uuid[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	reference_paper_for_software.software,
	mention.id,
	mention.doi,
	mention.url,
	mention.title,
	mention.authors,
	mention.publisher,
	mention.publication_year,
	mention.journal,
	mention.page,
	mention.image_url,
	mention.mention_type,
	mention.source,
	ARRAY_AGG(
		reference_paper_for_software.mention
	) AS reference_paper
FROM
	reference_paper_for_software
INNER JOIN
	citation_for_mention ON citation_for_mention.mention = reference_paper_for_software.mention
INNER JOIN
	mention ON mention.id = citation_for_mention.citation
GROUP BY
	reference_paper_for_software.software,
	mention.id,
	mention.doi,
	mention.url,
	mention.title,
	mention.authors,
	mention.publisher,
	mention.publication_year,
	mention.journal,
	mention.page,
	mention.image_url,
	mention.mention_type,
	mention.source
;
$function$
;

CREATE OR REPLACE FUNCTION public.reference_papers_to_scrape()
 RETURNS TABLE(id uuid, doi citext, citations_scraped_at timestamp with time zone, known_dois citext[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT mention.id, mention.doi, mention.citations_scraped_at, ARRAY_REMOVE(ARRAY_AGG(citation.doi), NULL)
	FROM mention
	LEFT JOIN citation_for_mention ON mention.id = citation_for_mention.mention
	LEFT JOIN mention AS citation ON citation_for_mention.citation = citation.id
	WHERE mention.id IN (
		SELECT mention FROM reference_paper_for_software
	)
	GROUP BY mention.id
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
	RETURN NEW;
END
$function$
;

create policy "admin_all_rights"
on "public"."category"
as permissive
for all
to rsd_admin
using (true);


create policy "anyone_can_read"
on "public"."category"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "admin_all_rights"
on "public"."category_for_software"
as permissive
for all
to rsd_admin
using (true);


create policy "anyone_can_read"
on "public"."category_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((EXISTS ( SELECT 1
   FROM software
  WHERE (software.id = category_for_software.software_id))));


create policy "maintainer_all_rights"
on "public"."category_for_software"
as permissive
for all
to rsd_user
using ((software_id IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))));


create policy "admin_all_rights"
on "public"."citation_for_mention"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."citation_for_mention"
as permissive
for select
to rsd_web_anon, rsd_user
using ((mention IN ( SELECT mention.id
   FROM mention)));


create policy "admin_all_rights"
on "public"."reference_paper_for_software"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."reference_paper_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "maintainer_all_rights"
on "public"."reference_paper_for_software"
as permissive
for all
to rsd_user
using ((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))))
with check (software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer)));


create policy "anyone_can_read"
on "public"."mention"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


CREATE TRIGGER check_category_before_delete BEFORE DELETE ON public.category FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_category_before_insert BEFORE INSERT ON public.category FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_category_before_update BEFORE UPDATE ON public.category FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_category BEFORE INSERT ON public.category FOR EACH ROW EXECUTE FUNCTION sanitise_insert_category();

CREATE TRIGGER sanitise_update_category BEFORE UPDATE ON public.category FOR EACH ROW EXECUTE FUNCTION sanitise_update_category();

CREATE TRIGGER zzz_check_cycle_categories AFTER INSERT OR UPDATE ON public.category FOR EACH ROW EXECUTE FUNCTION check_cycle_categories();

CREATE TRIGGER check_category_for_software_before_delete BEFORE DELETE ON public.category_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_category_for_software_before_insert BEFORE INSERT ON public.category_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_category_for_software_before_update BEFORE UPDATE ON public.category_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_citation_for_mention_before_delete BEFORE DELETE ON public.citation_for_mention FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_citation_for_mention_before_insert BEFORE INSERT ON public.citation_for_mention FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_citation_for_mention_before_update BEFORE UPDATE ON public.citation_for_mention FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_reference_paper_for_software_before_delete BEFORE DELETE ON public.reference_paper_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_reference_paper_for_software_before_insert BEFORE INSERT ON public.reference_paper_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_reference_paper_for_software_before_update BEFORE UPDATE ON public.reference_paper_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

