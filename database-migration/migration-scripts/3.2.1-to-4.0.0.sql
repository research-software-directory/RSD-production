-- work in progress

-- migration statement for public profiles
-- this might go wrong if someone has multiple ORCIDs attached to their account
-- this migrates existing names and splits them on the first space
WITH existing_public_profiles AS (
	SELECT account.id, account.public_orcid_profile, COALESCE((STRING_TO_ARRAY(login_for_account.name, ' '))[1], '') AS given_names, COALESCE(ARRAY_TO_STRING((STRING_TO_ARRAY(login_for_account.name, ' '))[2:], ' '), '') AS family_names
	FROM account
	LEFT JOIN login_for_account ON login_for_account.account = account.id AND provider = 'orcid'
	WHERE public_orcid_profile
)
INSERT INTO user_profile (account, is_public, given_names, family_names) SELECT id, public_orcid_profile, given_names, family_names FROM existing_public_profiles ON CONFLICT DO NOTHING;
