---------- CREATED BY MIGRA ----------

drop function if exists "public"."communities_overview"(public boolean);

create table "public"."locked_account" (
    "account_id" uuid not null,
    "admin_facing_reason" character varying(100),
    "user_facing_reason" character varying(100),
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."locked_account" enable row level security;

alter table "public"."account_invite" add column "comment" character varying(50);

alter table "public"."community" add column "website" character varying(200);

-- IMPORTANT: manually removed the NOT NULL requirement for "public"."software_for_community", since existing entries don't have a value

alter table "public"."software_for_community" add column "requested_at" timestamp with time zone;

CREATE UNIQUE INDEX community_website_key ON public.community USING btree (website);

CREATE UNIQUE INDEX locked_account_pkey ON public.locked_account USING btree (account_id);

alter table "public"."locked_account" add constraint "locked_account_pkey" PRIMARY KEY using index "locked_account_pkey";

alter table "public"."community" add constraint "community_website_key" UNIQUE using index "community_website_key";

alter table "public"."locked_account" add constraint "locked_account_account_id_fkey" FOREIGN KEY (account_id) REFERENCES account(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.notify_on_community_request()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	RAISE NOTICE 'About to send community request NOTIFY';
	PERFORM pg_notify('software_for_community_join_request', to_json(NEW)::text);
	RETURN NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.pre_request_hook()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE account_authenticated UUID;
BEGIN
	account_authenticated = UUID(CURRENT_SETTING('request.jwt.claims', TRUE)::json->>'account');
	IF account_authenticated IS NOT NULL AND (SELECT account_id FROM locked_account WHERE account_id = account_authenticated) IS NOT NULL THEN
		RAISE EXCEPTION SQLSTATE 'PT403' USING MESSAGE = 'Your account is locked.', DETAIL = COALESCE((SELECT user_facing_reason FROM locked_account WHERE account_id = account_authenticated), 'no reason given');
	END IF;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_locked_account()
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

CREATE OR REPLACE FUNCTION public.sanitise_insert_software_for_community()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.requested_at = LOCALTIMESTAMP;
	RETURN NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_locked_account()
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
	public.reference_paper_for_software
INNER JOIN
	public.citation_for_mention ON citation_for_mention.mention = reference_paper_for_software.mention
INNER JOIN
	public.mention ON mention.id = citation_for_mention.citation
--EXCLUDE reference papers items from citations
WHERE
	mention.id NOT IN (
		SELECT mention FROM public.reference_paper_for_software
	)
GROUP BY
	reference_paper_for_software.software,
	mention.id
;
$function$
;

CREATE OR REPLACE FUNCTION public.communities_overview(public boolean DEFAULT true)
 RETURNS TABLE(id uuid, slug character varying, name character varying, short_description character varying, logo_id character varying, primary_maintainer uuid, website character varying, software_cnt bigint, pending_cnt bigint, rejected_cnt bigint, keywords citext[], description character varying, created_at timestamp with time zone)
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
	community.website,
	COALESCE(software_count_by_community.software_cnt, 0),
	COALESCE(pending_count_by_community.pending_cnt, 0),
	COALESCE(rejected_count_by_community.rejected_cnt, 0),
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

CREATE OR REPLACE FUNCTION public.count_software_mentions()
 RETURNS TABLE(software uuid, mention_cnt bigint)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		mentions_by_software.software, COUNT(mentions_by_software.id) AS mention_cnt
	FROM
		public.mentions_by_software()
	GROUP BY
		mentions_by_software.software;
$function$
;

CREATE OR REPLACE FUNCTION public.maintainers_of_community(community_id uuid)
 RETURNS TABLE(maintainer uuid, name character varying[], email character varying[], affiliation character varying[], is_primary boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE account_authenticated BOOLEAN;
BEGIN
	account_authenticated = (
		CASE
			WHEN CURRENT_USER = 'rsd_admin' THEN TRUE
			ELSE (current_setting('request.jwt.claims', FALSE)::json->>'account') IS NOT NULL
		END
	);
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
	WITH maintainer_ids AS (
		-- primary maintainer of community
		SELECT
			community.primary_maintainer AS maintainer,
			TRUE AS is_primary
		FROM
			community
		WHERE
			community.id = community_id
		-- append second selection
		UNION ALL
		-- other maintainers of community
		SELECT
			maintainer_for_community.maintainer,
			FALSE AS is_primary
		FROM
			maintainer_for_community
		WHERE
			maintainer_for_community.community = community_id
		-- primary as first record
		ORDER BY is_primary DESC
	)
	SELECT
		maintainer_ids.maintainer AS maintainer,
		ARRAY_AGG(login_for_account."name") AS name,
		ARRAY_AGG(user_profile.email_address) AS email,
		ARRAY_AGG(login_for_account.home_organisation) AS affiliation,
		BOOL_OR(maintainer_ids.is_primary) AS is_primary
	FROM
		maintainer_ids
	INNER JOIN
		login_for_account ON login_for_account.account = maintainer_ids.maintainer
	INNER JOIN
		user_profile ON user_profile.account = maintainer_ids.maintainer
	GROUP BY
		maintainer_ids.maintainer
	-- primary as first record
	ORDER BY
		is_primary DESC;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.mentions_by_software()
 RETURNS TABLE(software uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying)
 LANGUAGE sql
 STABLE
AS $function$
WITH mentions_and_citations AS (
	-- mentions for software
	SELECT
		mention_for_software.software,
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
	FROM
		public.mention
	INNER JOIN
		public.mention_for_software ON mention_for_software.mention = mention.id
	-- does not deduplicate identical entries, but we will do so below with DISTINCT
	-- from scraped citations
	UNION ALL
	-- scraped citations from reference papers
	SELECT
		software,
		id,
		doi,
		url,
		title,
		authors,
		publisher,
		publication_year,
		journal,
		page,
		image_url,
		mention_type,
		source
	FROM
		public.citation_by_software()
)
SELECT DISTINCT ON (mentions_and_citations.software, mentions_and_citations.id) * FROM mentions_and_citations;
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_software_for_community()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.software = OLD.software;
	NEW.community = OLD.community;
	NEW.requested_at = OLD.requested_at;
	return NEW;
END
$function$
;

create policy "admin_all_rights"
on "public"."locked_account"
as permissive
for all
to rsd_admin
using (true)
with check (true);


CREATE TRIGGER check_locked_account_before_delete BEFORE DELETE ON public.locked_account FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_locked_account_before_insert BEFORE INSERT ON public.locked_account FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_locked_account_before_update BEFORE UPDATE ON public.locked_account FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_locked_account BEFORE INSERT ON public.locked_account FOR EACH ROW EXECUTE FUNCTION sanitise_insert_locked_account();

CREATE TRIGGER sanitise_update_locked_account BEFORE UPDATE ON public.locked_account FOR EACH ROW EXECUTE FUNCTION sanitise_update_locked_account();

CREATE TRIGGER notify_community_request AFTER INSERT OR UPDATE ON public.software_for_community FOR EACH ROW WHEN ((new.status = 'pending'::request_status)) EXECUTE FUNCTION notify_on_community_request();

CREATE TRIGGER sanitise_insert_software_for_community BEFORE INSERT ON public.software_for_community FOR EACH ROW EXECUTE FUNCTION sanitise_insert_software_for_community();

