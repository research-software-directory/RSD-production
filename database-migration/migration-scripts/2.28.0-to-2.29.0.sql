---------- CREATED BY MIGRA ----------

drop function if exists "public"."com_software_keywords_filter"(community_id uuid, software_status request_status, search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."com_software_languages_filter"(community_id uuid, software_status request_status, search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."com_software_licenses_filter"(community_id uuid, software_status request_status, search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."highlight_keywords_filter"(search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."highlight_languages_filter"(search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."highlight_licenses_filter"(search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."org_project_domains_filter"(organisation_id uuid, search_filter text, status_filter character varying, keyword_filter citext[], research_domain_filter character varying[], organisation_filter character varying[]);

drop function if exists "public"."org_project_keywords_filter"(organisation_id uuid, search_filter text, status_filter character varying, keyword_filter citext[], research_domain_filter character varying[], organisation_filter character varying[]);

drop function if exists "public"."org_project_participating_organisations_filter"(organisation_id uuid, search_filter text, status_filter character varying, keyword_filter citext[], research_domain_filter character varying[], organisation_filter character varying[]);

drop function if exists "public"."org_project_status_filter"(organisation_id uuid, search_filter text, keyword_filter citext[], research_domain_filter character varying[], organisation_filter character varying[]);

drop function if exists "public"."org_software_keywords_filter"(organisation_id uuid, search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."org_software_languages_filter"(organisation_id uuid, search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."org_software_licenses_filter"(organisation_id uuid, search_filter text, keyword_filter citext[], prog_lang_filter text[], license_filter character varying[]);

drop function if exists "public"."global_search"(query character varying);

drop function if exists "public"."highlight_overview"();

drop function if exists "public"."highlight_search"(search character varying);

drop function if exists "public"."organisations_overview"(public boolean);

drop function if exists "public"."projects_by_organisation"(organisation_id uuid);

drop function if exists "public"."projects_by_organisation_search"(organisation_id uuid, search character varying);

drop function if exists "public"."software_by_community"(community_id uuid);

drop function if exists "public"."software_by_community_search"(community_id uuid, search character varying);

drop function if exists "public"."software_by_organisation"(organisation_id uuid);

drop function if exists "public"."software_by_organisation_search"(organisation_id uuid, search character varying);

drop function if exists "public"."software_overview"();

drop function if exists "public"."software_search"(search character varying);

CREATE OR REPLACE FUNCTION public.varchar_array_to_string(arr character varying[])
 RETURNS character varying
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
	DECLARE entry VARCHAR;
	DECLARE result VARCHAR := '';
	BEGIN
	IF arr IS NULL THEN
		RETURN NULL;
	END IF;
	FOREACH entry IN ARRAY arr LOOP
		CONTINUE WHEN entry IS NULL;
		IF result = '' THEN result := entry; ELSE result := result || ';' || entry; END IF;
	END LOOP;
	RETURN result;
	END;
$function$
;

create table "public"."remote_rsd" (
    "id" uuid not null default gen_random_uuid(),
    "label" character varying(50) not null,
    "domain" character varying(200) not null,
    "active" boolean default true,
    "scrape_interval_minutes" bigint default 5,
    "scraped_at" timestamp with time zone,
    "last_err_msg" character varying(1000),
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."remote_rsd" enable row level security;

create table "public"."remote_software" (
    "id" uuid not null default gen_random_uuid(),
    "remote_rsd_id" uuid not null,
    "remote_software_id" uuid not null,
    "slug" character varying(200) not null,
    "is_published" boolean not null default false,
    "brand_name" character varying(200) not null,
    "short_statement" character varying(300),
    "image_id" character varying(40),
    "updated_at" timestamp with time zone,
    "contributor_cnt" bigint,
    "mention_cnt" bigint,
    "keywords" citext[],
    "keywords_text" text,
    "prog_lang" text[],
    "licenses" character varying[],
    "scraped_at" timestamp with time zone not null
);


alter table "public"."remote_software" enable row level security;

create table "public"."rsd_info" (
    "key" character varying(100) not null,
    "value" character varying(250) not null,
    "public" boolean default true,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."rsd_info" enable row level security;

alter table "public"."organisation" add column "ror_names" character varying(200)[];

alter table "public"."organisation" add column "ror_names_string" character varying generated always as (varchar_array_to_string(ror_names)) stored;

CREATE UNIQUE INDEX remote_rsd_domain_key ON public.remote_rsd USING btree (domain);

CREATE UNIQUE INDEX remote_rsd_label_key ON public.remote_rsd USING btree (label);

CREATE UNIQUE INDEX remote_rsd_pkey ON public.remote_rsd USING btree (id);

CREATE UNIQUE INDEX remote_software_pkey ON public.remote_software USING btree (id);

CREATE UNIQUE INDEX remote_software_remote_rsd_id_remote_software_id_key ON public.remote_software USING btree (remote_rsd_id, remote_software_id);

CREATE UNIQUE INDEX rsd_info_pkey ON public.rsd_info USING btree (key);

alter table "public"."remote_rsd" add constraint "remote_rsd_pkey" PRIMARY KEY using index "remote_rsd_pkey";

alter table "public"."remote_software" add constraint "remote_software_pkey" PRIMARY KEY using index "remote_software_pkey";

alter table "public"."rsd_info" add constraint "rsd_info_pkey" PRIMARY KEY using index "rsd_info_pkey";

alter table "public"."remote_rsd" add constraint "remote_rsd_domain_key" UNIQUE using index "remote_rsd_domain_key";

alter table "public"."remote_rsd" add constraint "remote_rsd_label_check" CHECK ((length((label)::text) >= 3));

alter table "public"."remote_rsd" add constraint "remote_rsd_label_key" UNIQUE using index "remote_rsd_label_key";

alter table "public"."remote_rsd" add constraint "remote_rsd_scrape_interval_minutes_check" CHECK ((scrape_interval_minutes >= 5));

alter table "public"."remote_software" add constraint "remote_software_remote_rsd_id_fkey" FOREIGN KEY (remote_rsd_id) REFERENCES remote_rsd(id);

alter table "public"."remote_software" add constraint "remote_software_remote_rsd_id_remote_software_id_key" UNIQUE using index "remote_software_remote_rsd_id_remote_software_id_key";

alter table "public"."remote_software" add constraint "remote_software_slug_check" CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.aggregated_software_categories_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[], rsd_host_filter character varying DEFAULT ''::character varying)
 RETURNS TABLE(category character varying, category_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(categories) AS category,
	COUNT(DISTINCT(id)) AS category_cnt
FROM
	aggregated_software_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
	AND
		CASE
			WHEN rsd_host_filter = '' THEN TRUE
			WHEN rsd_host_filter IS NULL THEN rsd_host IS NULL
		ELSE
			rsd_host = rsd_host_filter
		END
GROUP BY
	category
;
$function$
;

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
	COALESCE(categories, '{}') @> category_filter
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
	COALESCE(categories, '{}') @> category_filter
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
	COALESCE(categories, '{}') @> category_filter
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
	COALESCE(categories, '{}') @> category_filter
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

CREATE OR REPLACE FUNCTION public.aggregated_software_overview()
 RETURNS TABLE(id uuid, rsd_host character varying, domain character varying, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], categories character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_overview.id,
	COALESCE((SELECT value FROM rsd_info WHERE KEY='remote_name'),NULL) AS rsd_host,
	NULL AS domain,
	software_overview.slug,
	software_overview.brand_name,
	software_overview.short_statement,
	software_overview.image_id,
	software_overview.updated_at,
	software_overview.contributor_cnt,
	software_overview.mention_cnt,
	software_overview.is_published,
	software_overview.keywords,
	software_overview.keywords_text,
	software_overview.prog_lang,
	software_overview.licenses,
	software_overview.categories
FROM
	software_overview()
UNION ALL
SELECT
	remote_software.id,
	remote_rsd.label AS rsd_host,
	remote_rsd.domain,
	remote_software.slug,
	remote_software.brand_name,
	remote_software.short_statement,
	remote_software.image_id,
	remote_software.updated_at,
	remote_software.contributor_cnt,
	remote_software.mention_cnt,
	remote_software.is_published,
	remote_software.keywords,
	remote_software.keywords_text,
	remote_software.prog_lang,
	remote_software.licenses,
	--	WE DO NOT USE/SCRAPE categories from remotes
	'{}' AS categories
FROM
	remote_software
INNER JOIN
	remote_rsd ON remote_rsd.id = remote_software.remote_rsd_id
;
$function$
;

CREATE OR REPLACE FUNCTION public.aggregated_software_search(search character varying)
 RETURNS TABLE(id uuid, rsd_host character varying, domain character varying, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], categories character varying[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	id, rsd_host, domain, slug, brand_name, short_statement, image_id,
	updated_at, contributor_cnt, mention_cnt, is_published, keywords,
	keywords_text, prog_lang, licenses, categories
FROM
	aggregated_software_overview()
WHERE
	aggregated_software_overview.brand_name ILIKE CONCAT('%', search, '%')
	OR
	aggregated_software_overview.slug ILIKE CONCAT('%', search, '%')
	OR
	aggregated_software_overview.short_statement ILIKE CONCAT('%', search, '%')
	OR
	aggregated_software_overview.keywords_text ILIKE CONCAT('%', search, '%')
ORDER BY
	CASE
		WHEN aggregated_software_overview.brand_name ILIKE search THEN 0
		WHEN aggregated_software_overview.brand_name ILIKE CONCAT(search, '%') THEN 1
		WHEN aggregated_software_overview.brand_name ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN aggregated_software_overview.slug ILIKE search THEN 0
		WHEN aggregated_software_overview.slug ILIKE CONCAT(search, '%') THEN 1
		WHEN aggregated_software_overview.slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN aggregated_software_overview.short_statement ILIKE search THEN 0
		WHEN aggregated_software_overview.short_statement ILIKE CONCAT(search, '%') THEN 1
		WHEN aggregated_software_overview.short_statement ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_categories(community_id uuid)
 RETURNS TABLE(software uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_software.software_id AS software,
		ARRAY_AGG(
			category.short_name
			ORDER BY short_name
		) AS category
	FROM
		category_for_software
	INNER JOIN
		category ON category.id = category_for_software.category_id
	WHERE
		category.community = community_id
	GROUP BY
		category_for_software.software_id;
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_categories_filter(community_id uuid, software_status request_status DEFAULT 'approved'::request_status, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(category character varying, category_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(categories) AS category,
	-- count per software on unique software id
	COUNT(DISTINCT(id)) AS category_cnt
FROM
	software_by_community_search(community_id,search_filter)
WHERE
	software_by_community_search.status = software_status
	AND
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	category
;
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_keywords_filter(community_id uuid, software_status request_status DEFAULT 'approved'::request_status, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	software_by_community_search(community_id,search_filter)
WHERE
	software_by_community_search.status = software_status
	AND
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_languages_filter(community_id uuid, software_status request_status DEFAULT 'approved'::request_status, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(prog_language text, prog_language_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(prog_lang) AS prog_language,
	COUNT(id) AS prog_language_cnt
FROM
	software_by_community_search(community_id,search_filter)
WHERE
	software_by_community_search.status = software_status
	AND
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_licenses_filter(community_id uuid, software_status request_status DEFAULT 'approved'::request_status, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(license character varying, license_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(licenses) AS license,
	COUNT(id) AS license_cnt
FROM
	software_by_community_search(community_id,search_filter)
WHERE
	software_by_community_search.status = software_status
	AND
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_category_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(category character varying, category_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(categories) AS category,
	COUNT(DISTINCT(id)) AS category_cnt
FROM
	highlight_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	category
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_keywords_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	highlight_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_languages_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(prog_language text, prog_language_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(prog_lang) AS prog_language,
	COUNT(id) AS prog_language_cnt
FROM
	highlight_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_licenses_filter(search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(license character varying, license_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(licenses) AS license,
	COUNT(id) AS license_cnt
FROM
	highlight_search(search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.index_of_ror_query(query character varying, organisation_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE
AS $function$
	DECLARE query_lower VARCHAR := LOWER(query);
	DECLARE ror_names VARCHAR[];
	DECLARE ror_name VARCHAR;
	DECLARE ror_name_lower VARCHAR;
	DECLARE min_index INTEGER;
	BEGIN
	ror_names := (SELECT organisation.ror_names FROM organisation WHERE id = organisation_id);
	IF ror_names IS NULL THEN
		RETURN -1;
	ELSE
		FOREACH ror_name IN ARRAY ror_names LOOP
			CONTINUE WHEN ror_name IS NULL;
			ror_name_lower := LOWER(ror_name);
			IF ror_name_lower = query_lower THEN
				RETURN 0;
			ELSIF POSITION(query_lower IN ror_name_lower) <> 0 THEN
				min_index := LEAST(min_index, POSITION(query_lower IN ror_name_lower));
			END IF;
		END LOOP;
	END IF;
	IF min_index IS NULL THEN
		RETURN -1;
	ELSE
		RETURN min_index;
	END IF;
	END;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_categories(organisation_id uuid)
 RETURNS TABLE(project uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_project.project_id AS project,
		ARRAY_AGG(
			category.short_name
			ORDER BY short_name
		) AS category
	FROM
		category_for_project
	INNER JOIN
		category ON category.id = category_for_project.category_id
	WHERE
		category.organisation = organisation_id
	GROUP BY
		category_for_project.project_id;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_categories_filter(organisation_id uuid, search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(category character varying, category_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(categories) AS category,
	-- count per project on unique project id
	COUNT(DISTINCT(id)) AS category_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
	COALESCE(categories, '{}') @> category_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	category
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_domains_filter(organisation_id uuid, search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(domain character varying, domain_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(research_domain) AS domain,
	COUNT(id) AS domain_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
	COALESCE(categories, '{}') @> category_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	domain
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_keywords_filter(organisation_id uuid, search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
	COALESCE(categories, '{}') @> category_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_participating_organisations_filter(organisation_id uuid, search_filter text DEFAULT ''::text, status_filter character varying DEFAULT ''::character varying, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(organisation character varying, organisation_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(participating_organisations) AS organisation,
	COUNT(id) AS organisation_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
	COALESCE(categories, '{}') @> category_filter
	AND
		CASE
			WHEN status_filter <> '' THEN project_status = status_filter
			ELSE true
		END
GROUP BY
	organisation
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_project_status_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], research_domain_filter character varying[] DEFAULT '{}'::character varying[], organisation_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(project_status character varying, project_status_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	project_status,
	COUNT(id) AS project_status_cnt
FROM
	projects_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(research_domain, '{}') @> research_domain_filter
	AND
	COALESCE(participating_organisations, '{}') @> organisation_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	project_status
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_categories(organisation_id uuid)
 RETURNS TABLE(software uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_software.software_id AS software,
		ARRAY_AGG(
			category.short_name
			ORDER BY short_name
		) AS category
	FROM
		category_for_software
	INNER JOIN
		category ON category.id = category_for_software.category_id
	WHERE
		category.organisation = organisation_id
	GROUP BY
		category_for_software.software_id;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_categories_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(category character varying, category_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(categories) AS category,
	-- count per software on unique software id
	COUNT(DISTINCT(id)) AS category_cnt
FROM
	software_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	category
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_keywords_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(keyword citext, keyword_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(keywords) AS keyword,
	COUNT(id) AS keyword_cnt
FROM
	software_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_languages_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(prog_language text, prog_language_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(prog_lang) AS prog_language,
	COUNT(id) AS prog_language_cnt
FROM
	software_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.org_software_licenses_filter(organisation_id uuid, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[], category_filter character varying[] DEFAULT '{}'::character varying[])
 RETURNS TABLE(license character varying, license_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	UNNEST(licenses) AS license,
	COUNT(id) AS license_cnt
FROM
	software_by_organisation_search(organisation_id,search_filter)
WHERE
	COALESCE(keywords, '{}') @> keyword_filter
	AND
	COALESCE(prog_lang, '{}') @> prog_lang_filter
	AND
	COALESCE(licenses, '{}') @> license_filter
	AND
	COALESCE(categories, '{}') @> category_filter
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_remote_rsd()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_rsd_info()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_remote_rsd()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_rsd_info()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_categories()
 RETURNS TABLE(software uuid, category character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		category_for_software.software_id AS software,
		ARRAY_AGG(
			category.short_name
			ORDER BY short_name
		) AS category
	FROM
		category_for_software
	INNER JOIN
		category ON category.id = category_for_software.category_id
	WHERE
	-- FILTER FOR GLOBAL CATEGORIES
		category.community IS NULL AND category.organisation IS NULL
	GROUP BY
		category_for_software.software_id;
$function$
;



CREATE OR REPLACE FUNCTION public.global_search(query character varying)
 RETURNS TABLE(slug character varying, domain character varying, rsd_host character varying, name character varying, source text, is_published boolean, rank integer, index_found integer)
 LANGUAGE sql
 STABLE
AS $function$
	-- AGGREGATED SOFTWARE search
	SELECT
		aggregated_software_search.slug,
		aggregated_software_search.domain,
		aggregated_software_search.rsd_host,
		aggregated_software_search.brand_name AS name,
		'software' AS "source",
		aggregated_software_search.is_published,
		(CASE
			WHEN aggregated_software_search.slug ILIKE query OR aggregated_software_search.brand_name ILIKE query THEN 0
			WHEN aggregated_software_search.keywords_text ILIKE CONCAT('%', query, '%') THEN 1
			WHEN aggregated_software_search.slug ILIKE CONCAT(query, '%') OR aggregated_software_search.brand_name ILIKE CONCAT(query, '%') THEN 2
			WHEN aggregated_software_search.slug ILIKE CONCAT('%', query, '%') OR aggregated_software_search.brand_name ILIKE CONCAT('%', query, '%') THEN 3
			ELSE 4
		END) AS rank,
		(CASE
			WHEN aggregated_software_search.slug ILIKE query OR aggregated_software_search.brand_name ILIKE query THEN 0
			WHEN aggregated_software_search.keywords_text ILIKE CONCAT('%', query, '%') THEN 0
			WHEN aggregated_software_search.slug ILIKE CONCAT(query, '%') OR aggregated_software_search.brand_name ILIKE CONCAT(query, '%') THEN 0
			WHEN aggregated_software_search.slug ILIKE CONCAT('%', query, '%') OR aggregated_software_search.brand_name ILIKE CONCAT('%', query, '%')
				THEN LEAST(NULLIF(POSITION(LOWER(query) IN aggregated_software_search.slug), 0), NULLIF(POSITION(LOWER(query) IN LOWER(aggregated_software_search.brand_name)), 0))
			ELSE 0
		END) AS index_found
	FROM
		aggregated_software_search(query)
	UNION ALL
	-- PROJECT search
	SELECT
		project.slug,
		NULL AS domain,
		NULL as rsd_host,
		project.title AS name,
		'projects' AS "source",
		project.is_published,
		(CASE
			WHEN project.slug ILIKE query OR project.title ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 1
			WHEN project.slug ILIKE CONCAT(query, '%') OR project.title ILIKE CONCAT(query, '%') THEN 2
			WHEN project.slug ILIKE CONCAT('%', query, '%') OR project.title ILIKE CONCAT('%', query, '%') THEN 3
			ELSE 4
		END) AS rank,
		(CASE
			WHEN project.slug ILIKE query OR project.title ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 0
			WHEN project.slug ILIKE CONCAT(query, '%') OR project.title ILIKE CONCAT(query, '%') THEN 0
			WHEN project.slug ILIKE CONCAT('%', query, '%') OR project.title ILIKE CONCAT('%', query, '%')
				THEN LEAST(NULLIF(POSITION(LOWER(query) IN project.slug), 0), NULLIF(POSITION(LOWER(query) IN LOWER(project.title)), 0))
			ELSE 0
		END) AS index_found
	FROM
		project
	LEFT JOIN keyword_for_project ON keyword_for_project.project = project.id
	LEFT JOIN keyword ON keyword.id = keyword_for_project.keyword
	GROUP BY project.id
	HAVING
		project.slug ILIKE CONCAT('%', query, '%')
		OR
		project.title ILIKE CONCAT('%', query, '%')
		OR
		project.subtitle ILIKE CONCAT('%', query, '%')
		OR
		BOOL_OR(keyword.value ILIKE CONCAT('%', query, '%'))
	UNION ALL
	-- ORGANISATION search
	SELECT
		organisation.slug,
		NULL AS domain,
		NULL as rsd_host,
		organisation."name",
		'organisations' AS "source",
		TRUE AS is_published,
		(CASE
			WHEN organisation.slug ILIKE query OR organisation."name" ILIKE query OR index_of_ror_query(query, organisation.id) = 0 THEN 0
			WHEN organisation.slug ILIKE CONCAT(query, '%') OR organisation."name" ILIKE CONCAT(query, '%') OR index_of_ror_query(query, organisation.id) = 1 THEN 2
			ELSE 3
		END) AS rank,
		(CASE
			WHEN organisation.slug ILIKE query OR organisation."name" ILIKE query OR index_of_ror_query(query, organisation.id) = 0 THEN 0
			WHEN organisation.slug ILIKE CONCAT(query, '%') OR organisation."name" ILIKE CONCAT(query, '%') OR index_of_ror_query(query, organisation.id) = 1 THEN 0
			ELSE
				LEAST(NULLIF(POSITION(LOWER(query) IN organisation.slug), 0), NULLIF(POSITION(LOWER(query) IN LOWER(organisation."name")), 0), NULLIF(index_of_ror_query(query, organisation.id), -1))
		END) AS index_found
	FROM
		organisation
	WHERE
	-- ONLY TOP LEVEL ORGANISATIONS
		organisation.parent IS NULL
		AND
		(organisation.slug ILIKE CONCAT('%', query, '%') OR organisation."name" ILIKE CONCAT('%', query, '%') OR index_of_ror_query(query, organisation.id) >= 0)
	UNION ALL
	-- COMMUNITY search
	SELECT
		community.slug,
		NULL AS domain,
		NULL as rsd_host,
		community."name",
		'communities' AS "source",
		TRUE AS is_published,
		(CASE
			WHEN community.slug ILIKE query OR community."name" ILIKE query THEN 0
			WHEN community.slug ILIKE CONCAT(query, '%') OR community."name" ILIKE CONCAT(query, '%') THEN 2
			ELSE 3
		END) AS rank,
		(CASE
			WHEN community.slug ILIKE query OR community."name" ILIKE query THEN 0
			WHEN community.slug ILIKE CONCAT(query, '%') OR community."name" ILIKE CONCAT(query, '%') THEN 0
			ELSE
				LEAST(NULLIF(POSITION(LOWER(query) IN community.slug), 0), NULLIF(POSITION(LOWER(query) IN LOWER(community."name")), 0))
		END) AS index_found
	FROM
		community
	WHERE
		community.slug ILIKE CONCAT('%', query, '%') OR community."name" ILIKE CONCAT('%', query, '%');
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_overview()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], categories character varying[], "position" integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_overview.id,
	software_overview.slug,
	software_overview.brand_name,
	software_overview.short_statement,
	software_overview.image_id,
	software_overview.updated_at,
	software_overview.contributor_cnt,
	software_overview.mention_cnt,
	software_overview.is_published,
	software_overview.keywords,
	software_overview.keywords_text,
	software_overview.prog_lang,
	software_overview.licenses,
	software_overview.categories,
	software_highlight.position
FROM
	software_overview()
RIGHT JOIN
	software_highlight ON software_overview.id=software_highlight.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, is_published boolean, contributor_cnt bigint, mention_cnt bigint, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], categories character varying[], "position" integer)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_search.id,
	software_search.slug,
	software_search.brand_name,
	software_search.short_statement,
	software_search.image_id,
	software_search.updated_at,
	software_search.is_published,
	software_search.contributor_cnt,
	software_search.mention_cnt,
	software_search.keywords,
	software_search.keywords_text,
	software_search.prog_lang,
	software_search.licenses,
	software_search.categories,
	software_highlight.position
FROM
	software_search(search)
INNER JOIN
	software_highlight ON software_search.id=software_highlight.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.organisations_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, parent uuid, primary_maintainer uuid, name character varying, short_description character varying, country character varying, ror_id character varying, website character varying, is_tenant boolean, ror_names_string character varying, rsd_path character varying, parent_names character varying, logo_id character varying, software_cnt bigint, project_cnt bigint, children_cnt bigint, release_cnt bigint, score bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	organisation.id,
	organisation.slug,
	organisation.parent,
	organisation.primary_maintainer,
	organisation.name,
	organisation.short_description,
	organisation.country,
	organisation.ror_id,
	organisation.website,
	organisation.is_tenant,
	organisation.ror_names_string,
	organisation_route.rsd_path,
	organisation_route.parent_names,
	organisation.logo_id,
	software_count_by_organisation.software_cnt,
	project_count_by_organisation.project_cnt,
	children_count_by_organisation.children_cnt,
	release_cnt_by_organisation.release_cnt,
	(
		COALESCE(software_count_by_organisation.software_cnt,0) +
		COALESCE(project_count_by_organisation.project_cnt,0)
	) as score
FROM
	organisation
LEFT JOIN
	organisation_route(organisation.id) ON organisation_route.organisation = organisation.id
LEFT JOIN
	software_count_by_organisation(public) ON software_count_by_organisation.organisation = organisation.id
LEFT JOIN
	project_count_by_organisation(public) ON project_count_by_organisation.organisation = organisation.id
LEFT JOIN
	children_count_by_organisation() ON children_count_by_organisation.parent = organisation.id
LEFT JOIN
	release_cnt_by_organisation() ON release_cnt_by_organisation.organisation_id = organisation.id
;
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, is_featured boolean, status relation_status, keywords citext[], research_domain character varying[], participating_organisations character varying[], categories character varying[], impact_cnt integer, output_cnt integer, project_status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (project.id)
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	project.date_start,
	project.date_end,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	project_for_organisation.is_featured,
	project_for_organisation.status,
	keyword_filter_for_project.keywords,
	research_domain_filter_for_project.research_domain,
	project_participating_organisations.organisations AS participating_organisations,
	org_project_categories.category AS categories,
	COALESCE(count_project_impact.impact_cnt, 0) AS impact_cnt,
	COALESCE(count_project_output.output_cnt, 0) AS output_cnt,
	project_status.status
FROM
	project
LEFT JOIN
	project_for_organisation ON project.id = project_for_organisation.project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
LEFT JOIN
	project_participating_organisations() ON project.id=project_participating_organisations.project
LEFT JOIN
	org_project_categories(organisation_id) ON project.id=org_project_categories.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
LEFT JOIN
	project_status() ON project.id=project_status.project
WHERE
	project_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	)
;
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_organisation_search(organisation_id uuid, search character varying)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, is_featured boolean, status relation_status, keywords citext[], research_domain character varying[], participating_organisations character varying[], categories character varying[], impact_cnt integer, output_cnt integer, project_status character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (project.id)
	project.id,
	project.slug,
	project.title,
	project.subtitle,
	project.date_start,
	project.date_end,
	project.updated_at,
	project.is_published,
	project.image_contain,
	project.image_id,
	project_for_organisation.is_featured,
	project_for_organisation.status,
	keyword_filter_for_project.keywords,
	research_domain_filter_for_project.research_domain,
	project_participating_organisations.organisations AS participating_organisations,
	org_project_categories.category AS categories,
	COALESCE(count_project_impact.impact_cnt, 0) AS impact_cnt,
	COALESCE(count_project_output.output_cnt, 0) AS output_cnt,
	project_status.status
FROM
	project
LEFT JOIN
	project_for_organisation ON project.id = project_for_organisation.project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
LEFT JOIN
	project_participating_organisations() ON project.id=project_participating_organisations.project
LEFT JOIN
	org_project_categories(organisation_id) ON project.id=org_project_categories.project
LEFT JOIN
	count_project_impact() ON project.id = count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id = count_project_output.project
LEFT JOIN
	project_status() ON project.id=project_status.project
WHERE
	project_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	) AND (
		project.title ILIKE CONCAT('%', search, '%')
		OR
		project.slug ILIKE CONCAT('%', search, '%')
		OR
		project.subtitle ILIKE CONCAT('%', search, '%')
		OR
		keyword_filter_for_project.keywords_text ILIKE CONCAT('%', search, '%')
		OR
		research_domain_filter_for_project.research_domain_text ILIKE CONCAT('%', search, '%')
	)
ORDER BY
	project.id,
	CASE
		WHEN title ILIKE search THEN 0
		WHEN title ILIKE CONCAT(search, '%') THEN 1
		WHEN title ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN subtitle ILIKE search THEN 0
		WHEN subtitle ILIKE CONCAT(search, '%') THEN 1
		WHEN subtitle ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_community(community_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, status request_status, keywords citext[], prog_lang text[], licenses character varying[], categories character varying[], contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (software.id)
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.is_published,
	software.updated_at,
	software_for_community.status,
	keyword_filter_for_software.keywords,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	com_software_categories.category AS categories,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt
FROM
	software
LEFT JOIN
	software_for_community ON software.id=software_for_community.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
LEFT JOIN
	com_software_categories(community_id) ON software.id=com_software_categories.software
WHERE
	software_for_community.community = community_id
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_community_search(community_id uuid, search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, status request_status, keywords citext[], prog_lang text[], licenses character varying[], categories character varying[], contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (software.id)
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.is_published,
	software.updated_at,
	software_for_community.status,
	keyword_filter_for_software.keywords,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	com_software_categories.category AS categories,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt
FROM
	software
LEFT JOIN
	software_for_community ON software.id=software_for_community.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
LEFT JOIN
	com_software_categories(community_id) ON software.id=com_software_categories.software
WHERE
	software_for_community.community = community_id AND (
		software.brand_name ILIKE CONCAT('%', search, '%')
		OR
		software.slug ILIKE CONCAT('%', search, '%')
		OR
		software.short_statement ILIKE CONCAT('%', search, '%')
		OR
		keyword_filter_for_software.keywords_text ILIKE CONCAT('%', search, '%')
	)
ORDER BY
	software.id,
	CASE
		WHEN brand_name ILIKE search THEN 0
		WHEN brand_name ILIKE CONCAT(search, '%') THEN 1
		WHEN brand_name ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN short_statement ILIKE search THEN 0
		WHEN short_statement ILIKE CONCAT(search, '%') THEN 1
		WHEN short_statement ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, is_featured boolean, status relation_status, keywords citext[], prog_lang text[], licenses character varying[], categories character varying[], contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (software.id)
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.is_published,
	software.updated_at,
	software_for_organisation.is_featured,
	software_for_organisation.status,
	keyword_filter_for_software.keywords,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	org_software_categories.category AS categories,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt
FROM
	software
LEFT JOIN
	software_for_organisation ON software.id=software_for_organisation.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
LEFT JOIN
	org_software_categories(organisation_id) ON software.id=org_software_categories.software
WHERE
	software_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	)
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_organisation_search(organisation_id uuid, search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, is_featured boolean, status relation_status, keywords citext[], prog_lang text[], licenses character varying[], categories character varying[], contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (software.id)
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.image_id,
	software.is_published,
	software.updated_at,
	software_for_organisation.is_featured,
	software_for_organisation.status,
	keyword_filter_for_software.keywords,
	prog_lang_filter_for_software.prog_lang,
	license_filter_for_software.licenses,
	org_software_categories.category AS categories,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt
FROM
	software
LEFT JOIN
	software_for_organisation ON software.id=software_for_organisation.software
LEFT JOIN
	count_software_contributors() ON software.id=count_software_contributors.software
LEFT JOIN
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
LEFT JOIN
	org_software_categories(organisation_id) ON software.id=org_software_categories.software
WHERE
	software_for_organisation.organisation IN (
		SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
	) AND (
		software.brand_name ILIKE CONCAT('%', search, '%')
		OR
		software.slug ILIKE CONCAT('%', search, '%')
		OR
		software.short_statement ILIKE CONCAT('%', search, '%')
		OR
		keyword_filter_for_software.keywords_text ILIKE CONCAT('%', search, '%')
	)
ORDER BY
	software.id,
	CASE
		WHEN brand_name ILIKE search THEN 0
		WHEN brand_name ILIKE CONCAT(search, '%') THEN 1
		WHEN brand_name ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN short_statement ILIKE search THEN 0
		WHEN short_statement ILIKE CONCAT(search, '%') THEN 1
		WHEN short_statement ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
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
	count_software_mentions.mention_cnt,
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
	count_software_mentions() ON software.id=count_software_mentions.software
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

CREATE OR REPLACE FUNCTION public.software_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, is_published boolean, contributor_cnt bigint, mention_cnt bigint, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], categories character varying[])
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
	count_software_mentions.mention_cnt,
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
	count_software_mentions() ON software.id=count_software_mentions.software
LEFT JOIN
	keyword_filter_for_software() ON software.id=keyword_filter_for_software.software
LEFT JOIN
	prog_lang_filter_for_software() ON software.id=prog_lang_filter_for_software.software
LEFT JOIN
	license_filter_for_software() ON software.id=license_filter_for_software.software
LEFT JOIN
	software_categories() ON software.id=software_categories.software
WHERE
	software.brand_name ILIKE CONCAT('%', search, '%')
	OR
	software.slug ILIKE CONCAT('%', search, '%')
	OR
	software.short_statement ILIKE CONCAT('%', search, '%')
	OR
	keyword_filter_for_software.keywords_text ILIKE CONCAT('%', search, '%')
ORDER BY
	CASE
		WHEN brand_name ILIKE search THEN 0
		WHEN brand_name ILIKE CONCAT(search, '%') THEN 1
		WHEN brand_name ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN slug ILIKE search THEN 0
		WHEN slug ILIKE CONCAT(search, '%') THEN 1
		WHEN slug ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END,
	CASE
		WHEN short_statement ILIKE search THEN 0
		WHEN short_statement ILIKE CONCAT(search, '%') THEN 1
		WHEN short_statement ILIKE CONCAT('%', search, '%') THEN 2
		ELSE 3
	END
;
$function$
;

create policy "admin_all_rights"
on "public"."remote_rsd"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."remote_rsd"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "admin_all_rights"
on "public"."remote_software"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."remote_software"
as permissive
for select
to rsd_web_anon, rsd_user
using (is_published);


create policy "admin_all_rights"
on "public"."rsd_info"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."rsd_info"
as permissive
for select
to rsd_web_anon, rsd_user
using ((public = true));


CREATE TRIGGER sanitise_insert_remote_rsd BEFORE INSERT ON public.remote_rsd FOR EACH ROW EXECUTE FUNCTION sanitise_insert_remote_rsd();

CREATE TRIGGER sanitise_update_remote_rsd BEFORE UPDATE ON public.remote_rsd FOR EACH ROW EXECUTE FUNCTION sanitise_update_remote_rsd();

CREATE TRIGGER sanitise_insert_rsd_info BEFORE INSERT ON public.rsd_info FOR EACH ROW EXECUTE FUNCTION sanitise_insert_rsd_info();

CREATE TRIGGER sanitise_update_rsd_info BEFORE UPDATE ON public.rsd_info FOR EACH ROW EXECUTE FUNCTION sanitise_update_rsd_info();

