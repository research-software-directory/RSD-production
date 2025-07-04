---------- CREATED BY MIGRA ----------

create table "public"."user_access_token" (
    "id" uuid not null default gen_random_uuid(),
    "secret" character varying not null,
    "account" uuid not null,
    "expires_at" timestamp with time zone not null,
    "display_name" character varying(100) not null,
    "created_at" timestamp with time zone not null
);


alter table "public"."user_access_token" enable row level security;

CREATE INDEX user_access_token_account_idx ON public.user_access_token USING btree (account);

CREATE UNIQUE INDEX user_access_token_pkey ON public.user_access_token USING btree (id);

alter table "public"."user_access_token" add constraint "user_access_token_pkey" PRIMARY KEY using index "user_access_token_pkey";

alter table "public"."user_access_token" add constraint "user_access_token_account_fkey" FOREIGN KEY (account) REFERENCES account(id);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.cleanup_expired_token()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
	DELETE FROM user_access_token WHERE expires_at <= CURRENT_DATE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_my_user_access_token(id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
AS $function$
	DELETE FROM user_access_token
	WHERE
		account = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account')
		AND
		user_access_token.id = delete_my_user_access_token.id;
$function$
;

CREATE OR REPLACE FUNCTION public.my_user_access_tokens()
 RETURNS TABLE(id uuid, account uuid, expires_at timestamp with time zone, display_name character varying, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
	SELECT
		id,
		account,
		expires_at,
		display_name,
		created_at
	FROM user_access_token
	WHERE
		account = uuid(current_setting('request.jwt.claims', FALSE)::json->>'account')
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_insert_user_access_token()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	NEW.id = gen_random_uuid();
	NEW.created_at = LOCALTIMESTAMP;
	IF NEW.expires_at - NEW.created_at > INTERVAL '365 days' THEN
		RAISE EXCEPTION 'Access tokens should expire within one year';
	END IF;
	IF NEW.expires_at::date < NEW.created_at::date THEN
		RAISE EXCEPTION 'The selected expiration date cannot be in the past';
	END IF;
	return NEW;
END
$function$
;

CREATE OR REPLACE FUNCTION public.sanitise_update_user_access_token()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
	RAISE EXCEPTION 'Access tokens are not allowed to be updated';
END
$function$
;

create policy "admin_delete_all"
on "public"."user_access_token"
as permissive
for delete
to rsd_admin
using (true);


create policy "admin_insert_all"
on "public"."user_access_token"
as permissive
for insert
to rsd_admin
with check (true);


create policy "admin_select_all"
on "public"."user_access_token"
as permissive
for select
to rsd_admin
using (true);


CREATE TRIGGER sanitise_insert_user_access_token BEFORE INSERT ON public.user_access_token FOR EACH ROW EXECUTE FUNCTION sanitise_insert_user_access_token();

CREATE TRIGGER sanitise_update_user_access_token BEFORE UPDATE ON public.user_access_token FOR EACH ROW EXECUTE FUNCTION sanitise_update_user_access_token();

