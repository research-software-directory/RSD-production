---------- CREATED BY MIGRA ----------

-- WARNING:
-- If you have any category icons in production, you have to alter the script so that they are migrated to the `properties` column, because this script simply drops (i.e. permanently removes) them
-- END WARNING

alter table "public"."category" drop column "icon";

alter table "public"."category" add column "properties" jsonb not null default '{}'::jsonb;

alter table "public"."category" add column "provenance_iri" character varying;

alter table "public"."mention" alter column "title" set data type character varying(3000) using "title"::character varying(3000);

alter table "public"."category" add constraint "highlight_must_be_top_level_category" CHECK ((NOT (((properties ->> 'is_highlight'::text))::boolean AND (parent IS NOT NULL))));

alter table "public"."category" add constraint "invalid_value_for_properties" CHECK (((properties - '{icon,is_highlight,description,subtitle}'::text[]) = '{}'::jsonb));

set check_function_bodies = off;

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
	SELECT id, parent, short_name, name, properties, provenance_iri
	FROM cat_path
	ORDER BY r_index DESC;
$function$
;

