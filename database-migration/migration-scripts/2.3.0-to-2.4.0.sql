---------- CREATED BY MIGRA ----------

drop function if exists "public"."person_mentions"();

create table "public"."admin_account" (
    "account_id" uuid not null
);


alter table "public"."admin_account" enable row level security;

alter table "public"."account" add column "public_orcid_profile" boolean not null default false;

CREATE UNIQUE INDEX admin_account_pkey ON public.admin_account USING btree (account_id);

alter table "public"."admin_account" add constraint "admin_account_pkey" PRIMARY KEY using index "admin_account_pkey";

alter table "public"."admin_account" add constraint "admin_account_account_id_fkey" FOREIGN KEY (account_id) REFERENCES account(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.project_by_public_profile()
 RETURNS TABLE(id uuid, slug character varying, title character varying, subtitle character varying, date_start date, date_end date, updated_at timestamp with time zone, is_published boolean, image_contain boolean, image_id character varying, keywords citext[], keywords_text text, research_domain character varying[], participating_organisations character varying[], impact_cnt integer, output_cnt integer, project_status character varying, orcid character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	DISTINCT ON (project.id,public_profile.orcid)
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
	public_profile.orcid
FROM
	public_profile()
INNER JOIN
	team_member ON public_profile.orcid = team_member.orcid
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
 RETURNS TABLE(id uuid, is_contact_person boolean, email_address character varying, family_names character varying, given_names character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, "position" integer, project uuid, public_orcid_profile character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
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
	public_profile.orcid as public_orcid_profile
FROM
	team_member
LEFT JOIN
	public_profile() ON team_member.orcid = public_profile.orcid
WHERE
	team_member.project = project_id
;
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
	account ON login_for_account.account = account.id
WHERE
	login_for_account.provider='orcid' AND account.public_orcid_profile = TRUE
$function$
;

CREATE OR REPLACE FUNCTION public.software_by_public_profile()
 RETURNS TABLE(id uuid, slug character varying, brand_name character varying, short_statement character varying, image_id character varying, updated_at timestamp with time zone, contributor_cnt bigint, mention_cnt bigint, is_published boolean, keywords citext[], keywords_text text, prog_lang text[], licenses character varying[], orcid character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	DISTINCT ON (software.id,public_profile.orcid)
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
	public_profile.orcid
FROM
	public_profile()
INNER JOIN
	contributor ON public_profile.orcid = contributor.orcid
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
 RETURNS TABLE(id uuid, is_contact_person boolean, email_address character varying, family_names character varying, given_names character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, "position" integer, software uuid, public_orcid_profile character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
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
	public_profile.orcid as public_orcid_profile
FROM
	contributor
LEFT JOIN
	public_profile() ON contributor.orcid = public_profile.orcid
WHERE
	contributor.software = software_id
;
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
	DELETE FROM invite_maintainer_for_software WHERE created_by = account_id OR claimed_by = account_id;
	DELETE FROM invite_maintainer_for_project WHERE created_by = account_id OR claimed_by = account_id;
	DELETE FROM invite_maintainer_for_organisation WHERE created_by = account_id OR claimed_by = account_id;
	UPDATE organisation SET primary_maintainer = NULL WHERE primary_maintainer = account_id;
	DELETE FROM admin_account WHERE admin_account.account_id = delete_account.account_id;
	DELETE FROM login_for_account WHERE account = account_id;
	DELETE FROM account WHERE id = account_id;
END
$function$
;

CREATE OR REPLACE FUNCTION public.person_mentions()
 RETURNS TABLE(id uuid, given_names character varying, family_names character varying, email_address character varying, affiliation character varying, role character varying, orcid character varying, avatar_id character varying, origin character varying, slug character varying, public_orcid_profile character varying)
 LANGUAGE sql
 STABLE
AS $function$
SELECT
	contributor.id,
	contributor.given_names,
	contributor.family_names,
	contributor.email_address,
	contributor.affiliation,
	contributor.role,
	contributor.orcid,
	contributor.avatar_id,
	'contributor' AS origin,
	software.slug,
	public_profile.orcid as public_orcid_profile
FROM
	contributor
INNER JOIN
	software ON contributor.software = software.id
LEFT JOIN
	public_profile() ON public_profile.orcid=contributor.orcid
UNION
SELECT
	team_member.id,
	team_member.given_names,
	team_member.family_names,
	team_member.email_address,
	team_member.affiliation,
	team_member.role,
	team_member.orcid,
	team_member.avatar_id,
	'team_member' AS origin,
	project.slug,
	public_profile.orcid as public_orcid_profile
FROM
	team_member
INNER JOIN
	project ON team_member.project = project.id
LEFT JOIN
	public_profile() ON public_profile.orcid = team_member.orcid
$function$
;

create policy "admin_all_rights"
on "public"."admin_account"
as permissive
for all
to rsd_admin
using (true)
with check (true);


CREATE TRIGGER check_admin_account_before_delete BEFORE DELETE ON public.admin_account FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_delete_action();

CREATE TRIGGER check_admin_account_before_insert BEFORE INSERT ON public.admin_account FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

CREATE TRIGGER check_admin_account_before_update BEFORE UPDATE ON public.admin_account FOR EACH STATEMENT EXECUTE FUNCTION check_user_agreement_on_action();

