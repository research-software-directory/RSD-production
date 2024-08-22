---------- CREATED BY MIGRA ----------

drop policy "anyone_can_read" on "public"."software_for_community";

alter table "public"."package_manager" add column "download_count_scraping_disabled_reason" character varying(200);

alter table "public"."package_manager" add column "reverse_dependency_count_scraping_disabled_reason" character varying(200);

CREATE INDEX category_for_software_category_id_idx ON public.category_for_software USING btree (category_id);

CREATE INDEX citation_for_mention_citation_idx ON public.citation_for_mention USING btree (citation);

CREATE INDEX impact_for_project_project_idx ON public.impact_for_project USING btree (project);

CREATE INDEX keyword_for_community_keyword_idx ON public.keyword_for_community USING btree (keyword);

CREATE INDEX keyword_for_project_keyword_idx ON public.keyword_for_project USING btree (keyword);

CREATE INDEX keyword_for_software_keyword_idx ON public.keyword_for_software USING btree (keyword);

CREATE INDEX mention_for_software_software_idx ON public.mention_for_software USING btree (software);

CREATE INDEX organisation_parent_idx ON public.organisation USING btree (parent);

CREATE INDEX output_for_project_project_idx ON public.output_for_project USING btree (project);

CREATE INDEX project_for_organisation_organisation_idx ON public.project_for_organisation USING btree (organisation);

CREATE INDEX reference_paper_for_software_software_idx ON public.reference_paper_for_software USING btree (software);

CREATE INDEX release_version_mention_id_idx ON public.release_version USING btree (mention_id);

CREATE INDEX research_domain_for_project_research_domain_idx ON public.research_domain_for_project USING btree (research_domain);

CREATE INDEX software_for_organisation_organisation_idx ON public.software_for_organisation USING btree (organisation);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.citation_by_project()
 RETURNS TABLE(project uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying, reference_papers uuid[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	output_for_project.project,
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
		output_for_project.mention
	) AS reference_paper
FROM
	output_for_project
INNER JOIN
	citation_for_mention ON citation_for_mention.mention = output_for_project.mention
INNER JOIN
	mention ON mention.id = citation_for_mention.citation
--EXCLUDE reference papers items from citations
WHERE
	mention.id NOT IN (
		SELECT mention FROM output_for_project
	)
GROUP BY
	output_for_project.project,
	mention.id
;
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
--EXCLUDE reference papers items from citations
WHERE
	mention.id NOT IN (
		SELECT mention FROM reference_paper_for_software
	)
GROUP BY
	reference_paper_for_software.software,
	mention.id
;
$function$
;

CREATE OR REPLACE FUNCTION public.communities_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, name character varying, short_description character varying, logo_id character varying, primary_maintainer uuid, software_cnt bigint, pending_cnt bigint, rejected_cnt bigint, keywords citext[], description character varying, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (community.id)
	community.id,
	community.slug,
	community."name",
	community.short_description,
	community.logo_id,
	community.primary_maintainer,
	COALESCE(software_count_by_community.software_cnt, 0),
	COALESCE(pending_count_by_community.pending_cnt, 0),
	COALESCE(rejected_count_by_community.rejected_cnt, 0),
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
LEFT JOIN
	maintainer_for_community ON maintainer_for_community.community = community.id
WHERE
	maintainer_for_community.maintainer = maintainer_id OR community.primary_maintainer = maintainer_id;
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

CREATE OR REPLACE FUNCTION public.global_search(query character varying)
 RETURNS TABLE(slug character varying, name character varying, source text, is_published boolean, rank integer, index_found integer)
 LANGUAGE sql
 STABLE
AS $function$
	-- SOFTWARE search item
	SELECT
		software.slug,
		software.brand_name AS name,
		'software' AS "source",
		software.is_published,
		(CASE
			WHEN software.slug ILIKE query OR software.brand_name ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 1
			WHEN software.slug ILIKE CONCAT(query, '%') OR software.brand_name ILIKE CONCAT(query, '%') THEN 2
			WHEN software.slug ILIKE CONCAT('%', query, '%') OR software.brand_name ILIKE CONCAT('%', query, '%') THEN 3
			ELSE 4
		END) AS rank,
		(CASE
			WHEN software.slug ILIKE query OR software.brand_name ILIKE query THEN 0
			WHEN BOOL_OR(keyword.value ILIKE query) THEN 0
			WHEN software.slug ILIKE CONCAT(query, '%') OR software.brand_name ILIKE CONCAT(query, '%') THEN 0
			WHEN software.slug ILIKE CONCAT('%', query, '%') OR software.brand_name ILIKE CONCAT('%', query, '%')
				THEN LEAST(NULLIF(POSITION(query IN software.slug), 0), NULLIF(POSITION(query IN software.brand_name), 0))
			ELSE 0
		END) AS index_found
	FROM
		software
	LEFT JOIN keyword_for_software ON keyword_for_software.software = software.id
	LEFT JOIN keyword ON keyword.id = keyword_for_software.keyword
	GROUP BY software.id
	HAVING
		software.slug ILIKE CONCAT('%', query, '%')
		OR
		software.brand_name ILIKE CONCAT('%', query, '%')
		OR
		software.short_statement ILIKE CONCAT('%', query, '%')
		OR
		BOOL_OR(keyword.value ILIKE CONCAT('%', query, '%'))
	UNION ALL
	-- PROJECT search item
	SELECT
		project.slug,
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
				THEN LEAST(NULLIF(POSITION(query IN project.slug), 0), NULLIF(POSITION(query IN project.title), 0))
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
	-- ORGANISATION search item
	SELECT
		organisation.slug,
		organisation."name",
		'organisations' AS "source",
		TRUE AS is_published,
		(CASE
			WHEN organisation.slug ILIKE query OR organisation."name" ILIKE query THEN 0
			WHEN organisation.slug ILIKE CONCAT(query, '%') OR organisation."name" ILIKE CONCAT(query, '%') THEN 2
			ELSE 3
		END) AS rank,
		(CASE
			WHEN organisation.slug ILIKE query OR organisation."name" ILIKE query THEN 0
			WHEN organisation.slug ILIKE CONCAT(query, '%') OR organisation."name" ILIKE CONCAT(query, '%') THEN 0
			ELSE
				LEAST(NULLIF(POSITION(query IN organisation.slug), 0), NULLIF(POSITION(query IN organisation."name"), 0))
		END) AS index_found
	FROM
		organisation
	WHERE
	-- ONLY TOP LEVEL ORGANISATIONS
		organisation.parent IS NULL
		AND
		(organisation.slug ILIKE CONCAT('%', query, '%') OR organisation."name" ILIKE CONCAT('%', query, '%'))
	UNION ALL
	-- COMMUNITY search item
	SELECT
		community.slug,
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
				LEAST(NULLIF(POSITION(query IN community.slug), 0), NULLIF(POSITION(query IN community."name"), 0))
		END) AS index_found
	FROM
		community
	WHERE
		community.slug ILIKE CONCAT('%', query, '%') OR community."name" ILIKE CONCAT('%', query, '%');
$function$
;

CREATE OR REPLACE FUNCTION public.highlight_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, is_published boolean, contributor_cnt bigint, mention_cnt bigint, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], "position" integer)
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
	software_highlight.position
FROM
	software_search(search)
INNER JOIN
	software_highlight ON software_search.id=software_highlight.software
;
$function$
;

CREATE OR REPLACE FUNCTION public.impact_by_project()
 RETURNS TABLE(project uuid, id uuid, doi citext, url character varying, title character varying, authors character varying, publisher character varying, publication_year smallint, journal character varying, page character varying, image_url character varying, mention_type mention_type, source character varying, note character varying)
 LANGUAGE sql
 STABLE
AS $function$
WITH impact_and_citations AS (
	-- impact for project
	SELECT
		impact_for_project.project,
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
		mention.note
	FROM
		mention
	INNER JOIN
		impact_for_project ON impact_for_project.mention = mention.id
	-- does not deduplicate identical entries, but we will do so below with DISTINCT
	-- from scraped citations
	UNION ALL
	-- scraped citations from reference papers
	SELECT
		project,
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
		source,
		-- scraped citations have no note prop
		-- we need this prop in the edit impact section
		NULL as note
	FROM
		citation_by_project()
) SELECT DISTINCT ON (impact_and_citations.project, impact_and_citations.id) * FROM impact_and_citations;
;
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
		ARRAY_AGG(login_for_account.email) AS email,
		ARRAY_AGG(login_for_account.home_organisation) AS affiliation,
		BOOL_OR(maintainer_ids.is_primary) AS is_primary
	FROM
		maintainer_ids
	INNER JOIN
		login_for_account ON login_for_account.account = maintainer_ids.maintainer
	GROUP BY
		maintainer_ids.maintainer
	-- primary as first record
	ORDER BY
		is_primary DESC;
	RETURN;
END
$function$
;

CREATE OR REPLACE FUNCTION public.maintainers_of_organisation(organisation_id uuid)
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

	IF organisation_id IS NULL THEN
		RAISE EXCEPTION USING MESSAGE = 'Please provide a organisation id';
	END IF;

	IF NOT organisation_id IN (SELECT * FROM organisations_of_current_maintainer()) AND
		CURRENT_USER IS DISTINCT FROM 'rsd_admin' AND (
			SELECT rolsuper FROM pg_roles WHERE rolname = CURRENT_USER
		) IS DISTINCT FROM TRUE THEN
		RAISE EXCEPTION USING MESSAGE = 'You are not a maintainer of this organisation';
	END IF;

	RETURN QUERY
	WITH maintainer_ids AS (
		-- primary maintainer of organisation
		SELECT
			organisation.primary_maintainer AS maintainer,
			TRUE AS is_primary
		FROM
			organisation
		WHERE
			organisation.id = organisation_id
		-- append second selection
		UNION ALL
		-- other maintainers of organisation
		SELECT
			maintainer_for_organisation.maintainer AS maintainer,
			FALSE AS is_primary
		FROM
			maintainer_for_organisation
		WHERE
			maintainer_for_organisation.organisation = organisation_id
	)
	SELECT
		maintainer_ids.maintainer AS maintainer,
		ARRAY_AGG(login_for_account."name") AS name,
		ARRAY_AGG(login_for_account.email) AS email,
		ARRAY_AGG(login_for_account.home_organisation) AS affiliation,
		BOOL_OR(maintainer_ids.is_primary) AS is_primary
	FROM
		maintainer_ids
	INNER JOIN
		login_for_account ON login_for_account.account = maintainer_ids.maintainer
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
		mention
	INNER JOIN
		mention_for_software ON mention_for_software.mention = mention.id
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
		citation_by_software()
)
SELECT DISTINCT ON (mentions_and_citations.software, mentions_and_citations.id) * FROM mentions_and_citations;
$function$
;

CREATE OR REPLACE FUNCTION public.releases_by_organisation()
 RETURNS TABLE(organisation_id uuid, software_id uuid, software_slug character varying, software_name character varying, release_doi citext, release_tag character varying, release_date timestamp with time zone, release_year smallint, release_authors character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT DISTINCT ON (organisation_id, software_id, mention.id)
	organisation.id AS organisation_id,
	software.id AS software_id,
	software.slug AS software_slug,
	software.brand_name AS software_name,
	mention.doi AS release_doi,
	mention.version AS release_tag,
	mention.doi_registration_date AS release_date,
	mention.publication_year AS release_year,
	mention.authors AS release_authors
FROM
	organisation
CROSS JOIN
	list_child_organisations(organisation.id)
INNER JOIN
	software_for_organisation ON list_child_organisations.organisation_id = software_for_organisation.organisation
INNER JOIN
	software ON software.id = software_for_organisation.software
INNER JOIN
	"release" ON "release".software = software.id
INNER JOIN
	release_version ON release_version.release_id = "release".software
INNER JOIN
	mention ON mention.id = release_version.mention_id
;
$function$
;

create policy "anyone_can_read"
on "public"."software_for_community"
as permissive
for select
to rsd_web_anon, rsd_user
using (((software IN ( SELECT software.id
   FROM software)) AND (status = 'approved'::request_status)));


