---------- CREATED BY MIGRA ----------

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.categories()
 RETURNS TABLE(id uuid, parent uuid, community uuid, organisation uuid, allow_software boolean, allow_projects boolean, short_name character varying, name character varying, properties jsonb, provenance_iri character varying)
 LANGUAGE sql
 STABLE
AS $function$
	WITH RECURSIVE category_tree AS (
		-- 1. Anchor Member: Fetch root items (where parent IS NULL)
		-- These items hold the source-of-truth for allow_software and allow_projects
		SELECT
			root.id,
			root.parent,
			root.community,
			root.organisation,
			root.allow_software,
			root.allow_projects,
			root.short_name,
			root.name,
			root.properties,
			root.provenance_iri
		FROM category root
		WHERE root.parent IS NULL

		UNION ALL

		-- 2. Recursive Member: Fetch children and pass down allow... values
		-- Children ignore their own raw columns and pull flags directly from their parent's resolved tree record.
		SELECT
			child.id,
			child.parent,
			child.community,
			child.organisation,
			-- Inherited value passed down
			parent.allow_software,
			-- Inherited value passed down
			parent.allow_projects,
			child.short_name,
			child.name,
			child.properties,
			child.provenance_iri
		FROM category child
		JOIN category_tree parent ON child.parent = parent.id
	)
	SELECT
		id,
		parent,
		community,
		organisation,
		allow_software,
		allow_projects,
		short_name,
		name,
		properties,
		provenance_iri
	FROM category_tree;
$function$
;

