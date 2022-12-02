---------- CREATED BY MIGRA ----------

-- IMPORTANT: don't forget to change the env variable PGRST_DB_ANON_ROLE from web_anon to rsd_web_anon'
-- this script also has some manually added code, see "-- manually added"

drop policy "anyone_can_read" on "public"."contributor";

drop policy "anyone_can_read" on "public"."image";

drop policy "anyone_can_read" on "public"."impact_for_project";

drop policy "anyone_can_read" on "public"."keyword";

drop policy "anyone_can_read" on "public"."keyword_for_project";

drop policy "anyone_can_read" on "public"."keyword_for_software";

drop policy "anyone_can_read" on "public"."license_for_software";

drop policy "anyone_can_read" on "public"."mention";

drop policy "anyone_can_read" on "public"."mention_for_software";

drop policy "anyone_can_read" on "public"."meta_pages";

drop policy "anyone_can_read" on "public"."oaipmh";

drop policy "anyone_can_read" on "public"."organisation";

drop policy "anyone_can_read" on "public"."output_for_project";

drop policy "anyone_can_read" on "public"."project";

drop policy "anyone_can_read" on "public"."project_for_organisation";

drop policy "anyone_can_read" on "public"."project_for_project";

drop policy "anyone_can_read" on "public"."release";

drop policy "anyone_can_read" on "public"."release_content";

drop policy "anyone_can_read" on "public"."repository_url";

drop policy "anyone_can_read" on "public"."research_domain";

drop policy "anyone_can_read" on "public"."research_domain_for_project";

drop policy "anyone_can_read" on "public"."software";

drop policy "anyone_can_read" on "public"."software_for_organisation";

drop policy "anyone_can_read" on "public"."software_for_project";

drop policy "anyone_can_read" on "public"."software_for_software";

drop policy "anyone_can_read" on "public"."team_member";

drop policy "anyone_can_read" on "public"."testimonial";

drop policy "anyone_can_read" on "public"."url_for_project";


-- manually added
ALTER ROLE web_anon RENAME TO rsd_web_anon;
ALTER ROLE authenticator RENAME TO rsd_authenticator;

UPDATE repository_url SET languages = NULL, languages_scraped_at = NULL, commit_history = NULL, commit_history_scraped_at = NULL; 
-- end manually added


create policy "anyone_can_read"
on "public"."contributor"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."image"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "anyone_can_read"
on "public"."impact_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));


create policy "anyone_can_read"
on "public"."keyword"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "anyone_can_read"
on "public"."keyword_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));


create policy "anyone_can_read"
on "public"."keyword_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."license_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."mention"
as permissive
for select
to rsd_web_anon, rsd_user
using (((id IN ( SELECT mention_for_software.mention
   FROM mention_for_software)) OR (id IN ( SELECT output_for_project.mention
   FROM output_for_project)) OR (id IN ( SELECT impact_for_project.mention
   FROM impact_for_project))));


create policy "anyone_can_read"
on "public"."mention_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."meta_pages"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "anyone_can_read"
on "public"."oaipmh"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "anyone_can_read"
on "public"."organisation"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "anyone_can_read"
on "public"."output_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));


create policy "anyone_can_read"
on "public"."project"
as permissive
for select
to rsd_web_anon, rsd_user
using (is_published);


create policy "anyone_can_read"
on "public"."project_for_organisation"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));


create policy "anyone_can_read"
on "public"."project_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using (((origin IN ( SELECT project.id
   FROM project)) AND (relation IN ( SELECT project.id
   FROM project))));


create policy "anyone_can_read"
on "public"."release"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."release_content"
as permissive
for select
to rsd_web_anon, rsd_user
using ((release_id IN ( SELECT release.id
   FROM release)));


create policy "anyone_can_read"
on "public"."repository_url"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."research_domain"
as permissive
for select
to rsd_web_anon, rsd_user
using (true);


create policy "anyone_can_read"
on "public"."research_domain_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));


create policy "anyone_can_read"
on "public"."software"
as permissive
for select
to rsd_web_anon, rsd_user
using (is_published);


create policy "anyone_can_read"
on "public"."software_for_organisation"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."software_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using (((software IN ( SELECT software.id
   FROM software)) AND (project IN ( SELECT project.id
   FROM project))));


create policy "anyone_can_read"
on "public"."software_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using (((origin IN ( SELECT software.id
   FROM software)) AND (relation IN ( SELECT software.id
   FROM software))));


create policy "anyone_can_read"
on "public"."team_member"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));


create policy "anyone_can_read"
on "public"."testimonial"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "anyone_can_read"
on "public"."url_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));
