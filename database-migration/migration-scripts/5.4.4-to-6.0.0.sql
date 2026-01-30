-- CONTAINS AN EXTRA STEP TO MIGRATE REPOSITORY URLS

-- Before you upgrade to 6.0.0, you have to remove duplicate repo URL entries (so delete all but one) and add them back after the migration.
-- To see which duplicates you have, run the following query:
-- SELECT ru.url, COUNT(ru.url), ARRAY_AGG(s.slug) FROM repository_url AS ru INNER JOIN software AS s ON s.id = ru.software GROUP BY url HAVING COUNT(url) > 1;
-- Remember to keep track of the software from which you delete the URLs in order to add them back later. Do this deleting and adding through the web UI.

---------- CREATED BY MIGRA ----------

drop policy "maintainer_all_rights" on "public"."repository_url";

drop policy "anyone_can_read" on "public"."repository_url";

alter table "public"."repository_url" drop constraint "repository_url_software_fkey";

drop function if exists "public"."global_search"(query character varying);

drop function if exists "public"."projects_by_maintainer"(maintainer_id uuid);

drop function if exists "public"."software_by_maintainer"(maintainer_id uuid);

alter table "public"."repository_url" drop constraint "repository_url_pkey";

drop index if exists "public"."repository_url_pkey";

create table "public"."repository_url_for_software" (
    "repository_url" uuid not null,
    "software" uuid not null,
    "position" integer
);


alter table "public"."repository_url" add column "id" uuid not null default gen_random_uuid();

-- ADDED MANUALLY

INSERT INTO repository_url_for_software(repository_url, software, position)
	(SELECT id, software, 1 FROM repository_url);

-- END ADDED MANUALLY

alter table "public"."repository_url" drop column "software";

CREATE UNIQUE INDEX repository_url_for_software_pkey ON public.repository_url_for_software USING btree (repository_url, software);

CREATE UNIQUE INDEX repository_url_url_key ON public.repository_url USING btree (url);

CREATE UNIQUE INDEX repository_url_pkey ON public.repository_url USING btree (id);

alter table "public"."repository_url_for_software" add constraint "repository_url_for_software_pkey" PRIMARY KEY using index "repository_url_for_software_pkey";

alter table "public"."repository_url" add constraint "repository_url_pkey" PRIMARY KEY using index "repository_url_pkey";

alter table "public"."repository_url" add constraint "repository_url_url_key" UNIQUE using index "repository_url_url_key";

alter table "public"."repository_url_for_software" add constraint "repository_url_for_software_repository_url_fkey" FOREIGN KEY (repository_url) REFERENCES repository_url(id);

alter table "public"."repository_url_for_software" add constraint "repository_url_for_software_software_fkey" FOREIGN KEY (software) REFERENCES software(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.repository_by_software(software_id uuid)
 RETURNS TABLE(id uuid, software uuid, url character varying, code_platform platform_type, "position" integer, archived boolean, license character varying, star_count bigint, fork_count integer, open_issue_count integer, basic_data_last_error character varying, basic_data_scraped_at timestamp with time zone, languages jsonb, languages_last_error character varying, languages_scraped_at timestamp with time zone, commit_history jsonb, commit_history_last_error character varying, commit_history_scraped_at timestamp with time zone, contributor_count integer, contributor_count_last_error character varying, contributor_count_scraped_at timestamp with time zone, scraping_disabled_reason character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	id,software,url,code_platform,"position",
	archived,license,star_count,fork_count,open_issue_count,
	basic_data_last_error,basic_data_scraped_at,
	languages,languages_last_error,languages_scraped_at,
	commit_history,commit_history_last_error,commit_history_scraped_at,
	contributor_count,contributor_count_last_error,contributor_count_scraped_at,
	scraping_disabled_reason
FROM
	repository_url_for_software
LEFT JOIN
	repository_url ON repository_url.id = repository_url_for_software.repository_url
WHERE
	repository_url_for_software.software = software_id
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_repository_url()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_repository_url()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = OLD.id;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.delete_software(id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
	IF id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide the ID of the software to delete';
	END IF;

	IF
		(SELECT rolsuper FROM pg_roles WHERE rolname = SESSION_USER) IS DISTINCT FROM TRUE
		AND
		(SELECT CURRENT_SETTING('request.jwt.claims', FALSE)::json->>'role') IS DISTINCT FROM 'rsd_admin'
	THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not allowed to delete this software';
	END IF;

	DELETE FROM category_for_software WHERE category_for_software.software_id = delete_software.id;
	DELETE FROM contributor WHERE contributor.software = delete_software.id;
	DELETE FROM invite_maintainer_for_software WHERE invite_maintainer_for_software.software = delete_software.id;
	DELETE FROM keyword_for_software WHERE keyword_for_software.software = delete_software.id;
	DELETE FROM license_for_software WHERE license_for_software.software = delete_software.id;
	DELETE FROM maintainer_for_software WHERE maintainer_for_software.software = delete_software.id;
	DELETE FROM mention_for_software WHERE mention_for_software.software = delete_software.id;
	DELETE FROM package_manager WHERE package_manager.software = delete_software.id;
	DELETE FROM reference_paper_for_software WHERE reference_paper_for_software.software = delete_software.id;
	DELETE FROM release_version WHERE release_version.release_id = delete_software.id;
	DELETE FROM release WHERE release.software = delete_software.id;
	DELETE FROM repository_url_for_software WHERE repository_url_for_software.software = delete_software.id;
	DELETE FROM software_for_community WHERE software_for_community.software = delete_software.id;
	DELETE FROM software_for_organisation WHERE software_for_organisation.software = delete_software.id;
	DELETE FROM software_for_project WHERE software_for_project.software = delete_software.id;
	DELETE FROM software_for_software WHERE software_for_software.origin = delete_software.id OR software_for_software.relation = delete_software.id;
	DELETE FROM software_highlight WHERE software_highlight.software = delete_software.id;
	DELETE FROM testimonial WHERE testimonial.software = delete_software.id;

	DELETE FROM software WHERE software.id = delete_software.id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.global_search(query character varying)
 RETURNS TABLE(slug character varying, domain character varying, rsd_host character varying, name character varying, short_description character varying, source text, is_published boolean, image_id character varying, rank integer, index_found integer)
 LANGUAGE sql
 STABLE
AS $function$
	-- AGGREGATED SOFTWARE search
	SELECT
		aggregated_software_search.slug,
		aggregated_software_search.domain,
		aggregated_software_search.rsd_host,
		aggregated_software_search.brand_name AS name,
		aggregated_software_search.short_statement as short_description,
		'software' AS "source",
		aggregated_software_search.is_published,
		aggregated_software_search.image_id,
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
		project_search.slug,
		NULL AS domain,
		NULL as rsd_host,
		project_search.title AS name,
		project_search.subtitle as short_description,
		'projects' AS "source",
		project_search.is_published,
		project_search.image_id,
		(CASE
			WHEN project_search.slug ILIKE query OR project_search.title ILIKE query THEN 0
			WHEN project_search.keywords_text ILIKE CONCAT('%', query, '%') THEN 1
			WHEN project_search.slug ILIKE CONCAT(query, '%') OR project_search.title ILIKE CONCAT(query, '%') THEN 2
			WHEN project_search.slug ILIKE CONCAT('%', query, '%') OR project_search.title ILIKE CONCAT('%', query, '%') THEN 3
			ELSE 4
		END) AS rank,
		(CASE
			WHEN project_search.slug ILIKE query OR project_search.title ILIKE query THEN 0
			WHEN project_search.keywords_text ILIKE CONCAT('%', query, '%') THEN 0
			WHEN project_search.slug ILIKE CONCAT(query, '%') OR project_search.title ILIKE CONCAT(query, '%') THEN 0
			WHEN project_search.slug ILIKE CONCAT('%', query, '%') OR project_search.title ILIKE CONCAT('%', query, '%')
				THEN LEAST(NULLIF(POSITION(LOWER(query) IN project_search.slug), 0), NULLIF(POSITION(LOWER(query) IN LOWER(project_search.title)), 0))
			ELSE 0
		END) AS index_found
	FROM
		project_search(query)
	UNION ALL
	-- ORGANISATION search
	SELECT
		organisation.slug,
		NULL AS domain,
		NULL as rsd_host,
		organisation."name",
		organisation.short_description,
		'organisations' AS "source",
		TRUE AS is_published,
		organisation.logo_id AS image_id,
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
		community.short_description,
		'communities' AS "source",
		TRUE AS is_published,
		community.logo_id AS image_id,
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
		community.slug ILIKE CONCAT('%', query, '%') OR community."name" ILIKE CONCAT('%', query, '%')
	UNION ALL
	-- NEWS search
	SELECT
		CONCAT(news.publication_date,'/',news.slug) AS slug,
		NULL AS domain,
		NULL as rsd_host,
		news.title as "name",
		news.summary as short_description,
		'news' AS "source",
		news.is_published,
		image_for_news.image_id,
		(CASE
			WHEN news.title ILIKE query OR news.summary ILIKE query THEN 0
			WHEN news.title ILIKE CONCAT(query, '%') OR news.summary ILIKE CONCAT(query, '%') THEN 1
			WHEN news.title ILIKE CONCAT('%', query, '%') OR news.summary ILIKE CONCAT('%', query, '%') THEN 2
				ELSE 3
			END) AS rank,
			0 as index_found
	FROM
		news
	LEFT JOIN LATERAL (
		SELECT
			image_id
		FROM
			image_for_news
		WHERE
			image_for_news.news = news.id AND
			image_for_news.image_id IS NOT NULL
		ORDER BY
			image_for_news.position
		LIMIT 1
	) image_for_news ON TRUE
	WHERE
		news.title ILIKE CONCAT('%', query, '%') OR news.summary ILIKE CONCAT('%', query, '%')
	UNION ALL
	-- PERSONS search
	SELECT
		CAST (public_persons_overview.account AS VARCHAR) as slug,
		NULL AS domain,
		NULL as rsd_host,
		public_persons_overview.display_name as "name",
		CONCAT (public_persons_overview.role, ', ', public_persons_overview.affiliation) as short_description,
		'persons' AS "source",
		public_persons_overview.is_public AS is_published,
		public_persons_overview.avatar_id AS image_id,
		(CASE
			WHEN public_persons_overview.display_name ILIKE query THEN 0
			WHEN public_persons_overview.display_name ILIKE CONCAT(query, '%') THEN 2
			ELSE 3
		END) AS rank,
		0 as index_found
	FROM
		public_persons_overview()
	WHERE
		public_persons_overview.display_name ILIKE CONCAT('%', query, '%');
$function$
;

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
		url,
		code_platform,
		scraping_disabled_reason
	) VALUES (
		nassa_import.repository_url,
		'github',
		'This is a NASSA module which is not a repository root'
	)
	ON CONFLICT DO NOTHING;

	INSERT INTO repository_url_for_software (repository_url, software) VALUES (
		(SELECT id FROM repository_url WHERE repository_url.url = nassa_import.repository_url),
		software_id
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

CREATE OR REPLACE FUNCTION public.prog_lang_filter_for_software()
 RETURNS TABLE(software uuid, prog_lang text[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		repository_url_for_software.software,
		ARRAY_AGG(DISTINCT p_lang)
	FROM
		repository_url_for_software,
		LATERAL (SELECT JSONB_OBJECT_KEYS(repository_url.languages) FROM repository_url WHERE repository_url.id = repository_url_for_software.repository_url) AS p_lang
	GROUP BY repository_url_for_software.software;
$function$
;

CREATE OR REPLACE FUNCTION public.projects_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], research_domain character varying[], impact_cnt integer, output_cnt integer, project_status character varying)
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		project_overview.id,
		project_overview.slug,
		project_overview.title,
		project_overview.subtitle,
		project_overview.date_start,
		project_overview.date_end,
		project_overview.updated_at,
		project_overview.is_published,
		project_overview.image_contain,
		project_overview.image_id,
		project_overview.keywords,
		project_overview.research_domain,
		project_overview.impact_cnt,
		project_overview.output_cnt,
		project_overview.project_status
	FROM
		project_overview()
	INNER JOIN
		maintainer_for_project ON project_overview.id = maintainer_for_project.project
	WHERE
		maintainer_for_project.maintainer = maintainer_id;
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, is_published boolean, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, keywords citext[], prog_lang text[], licenses character varying[])
 LANGUAGE sql
 STABLE
AS $function$
	SELECT
		software_overview.id,
		software_overview.slug,
		software_overview.brand_name,
		software_overview.short_statement,
		software_overview.image_id,
		software_overview.is_published,
		software_overview.updated_at,
		software_overview.contributor_cnt,
		software_overview.mention_cnt,
		software_overview.keywords,
		software_overview.prog_lang,
		software_overview.licenses
	FROM
		software_overview()
	INNER JOIN
		maintainer_for_software ON software_overview.id=maintainer_for_software.software
	WHERE
		maintainer_for_software.maintainer=maintainer_id;
$function$
;

create policy "maintainer_delete"
on "public"."repository_url"
as permissive
for delete
to rsd_user
using (true);


create policy "maintainer_insert"
on "public"."repository_url"
as permissive
for insert
to rsd_user
with check (true);


create policy "anyone_can_read"
on "public"."repository_url"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


CREATE TRIGGER sanitise_insert_repository_url BEFORE INSERT ON public.repository_url FOR EACH ROW EXECUTE FUNCTION sanitise_insert_repository_url();

CREATE TRIGGER sanitise_update_repository_url BEFORE UPDATE ON public.repository_url FOR EACH ROW EXECUTE FUNCTION sanitise_update_repository_url();

CREATE TRIGGER check_repository_url_for_software_before_delete BEFORE DELETE ON public.repository_url_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_repository_url_for_software_before_insert BEFORE INSERT ON public.repository_url_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_repository_url_for_software_before_update BEFORE UPDATE ON public.repository_url_for_software FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

