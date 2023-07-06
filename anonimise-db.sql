-- use this script if you want to upload a backup to a dev environment

BEGIN;

UPDATE organisation SET primary_maintainer = NULL;

DELETE FROM orcid_whitelist;

DELETE FROM oaipmh;

DELETE FROM invite_maintainer_for_project;
DELETE FROM invite_maintainer_for_software;
DELETE FROM invite_maintainer_for_organisation;

DELETE FROM maintainer_for_software;
DELETE FROM maintainer_for_project;
DELETE FROM maintainer_for_organisation;

DELETE FROM login_for_account;
DELETE FROM account;

DELETE FROM testimonial WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM contributor WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM repository_url WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM package_manager WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM keyword_for_software WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM license_for_software WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM release_version WHERE release_id IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM release WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM mention_for_software WHERE software IN (SELECT id FROM software WHERE NOT is_published);

DELETE FROM team_member WHERE project IN (SELECT id FROM project WHERE NOT is_published);
DELETE FROM url_for_project WHERE project IN (SELECT id FROM project WHERE NOT is_published);
DELETE FROM keyword_for_project WHERE project IN (SELECT id FROM project WHERE NOT is_published);
DELETE FROM research_domain_for_project WHERE project IN (SELECT id FROM project WHERE NOT is_published);
DELETE FROM output_for_project WHERE project IN (SELECT id FROM project WHERE NOT is_published);
DELETE FROM impact_for_project WHERE project IN (SELECT id FROM project WHERE NOT is_published);

DELETE FROM software_for_software WHERE origin IN (SELECT id FROM software WHERE NOT is_published) OR relation IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM project_for_project WHERE origin IN (SELECT id FROM project WHERE NOT is_published) OR relation IN (SELECT id FROM project WHERE NOT is_published);
DELETE FROM software_for_project WHERE software IN (SELECT id FROM software WHERE NOT is_published) OR project IN (SELECT id FROM project WHERE NOT is_published);
DELETE FROM software_for_organisation WHERE software IN (SELECT id FROM software WHERE NOT is_published);
DELETE FROM project_for_organisation WHERE project IN (SELECT id FROM project WHERE NOT is_published);

DELETE FROM software WHERE NOT is_published;
DELETE FROM project WHERE NOT is_published;

DELETE FROM image WHERE
	id NOT IN (SELECT image_id FROM software) AND
	id NOT IN (SELECT avatar_id FROM contributor) AND
	id NOT IN (SELECT image_id FROM project) AND
	id NOT IN (SELECT avatar_id FROM team_member) AND
	id NOT IN (SELECT logo_id FROM organisation);

DELETE FROM mention WHERE
	id NOT IN (SELECT mention FROM mention_for_software) AND
	id NOT IN (SELECT mention FROM output_for_project) AND
	id NOT IN (SELECT mention FROM impact_for_project) AND
	id NOT IN (SELECT mention_id FROM release_version);

COMMIT;
