---------- CREATED BY MIGRA ----------

alter table "public"."category" drop constraint "invalid_value_for_properties";

-- added manually

ALTER TABLE image DROP CONSTRAINT IF EXISTS image_valid_mime_type;

-- You might have to run the following if you have image/jpg in your database:

-- UPDATE IMAGE SET mime_type = 'image/jpeg' WHERE mime_type = 'image/jpg';

-- if you have more conflicts, run the following and adapt the constraint:

-- select mime_type, count(*) from image group by mime_type order by mime_type;

-- end added manually

alter table "public"."image" add constraint "image_valid_mime_type" CHECK (((mime_type)::text = ANY ((ARRAY['image/avif'::character varying, 'image/gif'::character varying, 'image/jpeg'::character varying, 'image/png'::character varying, 'image/svg+xml'::character varying, 'image/webp'::character varying, 'image/x-icon'::character varying])::text[])));

alter table "public"."category" add constraint "invalid_value_for_properties" CHECK (((properties - '{icon,is_highlight,description,subtitle,tree_level_labels}'::text[]) = '{}'::jsonb));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_community_categories_from_software(software_id uuid, community_id uuid)
 RETURNS void
 LANGUAGE sql
AS $function$
DELETE FROM category_for_software
	USING category
	WHERE category_for_software.category_id = category.id AND category_for_software.software_id = software_id AND category.community = community_id;
$function$
;

