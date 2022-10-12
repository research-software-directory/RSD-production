---------- CREATED BY MIGRA ----------

create table "public"."orcid_whitelist" (
    "orcid" character varying(19) not null
);


alter table "public"."orcid_whitelist" enable row level security;

alter table "public"."contributor" add column "position" integer;

alter table "public"."team_member" add column "position" integer;

CREATE UNIQUE INDEX orcid_whitelist_pkey ON public.orcid_whitelist USING btree (orcid);

alter table "public"."orcid_whitelist" add constraint "orcid_whitelist_pkey" PRIMARY KEY using index "orcid_whitelist_pkey";

alter table "public"."orcid_whitelist" add constraint "orcid_whitelist_orcid_check" CHECK (((orcid)::text ~ '^\d{4}-\d{4}-\d{4}-\d{3}[0-9X]$'::text));

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.project_count_by_organisation(public boolean DEFAULT true)
 RETURNS TABLE(organisation uuid, project_cnt bigint)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
	IF (public) THEN
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT project_for_organisation.project) AS project_cnt
		FROM
			project_for_organisation
		CROSS JOIN list_parent_organisations(project_for_organisation.organisation)
		WHERE
			status = 'approved' AND
			project IN (
				SELECT id FROM project WHERE is_published=TRUE
			)
		GROUP BY list_parent_organisations.organisation_id;
	ELSE
		RETURN QUERY
		SELECT
			list_parent_organisations.organisation_id,
			COUNT(DISTINCT project_for_organisation.project) AS project_cnt
		FROM
			project_for_organisation
		CROSS JOIN list_parent_organisations(project_for_organisation.organisation)
		GROUP BY list_parent_organisations.organisation_id;
	END IF;
END
$function$
;

create policy "admin_all_rights"
on "public"."orcid_whitelist"
as permissive
for all
to rsd_admin
using (true)
with check (true);
