-- added manunally

-- update columns to remove white space from URLs
UPDATE software SET description_url = regexp_replace(description_url, '\s+', '', 'g') WHERE description_url !~ '^https?://\S+$';
UPDATE software SET get_started_url = regexp_replace(get_started_url, '\s+', '', 'g') WHERE get_started_url !~ '^https?://\S+$';
UPDATE repository_url SET url = regexp_replace(url, '\s+', '', 'g') WHERE url !~ '^https?://\S+$';
UPDATE package_manager SET url = regexp_replace(url, '\s+', '', 'g') WHERE url !~ '^https?://\S+$';
UPDATE license_for_software SET reference = regexp_replace(reference, '\s+', '', 'g') WHERE reference !~ '^https?://\S+$';
UPDATE url_for_project SET url = regexp_replace(url, '\s+', '', 'g') WHERE url !~ '^https?://\S+$';
UPDATE mention SET url = regexp_replace(url, '\s+', '', 'g') WHERE url !~ '^https?://\S+$';
UPDATE mention SET image_url = regexp_replace(image_url, '\s+', '', 'g') WHERE image_url !~ '^https?://\S+$';

-- select columns whose URLs are still not compliant, manual cleaning needed
--SELECT description_url FROM software WHERE description_url !~ '^https?://\S+$';
--SELECT get_started_url FROM software WHERE get_started_url !~ '^https?://\S+$';
--SELECT url FROM repository_url WHERE url !~ '^https?://\S+$';
--SELECT url FROM package_manager WHERE url !~ '^https?://\S+$';
--SELECT reference FROM license_for_software WHERE reference !~ '^https?://\S+$';
--SELECT url FROM url_for_project WHERE url !~ '^https?://\S+$';
--SELECT url FROM mention WHERE url !~ '^https?://\S+$';
--SELECT image_url FROM mention WHERE image_url !~ '^https?://\S+$';

-- We recommend to disable JIT (https://www.postgresql.org/docs/15/jit.html), replace the database name if appropriate:
--ALTER DATABASE "rsd-db" SET JIT = OFF;


-- end added manually

---------- CREATED BY MIGRA ----------

drop policy "anyone_can_read" on "public"."citation_for_mention";

alter table "public"."license_for_software" drop constraint "license_for_software_reference_check";

alter table "public"."mention" drop constraint "mention_image_url_check";

alter table "public"."mention" drop constraint "mention_url_check";

alter table "public"."package_manager" drop constraint "package_manager_url_check";

alter table "public"."repository_url" drop constraint "repository_url_url_check";

alter table "public"."software" drop constraint "software_description_url_check";

alter table "public"."software" drop constraint "software_get_started_url_check";

alter table "public"."url_for_project" drop constraint "url_for_project_url_check";

alter table "public"."package_manager" alter column "package_manager" drop default;

alter type "public"."package_manager_type" rename to "package_manager_type__old_version_to_be_dropped";

create type "public"."package_manager_type" as enum ('anaconda', 'chocolatey', 'cran', 'crates', 'debian', 'dockerhub', 'ghcr', 'github', 'gitlab', 'golang', 'maven', 'npm', 'pixi', 'pypi', 'snapcraft', 'sonatype', 'other');

alter table "public"."package_manager" alter column package_manager type "public"."package_manager_type" using package_manager::text::"public"."package_manager_type";

alter table "public"."package_manager" alter column "package_manager" set default 'other'::package_manager_type;

drop type "public"."package_manager_type__old_version_to_be_dropped";

CREATE INDEX contributor_orcid_idx ON public.contributor USING btree (orcid);

CREATE INDEX contributor_software_idx ON public.contributor USING btree (software);

CREATE INDEX team_member_orcid_idx ON public.team_member USING btree (orcid);

CREATE INDEX team_member_project_idx ON public.team_member USING btree (project);

CREATE INDEX testimonial_for_project_project_idx ON public.testimonial_for_project USING btree (project);

CREATE INDEX testimonial_software_idx ON public.testimonial USING btree (software);

alter table "public"."license_for_software" add constraint "license_for_software_reference_check" CHECK (((reference)::text ~ '^https?://\S+$'::text));

alter table "public"."mention" add constraint "mention_image_url_check" CHECK (((image_url)::text ~ '^https?://\S+$'::text));

alter table "public"."mention" add constraint "mention_url_check" CHECK (((url)::text ~ '^https?://\S+$'::text));

alter table "public"."package_manager" add constraint "package_manager_url_check" CHECK (((url)::text ~ '^https?://\S+$'::text));

alter table "public"."repository_url" add constraint "repository_url_url_check" CHECK (((url)::text ~ '^https?://\S+$'::text));

alter table "public"."software" add constraint "software_description_url_check" CHECK (((description_url)::text ~ '^https?://\S+$'::text));

alter table "public"."software" add constraint "software_get_started_url_check" CHECK (((get_started_url)::text ~ '^https?://\S+$'::text));

alter table "public"."url_for_project" add constraint "url_for_project_url_check" CHECK (((url)::text ~ '^https?://\S+$'::text));

set check_function_bodies = off;

create materialized view "public"."count_software_mentions_cached" as  SELECT count_software_mentions.software,
    count_software_mentions.mention_cnt
   FROM count_software_mentions() count_software_mentions(software, mention_cnt);


CREATE OR REPLACE FUNCTION public.aggregated_software_hosts_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(rsd_host character varying, rsd_host_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	rsd_host,
	COUNT(id) AS rsd_host_cnt
FROM
	aggregated_software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	CASE WHEN COALESCE(category_filter, '{}') = '{}' THEN TRUE ELSE COALESCE(categories, '{}') @> category_filter END
GROUP BY
	rsd_host
;
$function$
;

CREATE OR REPLACE FUNCTION public.aggregated_software_keywords_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[], rsd_host_filter character varying DEFAULT ''::character varying)
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	aggregated_software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	CASE WHEN COALESCE(category_filter, '{}') = '{}' THEN TRUE ELSE COALESCE(categories, '{}') @> category_filter END
	AND
		CASE
			WHEN rsd_host_filter = '' THEN TRUE
			WHEN rsd_host_filter IS NULL THEN rsd_host IS NULL
		ELSE
			rsd_host = rsd_host_filter
		END
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.aggregated_software_languages_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[], rsd_host_filter character varying DEFAULT ''::character varying)
 RETURNS TABLE(prog_language text, prog_language_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(prog_lang) AS prog_language,
	COUNT(id) AS prog_language_cnt
FROM
	aggregated_software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	CASE WHEN COALESCE(category_filter, '{}') = '{}' THEN TRUE ELSE COALESCE(categories, '{}') @> category_filter END
	AND
		CASE
			WHEN rsd_host_filter = '' THEN TRUE
			WHEN rsd_host_filter IS NULL THEN rsd_host IS NULL
		ELSE
			rsd_host = rsd_host_filter
		END
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.aggregated_software_licenses_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[], rsd_host_filter character varying DEFAULT ''::character varying)
 RETURNS TABLE(license character varying, license_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(licenses) AS license,
	COUNT(id) AS license_cnt
FROM
	aggregated_software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	CASE WHEN COALESCE(category_filter, '{}') = '{}' THEN TRUE ELSE COALESCE(categories, '{}') @> category_filter END
	AND
		CASE
			WHEN rsd_host_filter = '' THEN TRUE
			WHEN rsd_host_filter IS NULL THEN rsd_host IS NULL
		ELSE
			rsd_host = rsd_host_filter
		END
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.count_software_contributors()
 RETURNS TABLE(software uuid, contributor_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
		software.id, COUNT(*) AS contributor_cnt
	FROM
		software
	INNER JOIN
		contributor ON contributor.software = software.id
	GROUP BY
	software.id;
$function$
;

CREATE OR REPLACE FUNCTION public.software_for_highlight()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, is_published boolean, contributor_cnt bigint, mention_cnt bigint, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], "position" integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.updated_at,
	software.is_published,
	count_software_contributors.contributor_cnt,
	count_software_mentions_cached.mention_cnt,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	software_highlight.position
FROM
	software
INNER JOIN
	software_highlight ON software.id=software_highlight.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions_cached ON software.id=count_software_mentions_cached.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_overview()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], categories character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.updated_at,
	count_software_contributors.contributor_cnt,
	count_software_mentions_cached.mention_cnt,
	software.is_published,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	software_categories.category AS categories
FROM
	software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions_cached ON software.id=count_software_mentions_cached.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
LEFT JOIN
	software_categories() ON software.id=software_categories.software
;
$function$
;

CREATE UNIQUE INDEX count_software_mentions_cached_software_idx ON public.count_software_mentions_cached USING btree (software);

create policy "anyone_can_read"
on "public"."citation_for_mention"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


