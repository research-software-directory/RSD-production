---------- CREATED BY MIGRA ----------

-- manually added
CREATE DOMAIN "application/octet-stream" AS BYTEA;

DROP FUNCTION public.get_image;
-- end manually added

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.get_image(uid character varying)
 RETURNS "application/octet-stream"
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE headers TEXT;
DECLARE blob BYTEA;

BEGIN
	SELECT format(
		'[{"Content-Type": "%s"},'
		'{"Content-Disposition": "inline; filename=\"%s\""},'
		'{"Cache-Control": "max-age=31536001"}]',
		mime_type,
		uid)
	FROM image WHERE id = uid INTO headers;

	PERFORM set_config('response.headers', headers, TRUE);

	SELECT decode(image.data, 'base64') FROM image WHERE id = uid INTO blob;

	IF FOUND
		THEN RETURN(blob);
	ELSE RAISE SQLSTATE 'PT404'
		USING
			message = 'NOT FOUND',
			detail = 'File not found',
			hint = format('%s seems to be an invalid file id', image_id);
	END IF;
END
$function$
;

