---------- CREATED MANUALLY ----------
UPDATE mention SET "source" = 'RSD' WHERE "source" = 'manual';

---------- CREATED BY MIGRA ----------

drop policy "maintainer_all_rights" on "public"."mention";

alter type "public"."mention_type" rename to "mention_type__old_version_to_be_dropped";

create type "public"."mention_type" as enum ('blogPost', 'book', 'bookSection', 'computerProgram', 'conferencePaper', 'dataset', 'interview', 'highlight', 'journalArticle', 'magazineArticle', 'newspaperArticle', 'presentation', 'report', 'thesis', 'videoRecording', 'webpage', 'workshop', 'other');

alter table "public"."mention" alter column mention_type type "public"."mention_type" using mention_type::text::"public"."mention_type";

drop type "public"."mention_type__old_version_to_be_dropped";

alter table "public"."mention" add column "note" character varying(500);

alter table "public"."oaipmh" alter column "data" set data type xml using "data"::xml;

alter table "public"."keyword" add constraint "keyword_value_check" CHECK ((value ~ '^\S+( \S+)*$'::citext));

create policy "maintainer_can_delete"
on "public"."keyword"
as permissive
for delete
to rsd_user
using (true);


create policy "maintainer_can_delete"
on "public"."mention"
as permissive
for delete
to rsd_user
using (true);


create policy "maintainer_can_insert"
on "public"."mention"
as permissive
for insert
to rsd_user
with check (true);


create policy "maintainer_can_read"
on "public"."mention"
as permissive
for select
to rsd_user
using (true);
