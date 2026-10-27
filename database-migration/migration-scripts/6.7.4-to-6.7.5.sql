---------- CREATED BY MIGRA ----------

alter table "public"."repository_url_for_software" enable row level security;

alter table "public"."testimonial_for_project" enable row level security;

create policy "admin_all_rights"
on "public"."repository_url_for_software"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."repository_url_for_software"
as permissive
for select
to rsd_web_anon, rsd_user
using ((software IN ( SELECT software.id
   FROM software)));


create policy "maintainer_delete"
on "public"."repository_url_for_software"
as permissive
for delete
to rsd_user
using ((software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer))));


create policy "maintainer_insert"
on "public"."repository_url_for_software"
as permissive
for insert
to rsd_user
with check (software IN ( SELECT software_of_current_maintainer.software_of_current_maintainer
   FROM software_of_current_maintainer() software_of_current_maintainer(software_of_current_maintainer)));


create policy "admin_all_rights"
on "public"."testimonial_for_project"
as permissive
for all
to rsd_admin
using (true)
with check (true);


create policy "anyone_can_read"
on "public"."testimonial_for_project"
as permissive
for select
to rsd_web_anon, rsd_user
using ((project IN ( SELECT project.id
   FROM project)));


create policy "maintainer_all_rights"
on "public"."testimonial_for_project"
as permissive
for all
to rsd_user
using ((project IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer))))
with check (project IN ( SELECT projects_of_current_maintainer.projects_of_current_maintainer
   FROM projects_of_current_maintainer() projects_of_current_maintainer(projects_of_current_maintainer)));


