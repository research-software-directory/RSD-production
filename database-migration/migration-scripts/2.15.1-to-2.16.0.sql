create type "public"."request_status" as enum ('pending', 'approved', 'rejected');

create table "public"."community" (
    "id" uuid not null default gen_random_uuid(),
    "slug" character varying(200) not null,
    "name" character varying(200) not null,
    "short_description" character varying(300),
    "description" character varying(10000),
    "primary_maintainer" uuid,
    "logo_id" character varying(40),
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."community" enable row level security;

create table "public"."invite_maintainer_for_community" (
    "id" uuid not null default gen_random_uuid(),
    "community" uuid not null,
    "created_by" uuid,
    "claimed_by" uuid,
    "claimed_at" timestamp with time zone,
    "created_at" timestamp with time zone not null default LOCALTIMESTAMP,
    "expires_at" timestamp with time zone not null generated always as (((created_at AT TIME ZONE 'UTC'::text) + '31 days'::interval)) stored
);


alter table "public"."invite_maintainer_for_community" enable row level security;

create table "public"."keyword_for_community" (
    "community" uuid not null,
    "keyword" uuid not null
);


alter table "public"."keyword_for_community" enable row level security;

create table "public"."maintainer_for_community" (
    "maintainer" uuid not null,
    "community" uuid not null
);


alter table "public"."maintainer_for_community" enable row level security;

create table "public"."software_for_community" (
    "software" uuid not null,
    "community" uuid not null,
    "status" request_status not null default 'pending'::request_status
);


alter table "public"."software_for_community" enable row level security;

alter table "public"."invite_maintainer_for_organisation" add column "expires_at" timestamp with time zone not null generated always as (((created_at AT TIME ZONE 'UTC'::text) + '31 days'::interval)) stored;

alter table "public"."invite_maintainer_for_project" add column "expires_at" timestamp with time zone not null generated always as (((created_at AT TIME ZONE 'UTC'::text) + '31 days'::interval)) stored;

alter table "public"."invite_maintainer_for_software" add column "expires_at" timestamp with time zone not null generated always as (((created_at AT TIME ZONE 'UTC'::text) + '31 days'::interval)) stored;

CREATE UNIQUE INDEX community_pkey ON public.community USING btree (id);

CREATE UNIQUE INDEX community_slug_key ON public.community USING btree (slug);

CREATE UNIQUE INDEX invite_maintainer_for_community_pkey ON public.invite_maintainer_for_community USING btree (id);

CREATE UNIQUE INDEX keyword_for_community_pkey ON public.keyword_for_community USING btree (community, keyword);

CREATE UNIQUE INDEX maintainer_for_community_pkey ON public.maintainer_for_community USING btree (maintainer, community);

CREATE UNIQUE INDEX software_for_community_pkey ON public.software_for_community USING btree (software, community);

alter table "public"."community" add constraint "community_pkey" PRIMARY KEY using index "community_pkey";

alter table "public"."invite_maintainer_for_community" add constraint "invite_maintainer_for_community_pkey" PRIMARY KEY using index "invite_maintainer_for_community_pkey";

alter table "public"."keyword_for_community" add constraint "keyword_for_community_pkey" PRIMARY KEY using index "keyword_for_community_pkey";

alter table "public"."maintainer_for_community" add constraint "maintainer_for_community_pkey" PRIMARY KEY using index "maintainer_for_community_pkey";

alter table "public"."software_for_community" add constraint "software_for_community_pkey" PRIMARY KEY using index "software_for_community_pkey";

alter table "public"."community" add constraint "community_logo_id_fkey" FOREIGN KEY (logo_id) REFERENCES image(id);

alter table "public"."community" add constraint "community_primary_maintainer_fkey" FOREIGN KEY (primary_maintainer) REFERENCES account(id);

alter table "public"."community" add constraint "community_slug_check" CHECK (((slug)::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text));

alter table "public"."community" add constraint "community_slug_key" UNIQUE using index "community_slug_key";

alter table "public"."invite_maintainer_for_community" add constraint "invite_maintainer_for_community_claimed_by_fkey" FOREIGN KEY (claimed_by) REFERENCES account(id);

alter table "public"."invite_maintainer_for_community" add constraint "invite_maintainer_for_community_community_fkey" FOREIGN KEY (community) REFERENCES community(id);

alter table "public"."invite_maintainer_for_community" add constraint "invite_maintainer_for_community_created_by_fkey" FOREIGN KEY (created_by) REFERENCES account(id);

alter table "public"."keyword_for_community" add constraint "keyword_for_community_community_fkey" FOREIGN KEY (community) REFERENCES community(id);

alter table "public"."keyword_for_community" add constraint "keyword_for_community_keyword_fkey" FOREIGN KEY (keyword) REFERENCES keyword(id);

alter table "public"."maintainer_for_community" add constraint "maintainer_for_community_community_fkey" FOREIGN KEY (community) REFERENCES community(id);

alter table "public"."maintainer_for_community" add constraint "maintainer_for_community_maintainer_fkey" FOREIGN KEY (maintainer) REFERENCES account(id);

alter table "public"."software_for_community" add constraint "software_for_community_community_fkey" FOREIGN KEY (community) REFERENCES community(id);

alter table "public"."software_for_community" add constraint "software_for_community_software_fkey" FOREIGN KEY (software) REFERENCES software(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.accept_invitation_community(invitation uuid)
 RETURNS TABLE(id uuid, name character varying, slug character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE invitation_row invite_maintainer_for_community%ROWTYPE;
DECLARE account UUID;
BEGIN
	account = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
	IF account IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please login first';
	END IF;

	IF invitation IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide an invitation id';
	END IF;

	SELECT * FROM
		invite_maintainer_for_community
	WHERE
		invite_maintainer_for_community.id = invitation INTO invitation_row;

	IF invitation_row.id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' does not exist';
	END IF;

	IF invitation_row.claimed_by IS NOT NULL OR invitation_row.claimed_at IS NOT NULL OR
		invitation_row.expires_at < CURRENT_TIMESTAMP THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' is expired';
	END IF;

-- Only use the invitation if not already a maintainer
	IF NOT EXISTS(
		SELECT
			maintainer_for_community.maintainer
		FROM
			maintainer_for_community
		WHERE
			maintainer_for_community.maintainer=account AND maintainer_for_community.community=invitation_row.community
		UNION
		SELECT
			community.primary_maintainer AS maintainer
		FROM
			community
		WHERE
			community.primary_maintainer=account AND community.id=invitation_row.community
		LIMIT 1
	) THEN

		UPDATE invite_maintainer_for_community
			SET claimed_by = account, claimed_at = LOCALTIMESTAMP
			WHERE invite_maintainer_for_community.id = invitation;

		INSERT INTO maintainer_for_community
			VALUES (account, invitation_row.community);

	END IF;

	RETURN QUERY
		SELECT
			community.id,
			community.name,
			community.slug
		FROM
			community
		WHERE
			community.id = invitation_row.community;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_keywords_filter(community_id uuid, software_status request_status DEFAULT 'approved'::request_status, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
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
GROUP BY
	keyword
;
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_languages_filter(community_id uuid, software_status request_status DEFAULT 'approved'::request_status, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
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
GROUP BY
	prog_language
;
$function$
;

CREATE OR REPLACE FUNCTION public.com_software_licenses_filter(community_id uuid, software_status request_status DEFAULT 'approved'::request_status, search_filter text DEFAULT ''::text, keyword_filter citext[] DEFAULT '{}'::citext[], prog_lang_filter text[] DEFAULT '{}'::text[], license_filter character varying[] DEFAULT '{}'::character varying[])
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
GROUP BY
	license
;
$function$
;

CREATE OR REPLACE FUNCTION public.communities_of_current_maintainer()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
	SELECT
		id
	FROM
		community
	WHERE
		primary_maintainer = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account')
	UNION
	SELECT
		community
	FROM
		maintainer_for_community
	WHERE
		maintainer = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
$function$
;

CREATE OR REPLACE FUNCTION public.communities_of_software(software_id uuid)
 RETURNS TABLE(id uuid, slug character varying, status request_status, name character varying, short_description character varying, logo_id character varying, primary_maintainer uuid, software_cnt bigint, pending_cnt bigint, rejected_cnt bigint, keywords citext[], description character varying, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	community.id,
	community.slug,
	software_for_community.status,
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
INNER JOIN
	software_for_community ON community.id = software_for_community.community
WHERE
	software_for_community.software = software_id
;
$function$
;

CREATE OR REPLACE FUNCTION public.communities_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, name character varying, short_description character varying, logo_id character varying, primary_maintainer uuid, software_cnt bigint, pending_cnt bigint, rejected_cnt bigint, keywords citext[], description character varying, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
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
	software_count_by_community(public) ON community.id = software_count_by_community.community
LEFT JOIN
	pending_count_by_community() ON community.id = pending_count_by_community.community
LEFT JOIN
	rejected_count_by_community() ON community.id = rejected_count_by_community.community
LEFT JOIN
	keyword_filter_for_community() ON community.id=keyword_filter_for_community.community
;
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_count_for_community()
 RETURNS TABLE(id uuid, keyword citext, cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_count.cnt
	FROM
		keyword
	LEFT JOIN
		(SELECT
				keyword_for_community.keyword,
				COUNT(keyword_for_community.keyword) AS cnt
			FROM
				keyword_for_community
			GROUP BY keyword_for_community.keyword
		) AS keyword_count ON keyword.id = keyword_count.keyword;
$function$
;

CREATE OR REPLACE FUNCTION public.keyword_filter_for_community()
 RETURNS TABLE(community uuid, keywords citext[], keywords_text text)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword_for_community.community AS community,
		ARRAY_AGG(
			keyword.value
			ORDER BY value
		) AS keywords,
		STRING_AGG(
			keyword.value,' '
			ORDER BY value
		) AS keywords_text
	FROM
		keyword_for_community
	INNER JOIN
		keyword ON keyword.id = keyword_for_community.keyword
	GROUP BY keyword_for_community.community;
$function$
;

CREATE OR REPLACE FUNCTION public.keywords_by_community()
 RETURNS TABLE(id uuid, keyword citext, community uuid)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		keyword.id,
		keyword.value AS keyword,
		keyword_for_community.community
	FROM
		keyword_for_community
	INNER JOIN
		keyword ON keyword.id = keyword_for_community.keyword;
$function$
;

CREATE OR REPLACE FUNCTION public.maintainers_of_community(community_id uuid)
 RETURNS TABLE(maintainer uuid, name character varying[], email character varying[], affiliation character varying[], is_primary boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE account_authenticated UUID;
BEGIN
	account_authenticated = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
	IF account_authenticated IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please login first';
	END IF;

	IF community_id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide a community id';
	END IF;

	IF NOT community_id IN (SELECT * FROM communities_of_current_maintainer()) AND
		CURRENT_USER IS DISTINCT FROM 'rsd_admin' AND (
			SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER
		) IS DISTINCT FROM TRUE THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not a maintainer of this community';
	END IF;

	RETURN QUERY
	-- primary maintainer of community
	SELECT
		community.primary_maintainer AS maintainer,
		ARRAY_AGG(login_for_account."name") AS name,
		ARRAY_AGG(login_for_account.email) AS email,
		ARRAY_AGG(login_for_account.home_organisation) AS affiliation,
		TRUE AS is_primary
	FROM
		community
	INNER JOIN
		login_for_account ON community.primary_maintainer = login_for_account.account
	WHERE
		community.id = community_id
	GROUP BY
		community.id,community.primary_maintainer
	-- append second selection
	UNION
	-- other maintainers of community
	SELECT
		maintainer_for_community.maintainer,
		ARRAY_AGG(login_for_account."name") AS name,
		ARRAY_AGG(login_for_account.email) AS email,
		ARRAY_AGG(login_for_account.home_organisation) AS affiliation,
		FALSE AS is_primary
	FROM
		maintainer_for_community
	INNER JOIN
		login_for_account ON maintainer_for_community.maintainer = login_for_account.account
	WHERE
		maintainer_for_community.community = community_id
	GROUP BY
		maintainer_for_community.community, maintainer_for_community.maintainer
	-- primary as first record
	ORDER BY is_primary DESC;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.pending_count_by_community()
 RETURNS TABLE(community uuid, pending_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_for_community.community,
	COUNT(DISTINCT software_for_community.software) AS pending_cnt
FROM
	software_for_community
WHERE
	software_for_community.status = 'pending'
GROUP BY
	software_for_community.community
;
$function$
;

CREATE OR REPLACE FUNCTION public.rejected_count_by_community()
 RETURNS TABLE(community uuid, rejected_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_for_community.community,
	COUNT(DISTINCT software_for_community.software) AS rejected_cnt
FROM
	software_for_community
WHERE
	software_for_community.status = 'rejected'
GROUP BY
	software_for_community.community
;
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_community()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;

	IF CURRENT_USER = 'rsd_admin' OR (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) THEN
		RETURN NEW;
	END IF;

	RAISE EXCEPTION USING MESSAGE = 'You are not allowed to add this community';
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_invite_maintainer_for_community()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	NEW.claimed_by = NULL;
	NEW.claimed_at = NULL;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_community()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;

	IF NEW.slug IS DISTINCT FROM OLD.slug AND CURRENT_USER IS DISTINCT FROM 'rsd_admin' AND (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) IS DISTINCT FROM TRUE THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to change the slug';
	END IF;

	IF NEW.primary_maintainer IS DISTINCT FROM OLD.primary_maintainer AND CURRENT_USER IS DISTINCT FROM 'rsd_admin' AND (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) IS DISTINCT FROM TRUE THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to change the primary maintainer for community ' || OLD.name;
	END IF;

	RETURN NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_invite_maintainer_for_community()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.community = OLD.community;
	NEW.created_by = OLD.created_by;
	NEW.created_at = OLD.created_at;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_software_for_community()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.software = OLD.software;
	NEW.community = OLD.community;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_community(community_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, status request_status, keywords citext[], prog_lang text[], licenses character varying[], contributor_cnt bigint, mention_cnt bigint)
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
WHERE
	software_for_community.community = community_id
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_community_search(community_id uuid, search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, status request_status, keywords citext[], prog_lang text[], licenses character varying[], contributor_cnt bigint, mention_cnt bigint)
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

CREATE OR REPLACE FUNCTION public.software_count_by_community(public boolean DEFAULT true)
 RETURNS TABLE(community uuid, software_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software_for_community.community,
	COUNT(DISTINCT software_for_community.software) AS software_cnt
FROM
	software_for_community
WHERE
	software_for_community.status = 'approved' AND (
		NOT public OR software IN (SELECT id FROM software WHERE is_published)
	)
GROUP BY
	software_for_community.community
;
$function$
;

CREATE OR REPLACE FUNCTION public.accept_invitation_organisation(invitation uuid)
 RETURNS TABLE(id uuid, name character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE invitation_row invite_maintainer_for_organisation%ROWTYPE;
DECLARE account UUID;
BEGIN
	account = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
	IF account IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please login first';
	END IF;

	IF invitation IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide an invitation id';
	END IF;

	SELECT * FROM invite_maintainer_for_organisation WHERE invite_maintainer_for_organisation.id = invitation INTO invitation_row;
	IF invitation_row.id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' does not exist';
	END IF;

	IF invitation_row.claimed_by IS NOT NULL OR invitation_row.claimed_at IS NOT NULL OR invitation_row.expires_at < CURRENT_TIMESTAMP THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' is expired';
	END IF;

-- Only use the invitation if not already a maintainer
	IF NOT EXISTS(
		SELECT
			maintainer_for_organisation.maintainer
		FROM
			maintainer_for_organisation
		WHERE
			maintainer_for_organisation.maintainer=account AND maintainer_for_organisation.organisation=invitation_row.organisation
		UNION
		SELECT
			organisation.primary_maintainer AS maintainer
		FROM
			organisation
		WHERE
			organisation.primary_maintainer=account AND organisation.id=invitation_row.organisation
		LIMIT 1
	) THEN
		UPDATE invite_maintainer_for_organisation SET claimed_by = account, claimed_at = LOCALTIMESTAMP WHERE invite_maintainer_for_organisation.id = invitation;
		INSERT INTO maintainer_for_organisation VALUES (account, invitation_row.organisation);
	END IF;

	RETURN QUERY
		SELECT
			organisation.id,
			organisation.name
		FROM
			organisation
		WHERE
			organisation.id = invitation_row.organisation;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.accept_invitation_project(invitation uuid)
 RETURNS TABLE(title character varying, slug character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE invitation_row invite_maintainer_for_project%ROWTYPE;
DECLARE account UUID;
BEGIN
	account = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
	IF account IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please login first';
	END IF;

	IF invitation IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide an invitation id';
	END IF;

	SELECT * FROM invite_maintainer_for_project WHERE id = invitation INTO invitation_row;
	IF invitation_row.id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' does not exist';
	END IF;

	IF invitation_row.claimed_by IS NOT NULL OR invitation_row.claimed_at IS NOT NULL OR invitation_row.expires_at < CURRENT_TIMESTAMP THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' is expired';
	END IF;

-- Only use the invitation if not already a maintainer
	IF NOT EXISTS(SELECT 1 FROM maintainer_for_project WHERE maintainer = account AND project = invitation_row.project) THEN
		UPDATE invite_maintainer_for_project SET claimed_by = account, claimed_at = LOCALTIMESTAMP WHERE id = invitation;
		INSERT INTO maintainer_for_project VALUES (account, invitation_row.project);
	END IF;

	RETURN QUERY
		SELECT project.title, project.slug FROM project WHERE project.id = invitation_row.project;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.accept_invitation_software(invitation uuid)
 RETURNS TABLE(brand_name character varying, slug character varying)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE invitation_row invite_maintainer_for_software%ROWTYPE;
DECLARE account UUID;
BEGIN
	account = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
	IF account IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please login first';
	END IF;

	IF invitation IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide an invitation id';
	END IF;

	SELECT * FROM invite_maintainer_for_software WHERE id = invitation INTO invitation_row;
	IF invitation_row.id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' does not exist';
	END IF;

	IF invitation_row.claimed_by IS NOT NULL OR invitation_row.claimed_at IS NOT NULL OR invitation_row.expires_at < CURRENT_TIMESTAMP THEN
		RAISE EXCEPTION USING MESSAGE = 'Invitation with id ' || invitation || ' is expired';
	END IF;

-- Only use the invitation if not already a maintainer
	IF NOT EXISTS(SELECT 1 FROM maintainer_for_software WHERE maintainer = account AND software = invitation_row.software) THEN
		UPDATE invite_maintainer_for_software SET claimed_by = account, claimed_at = LOCALTIMESTAMP WHERE id = invitation;
		INSERT INTO maintainer_for_software VALUES (account, invitation_row.software);
	END IF;

	RETURN QUERY
		SELECT software.brand_name, software.slug FROM software WHERE software.id = invitation_row.software;
	RETURN;
END
$function$
;

create policy "admin_all_rights"
on "public"."community"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."community"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "maintainer_all_rights"
on "public"."community"
as permissive
for all
to rsd_user
using ((id IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))))
with check (true);


create policy "admin_all_rights"
on "public"."invite_maintainer_for_community"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "maintainer_delete"
on "public"."invite_maintainer_for_community"
as permissive
for delete
to rsd_user
using (((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


create policy "maintainer_insert"
on "public"."invite_maintainer_for_community"
as permissive
for insert
to rsd_user
with check ((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))) AND (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid));


create policy "maintainer_select"
on "public"."invite_maintainer_for_community"
as permissive
for select
to rsd_user
using (((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))) OR (created_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid) OR (claimed_by = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid)));


create policy "admin_all_rights"
on "public"."keyword_for_community"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."keyword_for_community"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "maintainer_delete"
on "public"."keyword_for_community"
as permissive
for delete
to rsd_user
using ((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))));


create policy "maintainer_insert"
on "public"."keyword_for_community"
as permissive
for insert
to rsd_user
with check (community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer)));


create policy "admin_all_rights"
on "public"."maintainer_for_community"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "maintainer_delete"
on "public"."maintainer_for_community"
as permissive
for delete
to rsd_user
using ((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))));


create policy "maintainer_insert"
on "public"."maintainer_for_community"
as permissive
for insert
to rsd_user
with check (community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer)));


create policy "maintainer_select"
on "public"."maintainer_for_community"
as permissive
for select
to rsd_user
using ((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))));


create policy "admin_all_rights"
on "public"."software_for_community"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."software_for_community"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "maintainer_can_read"
on "public"."software_for_community"
as permissive
for select
to rsd_user
using (((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))) OR (community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer)))));


create policy "maintainer_community_delete"
on "public"."software_for_community"
as permissive
for delete
to rsd_user
using ((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))));


create policy "maintainer_community_insert"
on "public"."software_for_community"
as permissive
for insert
to rsd_user
with check (community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer)));


create policy "maintainer_community_update"
on "public"."software_for_community"
as permissive
for update
to rsd_user
using ((community IN ( SELECT communities_of_current_maintainer.communities_of_current_maintainer
   FROM communities_of_current_maintainer() communities_of_current_maintainer(communities_of_current_maintainer))));


create policy "maintainer_software_delete"
on "public"."software_for_community"
as permissive
for delete
to rsd_user
using ((((status = 'pending'::request_status) OR (status = 'approved'::request_status)) AND (software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer)))));


create policy "maintainer_software_insert"
on "public"."software_for_community"
as permissive
for insert
to rsd_user
with check ((status = 'pending'::request_status) AND (software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))));


CREATE TRIGGER sanitise_insert_community BEFORE INSERT ON public.community FOR EACH ROW EXECUTE FUNCTION sanitise_insert_community();

CREATE TRIGGER sanitise_update_community BEFORE UPDATE ON public.community FOR EACH ROW EXECUTE FUNCTION sanitise_update_community();

CREATE TRIGGER sanitise_insert_invite_maintainer_for_community BEFORE INSERT ON public.invite_maintainer_for_community FOR EACH ROW EXECUTE FUNCTION sanitise_insert_invite_maintainer_for_community();

CREATE TRIGGER sanitise_update_invite_maintainer_for_community BEFORE UPDATE ON public.invite_maintainer_for_community FOR EACH ROW EXECUTE FUNCTION sanitise_update_invite_maintainer_for_community();

CREATE TRIGGER sanitise_update_software_for_community BEFORE UPDATE ON public.software_for_community FOR EACH ROW EXECUTE FUNCTION sanitise_update_software_for_community();

