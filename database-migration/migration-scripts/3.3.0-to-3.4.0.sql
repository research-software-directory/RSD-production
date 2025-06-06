---------- CREATED BY MIGRA ----------

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.project_cnt_by_person(acc_id uuid, orc_id character varying)
 RETURNS TABLE(project_cnt bigint, acc_id uuid, orc_id character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	count(*) AS project_cnt,
	acc_id,
	orc_id
FROM
	project_by_public_profile()
WHERE
	project_by_public_profile.orcid = orc_id
	OR
	project_by_public_profile.account = acc_id
$function$
;

CREATE OR REPLACE FUNCTION public.public_persons_overview()
 RETURNS TABLE(account uuid, display_name character varying, affiliation character varying, role character varying, avatar_id character varying, orcid character varying, is_public boolean, software_cnt bigint, project_cnt bigint, keywords character varying[])
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
SELECT
	public_user_profile.account,
	public_user_profile.display_name,
	public_user_profile.affiliation,
	public_user_profile.role,
	public_user_profile.avatar_id,
	public_user_profile.orcid,
	public_user_profile.is_public,
	software_cnt_by_person.software_cnt,
	project_cnt_by_person.project_cnt,
	-- include keywords for future use
	array[]::varchar[] AS keywords
FROM
	public_user_profile()
LEFT JOIN
	software_cnt_by_person(public_user_profile.account,public_user_profile.orcid) ON (
		software_cnt_by_person.acc_id = public_user_profile.account
		OR
		software_cnt_by_person.orc_id = public_user_profile.orcid
	)
LEFT JOIN
	project_cnt_by_person(public_user_profile.account,public_user_profile.orcid) ON (
		project_cnt_by_person.acc_id = public_user_profile.account
		OR
		project_cnt_by_person.orc_id = public_user_profile.orcid
	)
$function$
;

CREATE OR REPLACE FUNCTION public.software_cnt_by_person(acc_id uuid, orc_id character varying)
 RETURNS TABLE(software_cnt bigint, acc_id uuid, orc_id character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	count(*) AS software_cnt,
	acc_id,
	orc_id
FROM
	software_by_public_profile()
WHERE
	software_by_public_profile.orcid = orc_id
	OR
	software_by_public_profile.account = acc_id
$function$
;

-- ADDED MANUALLY, unclear why this was not included

CREATE OR REPLACE FUNCTION global_search(query VARCHAR) RETURNS TABLE(
	slug VARCHAR,
	domain VARCHAR,
	rsd_host VARCHAR,
	name VARCHAR,
	source TEXT,
	is_published BOOLEAN,
	rank INTEGER,
	index_found INTEGER
) LANGUAGE sql STABLE AS
$$
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
		community.slug ILIKE CONCAT('%', query, '%') OR community."name" ILIKE CONCAT('%', query, '%')
	UNION ALL
	-- PERSONS search
	SELECT
		CAST (public_user_profile.account AS VARCHAR) as slug,
		NULL AS domain,
		NULL as rsd_host,
		public_user_profile.display_name as "name",
		'persons' AS "source",
		public_user_profile.is_public AS is_published,
		(CASE
			WHEN public_user_profile.display_name ILIKE query THEN 0
			WHEN public_user_profile.display_name ILIKE CONCAT(query, '%') THEN 2
			ELSE 3
		END) AS rank,
		0 as index_found
	FROM
		public_user_profile()
	WHERE
		public_user_profile.display_name ILIKE CONCAT('%', query, '%');
$$;

