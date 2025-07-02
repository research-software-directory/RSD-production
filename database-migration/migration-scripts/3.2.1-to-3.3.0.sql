---------- CREATED BY MIGRA ----------

-- THESE STATEMENTs WERE MOVED TO THE TOP TO ALLOW MIGRATION STATEMENT BELOW
create table "public"."user_profile" (
    "account" uuid not null,
    "given_names" character varying(200) not null,
    "family_names" character varying(200) not null,
    "email_address" character varying(200),
    "role" character varying(200),
    "affiliation" character varying(200),
    "is_public" boolean not null default false,
    "avatar_id" character varying(40),
    "description" character varying(10000),
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);

CREATE OR REPLACE FUNCTION public.sanitise_insert_user_profile()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	-- use account uuid from token ?
	-- NEW.account = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account');
	NEW.created_at = LOCALTIMESTAMP;
	NEW.updated_at = NEW.created_at;
	return NEW;
END
$function$
;

CREATE TRIGGER sanitise_insert_user_profile BEFORE INSERT ON public.user_profile FOR EACH ROW EXECUTE FUNCTION sanitise_insert_user_profile();

-- ADDED MANUALLY
-- migration statement for public profiles
-- this might go wrong if someone has multiple ORCIDs attached to their account
-- this migrates existing names and splits them on the first space
WITH existing_public_profiles AS (
	SELECT account.id, account.public_orcid_profile, COALESCE((STRING_TO_ARRAY(login_for_account.name, ' '))[1], '') AS given_names, COALESCE(ARRAY_TO_STRING((STRING_TO_ARRAY(login_for_account.name, ' '))[2:], ' '), '') AS family_names
	FROM account
	LEFT JOIN login_for_account ON login_for_account.account = account.id AND provider = 'orcid'
	WHERE public_orcid_profile
)
INSERT INTO user_profile (account, is_public, given_names, family_names) SELECT id, public_orcid_profile, given_names, family_names FROM existing_public_profiles ON CONFLICT DO NOTHING;
-- END ADDED MANUALLY

drop trigger if exists "check_orcid_whitelist_before_delete" on "public"."orcid_whitelist";

drop trigger if exists "check_orcid_whitelist_before_insert" on "public"."orcid_whitelist";

drop trigger if exists "check_orcid_whitelist_before_update" on "public"."orcid_whitelist";

drop policy "admin_all_rights" on "public"."orcid_whitelist";

alter table "public"."orcid_whitelist" drop constraint "orcid_whitelist_orcid_check";

drop function if exists "public"."project_by_public_profile"();

drop function if exists "public"."project_team"(project_id uuid);

drop function if exists "public"."projects_by_maintainer"(maintainer_id uuid);

drop function if exists "public"."software_by_public_profile"();

drop function if exists "public"."software_contributors"(software_id uuid);

drop function if exists "public"."unique_person_entries"();

alter table "public"."orcid_whitelist" drop constraint "orcid_whitelist_pkey";

drop index if exists "public"."orcid_whitelist_pkey";

drop table "public"."orcid_whitelist";

alter table "public"."package_manager" alter column "package_manager" drop default;

alter table "public"."repository_url" alter column "code_platform" drop default;

alter type "public"."package_manager_type" rename to "package_manager_type__old_version_to_be_dropped";

create type "public"."package_manager_type" as enum ('anaconda', 'chocolatey', 'cran', 'crates', 'debian', 'dockerhub', 'fourtu', 'ghcr', 'github', 'gitlab', 'golang', 'maven', 'npm', 'pixi', 'pypi', 'snapcraft', 'sonatype', 'other');

alter type "public"."platform_type" rename to "platform_type__old_version_to_be_dropped";

create type "public"."platform_type" as enum ('github', 'gitlab', 'bitbucket', '4tu', 'other');

create table "public"."account_invite" (
    "id" uuid not null,
    "uses_left" integer,
    "expires_at" timestamp with time zone not null,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."account_invite" enable row level security;


alter table "public"."user_profile" enable row level security;

alter table "public"."package_manager" alter column package_manager type "public"."package_manager_type" using package_manager::text::"public"."package_manager_type";

alter table "public"."repository_url" alter column code_platform type "public"."platform_type" using code_platform::text::"public"."platform_type";

alter table "public"."package_manager" alter column "package_manager" set default 'other'::package_manager_type;

alter table "public"."repository_url" alter column "code_platform" set default 'other'::platform_type;

drop type "public"."package_manager_type__old_version_to_be_dropped";

-- ADDED MANUALLY
DROP FUNCTION suggest_platform;

CREATE FUNCTION suggest_platform(hostname VARCHAR(200)) RETURNS platform_type
LANGUAGE SQL STABLE AS
$$
SELECT
	code_platform
FROM
	(
		SELECT
			url,
			code_platform
		FROM
			repository_url
	) AS sub
WHERE
	(
		-- Returns the hostname of sub.url
		SELECT
			TOKEN
		FROM
			ts_debug(sub.url)
		WHERE
			alias = 'host'
	) = hostname
GROUP BY
	sub.code_platform
ORDER BY
	COUNT(*)
DESC LIMIT
	1;
;
$$;
-- END ADDED MANUALLY

drop type "public"."platform_type__old_version_to_be_dropped";

alter table "public"."account" drop column "public_orcid_profile";

alter table "public"."contributor" add column "account" uuid;

alter table "public"."software" alter column "brand_name" set data type character varying(250) using "brand_name"::character varying(250);

alter table "public"."software" alter column "slug" set data type character varying(250) using "slug"::character varying(250);

alter table "public"."team_member" add column "account" uuid;

CREATE UNIQUE INDEX account_invite_pkey ON public.account_invite USING btree (id);

CREATE INDEX contributor_account_idx ON public.contributor USING btree (account);

CREATE INDEX login_for_account_account_idx ON public.login_for_account USING btree (account);

CREATE UNIQUE INDEX package_manager_software_url_package_manager_key ON public.package_manager USING btree (software, url, package_manager);

CREATE INDEX team_member_account_idx ON public.team_member USING btree (account);

CREATE UNIQUE INDEX user_profile_pkey ON public.user_profile USING btree (account);

alter table "public"."account_invite" add constraint "account_invite_pkey" PRIMARY KEY using index "account_invite_pkey";

alter table "public"."user_profile" add constraint "user_profile_pkey" PRIMARY KEY using index "user_profile_pkey";

alter table "public"."contributor" add constraint "contributor_account_fkey" FOREIGN KEY (account) REFERENCES account(id);

alter table "public"."package_manager" add constraint "package_manager_software_url_package_manager_key" UNIQUE using index "package_manager_software_url_package_manager_key";

alter table "public"."team_member" add constraint "team_member_account_fkey" FOREIGN KEY (account) REFERENCES account(id);

alter table "public"."user_profile" add constraint "user_profile_account_fkey" FOREIGN KEY (account) REFERENCES account(id);

alter table "public"."user_profile" add constraint "user_profile_affiliation_check" CHECK (((affiliation)::text ~ '^\S+( \S+)*$'::text));

alter table "public"."user_profile" add constraint "user_profile_avatar_id_fkey" FOREIGN KEY (avatar_id) REFERENCES image(id);

alter table "public"."user_profile" add constraint "user_profile_role_check" CHECK (((role)::text ~ '^\S+( \S+)*$'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.nassa_import(slug character varying, brand_name character varying, description character varying, short_statement character varying, get_started_url character varying, repository_url character varying, license_value character varying, license_name character varying, license_url character varying, license_open_source boolean, related_modules character varying[], family_names_array character varying[], given_names_array character varying[], role_array character varying[], orcid_array character varying[], position_array integer[], categories jsonb, regular_mentions jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE software_id UUID;
DECLARE related_software_slug VARCHAR;
DECLARE related_software_id UUID;
DECLARE nassa_id UUID;
DECLARE category_value TEXT;
DECLARE category_id UUID;
DECLARE top_level_category_value TEXT;
DECLARE top_level_category_id UUID;
DECLARE mention_entry JSONB;
DECLARE mention_id UUID;

BEGIN
	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to import NASSA software';
	END IF;

	SELECT id FROM community WHERE community.slug = 'nassa' INTO nassa_id;
	IF nassa_id IS NULL
	THEN
		RAISE EXCEPTION USING MESSAGE = 'The NASSA community does not exist yet';
	END IF;

	IF
		ARRAY_LENGTH(family_names_array, 1) IS DISTINCT FROM ARRAY_LENGTH(given_names_array, 1)
		OR
		ARRAY_LENGTH(given_names_array, 1) IS DISTINCT FROM ARRAY_LENGTH(role_array, 1)
		OR
		ARRAY_LENGTH(role_array, 1) IS DISTINCT FROM ARRAY_LENGTH(orcid_array, 1)
		OR
		ARRAY_LENGTH(orcid_array, 1) IS DISTINCT FROM ARRAY_LENGTH(position_array, 1)
	THEN
		RAISE EXCEPTION USING MESSAGE = 'The contributor arrays should have the same length';
	END IF;

	INSERT INTO software (
		slug,
		is_published,
		brand_name,
		description,
		short_statement,
		get_started_url
	) VALUES (
		nassa_import.slug,
		TRUE,
		nassa_import.brand_name,
		nassa_import.description,
		nassa_import.short_statement,
		nassa_import.get_started_url
	)
	ON CONFLICT ((software.slug)) DO UPDATE SET
		brand_name = EXCLUDED.brand_name,
		description = EXCLUDED.description,
		short_statement = EXCLUDED.short_statement,
		get_started_url = EXCLUDED.get_started_url
	RETURNING software.id INTO software_id;

	INSERT INTO software_for_community (software, community, status) VALUES (software_id, nassa_id, 'approved') ON CONFLICT DO NOTHING;

	INSERT INTO repository_url (
		software,
		url,
		code_platform,
		scraping_disabled_reason
	) VALUES (
		software_id,
		nassa_import.repository_url,
		'github',
		'This is a NASSA module which is not a repository root'
	)
	ON CONFLICT DO NOTHING;

	DELETE FROM license_for_software WHERE license_for_software.software = software_id;
	IF license_value IS NOT NULL
	THEN
		INSERT INTO license_for_software (
			software,
			license,
			name,
			reference,
			open_source
		) VALUES (
			software_id,
			license_value,
			license_name,
			license_url,
			license_open_source
		);
	END IF;

	IF related_modules IS NOT NULL
	THEN
		FOREACH related_software_slug IN ARRAY related_modules LOOP
			SELECT software.id FROM software WHERE software.slug = related_software_slug INTO related_software_id;
			IF related_software_id IS NOT NULL
			THEN
				INSERT INTO software_for_software (origin, relation) VALUES (software_id, related_software_id) ON CONFLICT DO NOTHING;
			END IF;
		END LOOP;
	END IF;

	-- contributors
	FOR i IN 1..ARRAY_LENGTH(family_names_array, 1) LOOP
		IF
			orcid_array[i] IS NOT NULL
			AND
			(SELECT COUNT(*) FROM contributor WHERE contributor.software = software_id AND contributor.orcid = orcid_array[i]) = 1
		THEN
			UPDATE contributor SET
				family_names = family_names_array[i],
				given_names = given_names_array[i],
				role = role_array[i],
				position = position_array[i]
			WHERE
				contributor.software = software_id AND contributor.orcid = orcid_array[i];
		ELSEIF (SELECT COUNT(*) FROM contributor WHERE contributor.software = software_id AND contributor.family_names = family_names_array[i] AND contributor.given_names = given_names_array[i]) = 1
		THEN
			UPDATE contributor SET
				role = role_array[i],
				orcid = orcid_array[i],
				position = position_array[i]
			WHERE
				contributor.software = software_id AND contributor.family_names = family_names_array[i] AND contributor.given_names = given_names_array[i];
		ELSE
			INSERT INTO contributor (
				software,
				family_names,
				given_names,
				role,
				orcid,
				position
			) VALUES (
				software_id,
				family_names_array[i],
				given_names_array[i],
				role_array[i],
				orcid_array[i],
				position_array[i]
			);
		END IF;

	END LOOP;
	-- end contributors

	-- categories
	FOR top_level_category_value IN (SELECT JSONB_OBJECT_KEYS(categories)) LOOP
		SELECT id FROM category WHERE community = nassa_id AND name = top_level_category_value INTO top_level_category_id;
		IF top_level_category_id IS NULL
		THEN
			INSERT INTO category (
				community,
				short_name,
				name
			)
			VALUES (
				nassa_id,
				top_level_category_value,
				top_level_category_value
			)
			RETURNING id INTO top_level_category_id;
		END IF;

		FOR category_value IN (SELECT JSONB_ARRAY_ELEMENTS_TEXT(categories -> top_level_category_value)) LOOP
			SELECT id FROM category WHERE community = nassa_id AND name = category_value INTO category_id;
			IF category_id IS NULL
			THEN
				INSERT INTO category (
					community,
					parent,
					short_name,
					name
				)
				VALUES (
					nassa_id,
					top_level_category_id,
					category_value,
					category_value
				)
				RETURNING id INTO category_id;
			END IF;

			INSERT INTO category_for_software (software_id, category_id) VALUES (software_id, category_id) ON CONFLICT DO NOTHING;
		END LOOP;
	END LOOP;
	-- end categories

	-- regular mentions
	FOR mention_entry IN (SELECT JSONB_ARRAY_ELEMENTS(regular_mentions)) LOOP
		SELECT id FROM mention WHERE mention.doi = mention_entry ->> 'doi' INTO mention_id;

		IF mention_id IS NULL
		THEN
			SELECT id FROM mention WHERE mention.title = mention_entry ->> 'title' AND mention.authors IS NOT DISTINCT FROM mention_entry ->> 'authors' INTO mention_id;
		END IF;

		IF mention_id IS NOT NULL
		THEN
			INSERT INTO mention_for_software (mention, software) VALUES (mention_id, software_id) ON CONFLICT DO NOTHING;
		ELSE
			INSERT INTO mention (SELECT * FROM JSONB_POPULATE_RECORD(NULL::mention, mention_entry)) RETURNING id INTO mention_id;
			INSERT INTO mention_for_software (mention, software) VALUES (mention_id, software_id) ON CONFLICT DO NOTHING;
		END IF;
	END LOOP;
	-- end regular mentions
END
$function$
;

CREATE OR REPLACE FUNCTION public.public_user_profile()
 RETURNS TABLE(display_name character varying, given_names character varying, family_names character varying, email_address character varying, affiliation character varying, role character varying, avatar_id character varying, orcid character varying, account uuid, is_public boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
SELECT
	(CONCAT(user_profile.given_names,' ',user_profile.family_names)) AS display_name,
	user_profile.given_names,
	user_profile.family_names,
	user_profile.email_address,
	user_profile.affiliation,
	user_profile.role,
	user_profile.avatar_id,
	login_for_account.sub AS orcid,
	user_profile.account,
	user_profile.is_public
FROM
	user_profile
LEFT JOIN
	login_for_account ON
		user_profile.account = login_for_account.account
		AND
		login_for_account.provider = 'orcid'
WHERE
	user_profile.is_public
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_account_invite()
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

CREATE OR REPLACE FUNCTION public.sanitise_update_account_invite()
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

CREATE OR REPLACE FUNCTION public.sanitise_update_user_profile()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.account = OLD.account;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.delete_account(account_id uuid)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE account_authenticated UUID;
BEGIN
	IF
		account_id IS NULL
	THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide an account id';
	END IF;
	account_authenticated = uuid(current_setting('request.jwt.claims', TRUE)::json->>'account');
	IF
			CURRENT_USER IS DISTINCT FROM 'rsd_admin'
		AND
			(SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER) IS DISTINCT FROM TRUE
		AND
			(
				account_authenticated IS NULL OR account_authenticated IS DISTINCT FROM account_id
			)
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this account';
	END IF;
	DELETE FROM maintainer_for_software WHERE maintainer = account_id;
	DELETE FROM maintainer_for_project WHERE maintainer = account_id;
	DELETE FROM maintainer_for_organisation WHERE maintainer = account_id;
	DELETE FROM maintainer_for_community WHERE maintainer = account_id;
	DELETE FROM invite_maintainer_for_software WHERE created_by = account_id OR claimed_by = account_id;
	DELETE FROM invite_maintainer_for_project WHERE created_by = account_id OR claimed_by = account_id;
	DELETE FROM invite_maintainer_for_organisation WHERE created_by = account_id OR claimed_by = account_id;
	DELETE FROM invite_maintainer_for_community WHERE created_by = account_id OR claimed_by = account_id;
	UPDATE organisation SET primary_maintainer = NULL WHERE primary_maintainer = account_id;
	UPDATE community SET primary_maintainer = NULL WHERE primary_maintainer = account_id;
	UPDATE contributor SET account = NULL WHERE account = account_id;
	UPDATE team_member SET account = NULL WHERE account = account_id;
	DELETE FROM admin_account WHERE admin_account.account_id = delete_account.account_id;
	DELETE FROM login_for_account WHERE account = account_id;
	DELETE FROM user_profile WHERE account = account_id;
	DELETE FROM account WHERE id = account_id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.delete_community(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the community to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this community';
	END IF;

	DELETE FROM category_for_software WHERE category_id IN (SELECT category.id FROM category WHERE category.community = delete_community.id);
	DELETE FROM category WHERE category.community = delete_community.id;
	DELETE FROM invite_maintainer_for_community WHERE invite_maintainer_for_community.community = delete_community.id;
	DELETE FROM keyword_for_community WHERE keyword_for_community.community = delete_community.id;
	DELETE FROM maintainer_for_community WHERE maintainer_for_community.community = delete_community.id;
	DELETE FROM software_for_community WHERE software_for_community.community = delete_community.id;

	DELETE FROM community WHERE community.id = delete_community.id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.project_by_public_profile()
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], keywords_text text, research_domain character varying[], participating_organisations character varying[], impact_cnt integer, output_cnt integer, project_status character varying, orcid character varying, account uuid)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
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
	keyword_filter_for_project.keywords,
	keyword_filter_for_project.keywords_text,
	research_domain_filter_for_project.research_domain,
	project_participating_organisations.organisations AS participating_organisations,
	COALESCE(count_project_impact.impact_cnt, 0) AS impact_cnt,
	COALESCE(count_project_output.output_cnt, 0) AS output_cnt,
	project_status.status,
	public_user_profile.orcid,
	public_user_profile.account
FROM
	public_user_profile()
INNER JOIN
	team_member ON (
		public_user_profile.orcid = team_member.orcid
		OR
		public_user_profile.account = team_member.account
	)
LEFT JOIN
	project ON project.id=team_member.project
LEFT JOIN
	keyword_filter_for_project() ON project.id=keyword_filter_for_project.project
LEFT JOIN
	research_domain_filter_for_project() ON project.id=research_domain_filter_for_project.project
LEFT JOIN
	project_participating_organisations() ON project.id=project_participating_organisations.project
LEFT JOIN
	count_project_impact() ON project.id=count_project_impact.project
LEFT JOIN
	count_project_output() ON project.id=count_project_output.project
LEFT JOIN
	project_status() ON project.id=project_status.project
;
$function$
;

CREATE OR REPLACE FUNCTION public.project_team(project_id uuid)
 RETURNS TABLE(id uuid, is_contact_person boolean, email_address character varying, family_names character varying, given_names character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, "position" integer, project uuid, account uuid, is_public character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (team_member.id)
	team_member.id,
	team_member.is_contact_person,
	team_member.email_address,
	team_member.family_names,
	team_member.given_names,
	team_member.affiliation,
	team_member.role,
	team_member.orcid,
	team_member.avatar_id,
	team_member."position",
	team_member.project,
	public_user_profile.account,
	public_user_profile.is_public
FROM
	team_member
LEFT JOIN
	public_user_profile() ON (
		team_member.orcid = public_user_profile.orcid
		OR
		team_member.account = public_user_profile.account
	)
WHERE
	team_member.project = project_id
;
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, current_state character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, impact_cnt integer, output_cnt integer)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		project.id,
		project.slug,
		project.title,
		project.subtitle,
		project_status.status AS current_state,
		project.date_start,
		project.date_end,
		project.updated_at,
		project.is_published,
		project.image_contain,
		project.image_id,
		COALESCE(count_project_impact.impact_cnt, 0),
		COALESCE(count_project_output.output_cnt, 0)
	FROM
		project
	INNER JOIN
		maintainer_for_project ON project.id = maintainer_for_project.project
	LEFT JOIN
		count_project_impact() ON count_project_impact.project = project.id
	LEFT JOIN
		count_project_output() ON count_project_output.project = project.id
	LEFT JOIN
		project_status() ON project.id=project_status.project
	WHERE
		maintainer_for_project.maintainer = maintainer_id;
$function$
;

CREATE OR REPLACE FUNCTION public.public_profile()
 RETURNS TABLE(orcid character varying)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
SELECT
	login_for_account.sub as orcid
FROM
	login_for_account
INNER JOIN
	user_profile ON login_for_account.account = user_profile.account
WHERE
	login_for_account.provider='orcid' AND user_profile.is_public
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_contributor()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	IF OLD.account IS NOT NULL AND (CURRENT_USER = 'rsd_admin' OR (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER)) IS DISTINCT FROM TRUE THEN
		NEW.family_names = OLD.family_names;
		NEW.given_names = OLD.given_names;
		NEW.orcid = OLD.orcid;
	END IF;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_team_member()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	NEW.created_at = OLD.created_at;
	NEW.updated_at = LOCALTIMESTAMP;
	IF OLD.account IS NOT NULL AND (CURRENT_USER = 'rsd_admin' OR (SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER)) IS DISTINCT FROM TRUE THEN
		NEW.family_names = OLD.family_names;
		NEW.given_names = OLD.given_names;
		NEW.orcid = OLD.orcid;
	END IF;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_public_profile()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], orcid character varying, account uuid)
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
	public_user_profile.orcid,
	public_user_profile.account
FROM
	public_user_profile()
INNER JOIN
	contributor ON (
		public_user_profile.orcid = contributor.orcid
		OR public_user_profile.account = contributor.account
	)
LEFT JOIN
	software ON software.id = contributor.software
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
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_contributors(software_id uuid)
 RETURNS TABLE(id uuid, is_contact_person boolean, email_address character varying, family_names character varying, given_names character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, "position" integer, software uuid, account uuid, is_public character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (contributor.id)
	contributor.id,
	contributor.is_contact_person,
	contributor.email_address,
	contributor.family_names,
	contributor.given_names,
	contributor.affiliation,
	contributor.role,
	contributor.orcid,
	contributor.avatar_id,
	contributor."position",
	contributor.software,
	public_user_profile.account,
	public_user_profile.is_public
FROM
	contributor
LEFT JOIN
	public_user_profile() ON (
		contributor.orcid = public_user_profile.orcid
		OR
		contributor.account = public_user_profile.account
	)
WHERE
	contributor.software = software_id
;
$function$
;

CREATE OR REPLACE FUNCTION public.unique_person_entries()
 RETURNS TABLE(display_name text, given_names character varying, family_names character varying, email_address character varying, affiliation character varying, role character varying, avatar_id character varying, orcid character varying, account uuid)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT
	(CONCAT(contributor.given_names,' ',contributor.family_names)) AS display_name,
	contributor.given_names,
	contributor.family_names,
	contributor.email_address,
	contributor.affiliation,
	contributor.role,
	contributor.avatar_id,
	contributor.orcid,
	contributor.account
FROM
	contributor
UNION
SELECT DISTINCT
	(CONCAT(team_member.given_names,' ',team_member.family_names)) AS display_name,
	team_member.given_names,
	team_member.family_names,
	team_member.email_address,
	team_member.affiliation,
	team_member.role,
	team_member.avatar_id,
	team_member.orcid,
	team_member.account
FROM
	team_member
ORDER BY
	display_name ASC;
$function$
;

create policy "admin_all_rights"
on "public"."account_invite"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "admin_all_rights"
on "public"."user_profile"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "maintainer_delete_rights"
on "public"."user_profile"
as permissive
for delete
to rsd_user
using ((account = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid));


create policy "maintainer_insert_rights"
on "public"."user_profile"
as permissive
for insert
to rsd_user
with check (account = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid);


create policy "maintainer_update_rights"
on "public"."user_profile"
as permissive
for update
to rsd_user
using ((account = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid))
with check (account = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid);


create policy "my_user_profile"
on "public"."user_profile"
as permissive
for select
to rsd_user
using ((account = (((current_setting('request.jwt.claims'::text, false))::json ->> 'account'::text))::uuid));


create policy "public_user_profile"
on "public"."user_profile"
as permissive
for select
to rsd_web_anon
using (is_public);


CREATE TRIGGER check_account_invite_before_delete BEFORE DELETE ON public.account_invite FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_account_invite_before_insert BEFORE INSERT ON public.account_invite FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_account_invite_before_update BEFORE UPDATE ON public.account_invite FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_account_invite BEFORE INSERT ON public.account_invite FOR EACH ROW EXECUTE FUNCTION sanitise_insert_account_invite();

CREATE TRIGGER sanitise_update_account_invite BEFORE UPDATE ON public.account_invite FOR EACH ROW EXECUTE FUNCTION sanitise_update_login_for_account();

CREATE TRIGGER sanitise_update_login_for_account BEFORE UPDATE ON public.user_profile FOR EACH ROW EXECUTE FUNCTION sanitise_update_user_profile();

