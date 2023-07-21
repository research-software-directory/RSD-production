---------- CREATED BY MIGRA ----------

drop function if exists "public"."count_software_countributors"();

alter type "public"."mention_type" rename to "mention_type__old_version_to_be_dropped";

create type "public"."mention_type" as enum ('blogPost', 'book', 'bookSection', 'computerProgram', 'conferencePaper', 'dataset', 'interview', 'highlight', 'journalArticle', 'magazineArticle', 'newspaperArticle', 'poster', 'presentation', 'report', 'thesis', 'videoRecording', 'webpage', 'workshop', 'other');

create table "public"."backend_log" (
    "id" uuid not null,
    "service_name" character varying,
    "table_name" character varying,
    "reference_id" uuid,
    "message" character varying,
    "stack_trace" character varying,
    "other_data" jsonb,
    "created_at" timestamp with time zone not null,
    "updated_at" timestamp with time zone not null
);


alter table "public"."backend_log" enable row level security;

alter table "public"."mention" alter column mention_type type "public"."mention_type" using mention_type::text::"public"."mention_type";

drop type "public"."mention_type__old_version_to_be_dropped";

alter table "public"."package_manager" add column "download_count_last_error" character varying(500);

alter table "public"."package_manager" add column "reverse_dependency_count_last_error" character varying(500);

alter table "public"."repository_url" add column "basic_data_last_error" character varying(500);

alter table "public"."repository_url" add column "commit_history_last_error" character varying(500);

alter table "public"."repository_url" add column "contributor_count_last_error" character varying(500);

alter table "public"."repository_url" add column "languages_last_error" character varying(500);

alter table "public"."software" add column "closed_source" boolean not null default false;

CREATE UNIQUE INDEX backend_log_pkey ON public.backend_log USING btree (id);

alter table "public"."backend_log" add constraint "backend_log_pkey" PRIMARY KEY using index "backend_log_pkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.count_software_contributors()
 RETURNS TABLE(software uuid, contributor_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY SELECT
		contributor.software, COUNT(contributor.id) AS contributor_cnt
	FROM
		contributor
	GROUP BY
		contributor.software;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_backend_log()
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

CREATE OR REPLACE FUNCTION public.sanitise_update_backend_log()
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

CREATE OR REPLACE FUNCTION public.count_software_contributors_mentions()
 RETURNS TABLE(id uuid, contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY SELECT
		software.id, count_software_contributors.contributor_cnt, count_software_mentions.mention_cnt
	FROM
		software
	LEFT JOIN
		count_software_contributors() AS count_software_contributors ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() AS count_software_mentions ON software.id=count_software_mentions.software;
END
$function$
;

CREATE OR REPLACE FUNCTION public.related_software_for_project(project_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, status relation_status)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.updated_at,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt,
		software.is_published,
		software_for_project.status
	FROM
		software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	INNER JOIN
		software_for_project ON software.id=software_for_project.software
	WHERE
		software_for_project.project=project_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.related_software_for_software(software_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.updated_at,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt,
		software.is_published
	FROM
		software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	INNER JOIN
		software_for_software ON software.id=software_for_software.relation
	WHERE
		software_for_software.origin = software_id
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_maintainer(maintainer_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, is_published boolean, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.is_published,
		software.updated_at,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt
	FROM
		software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	INNER JOIN
		maintainer_for_software ON software.id=maintainer_for_software.software
	WHERE
		maintainer_for_software.maintainer=maintainer_id
;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_organisation(organisation_id uuid)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, is_published boolean, is_featured boolean, status relation_status, contributor_cnt bigint, mention_cnt bigint, updated_at timestamp with time zone, organisation uuid)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	RETURN QUERY
	SELECT DISTINCT ON (software.id)
		software.id,
		software.slug,
		software.brand_name,
		software.short_statement,
		software.is_published,
		software_for_organisation.is_featured,
		software_for_organisation.status,
		count_software_contributors.contributor_cnt,
		count_software_mentions.mention_cnt,
		software.updated_at,
		software_for_organisation.organisation
	FROM
		software
	LEFT JOIN
		software_for_organisation ON software.id=software_for_organisation.software
	LEFT JOIN
		count_software_contributors() ON software.id=count_software_contributors.software
	LEFT JOIN
		count_software_mentions() ON software.id=count_software_mentions.software
	WHERE
		software_for_organisation.organisation IN (
			SELECT list_child_organisations.organisation_id FROM list_child_organisations(organisation_id)
		)
	;
END
$function$
;

CREATE OR REPLACE FUNCTION public.software_overview()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.updated_at,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt,
	software.is_published,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang
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
;
$function$
;

CREATE OR REPLACE FUNCTION public.software_search(search character varying)
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[])
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	software.id,
	software.slug,
	software.brand_name,
	software.short_statement,
	software.updated_at,
	count_software_contributors.contributor_cnt,
	count_software_mentions.mention_cnt,
	software.is_published,
	keyword_filter_for_software.keywords,
	keyword_filter_for_software.keywords_text,
	prog_lang_filter_for_software.prog_lang
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
on "public"."backend_log"
as permissive
for all
to rsd_admin
using (true)
with check (true);


CREATE TRIGGER check_backend_log_before_delete BEFORE DELETE ON public.backend_log FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_backend_log_before_insert BEFORE INSERT ON public.backend_log FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_backend_log_before_update BEFORE UPDATE ON public.backend_log FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER sanitise_insert_backend_log BEFORE INSERT ON public.backend_log FOR EACH ROW EXECUTE FUNCTION sanitise_insert_backend_log();

CREATE TRIGGER sanitise_update_backend_log BEFORE UPDATE ON public.backend_log FOR EACH ROW EXECUTE FUNCTION sanitise_update_backend_log();

