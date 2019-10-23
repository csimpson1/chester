--Create the DB

CREATE OR REPLACE DATABASE chester;

USE chester;

--Create the main table and audit table

CREATE OR REPLACE TABLE matches(
	id int NOT NULL AUTO_INCREMENT,
	event varchar(50),
	site varchar(50),
	match_date date	NOT NULL,
	match_round int,
	white varchar(50),
	black varchar(50),
	result varchar(8),
	movetext varchar(800) NOT NULL,
	created_by varchar(20) NOT NULL,
	created_on datetime NOT NULL,
	updated_by varchar(20) NOT NULL,
	updated_on datetime NOT NULL,
	PRIMARY KEY (id)
);

/*
Normally I'd want the version_id to be NOT NULL, but it messes up the trigger. If it is
specified as not null then

1) We could try using an INSERT SELECT, but the version ID isn't present here. There isn't
a way to combine an INSERT SELECT with a regular insert statement to include the value 
with those that are selected.

2) We could try to insert a row with the version ID and the match ID, and then use several
selects in combination with an update statement, but this results in a larger query.
*/

CREATE OR REPLACE TABLE matches_version (
	id int NOT NULL,
	version_id int,
	event varchar(50),
	site varchar(50),
	match_date date	NOT NULL,
	match_round int,
	white varchar(50),
	black varchar(50),
	result varchar(8),
	movetext varchar(800) NOT NULL,
	created_by varchar(20) NOT NULL,
	created_on datetime NOT NULL,
	updated_by varchar(20) NOT NULL,
	updated_on datetime NOT NULL,
	PRIMARY KEY (id,version_id)
);

-- Create DB user accounts

CREATE OR REPLACE USER 'chester_web_user'@'localhost';
CREATE OR REPLACE USER 'chester_upload_user'@'localhost';

-- Give permissions to user accounts

GRANT SELECT ON chester.matches TO chester_web_user@localhost;
GRANT SELECT,INSERT,UPDATE ON chester.matches TO chester_upload_user@localhost;
GRANT SELECT,INSERT,UPDATE ON chester.matches_version to chester_upload_user@localhost;

-- Create triggers to update the audit tables

DELIMITER //
CREATE OR REPLACE DEFINER='root'@'localhost' TRIGGER insert_match
	AFTER INSERT ON matches FOR EACH ROW BEGIN
		
		DECLARE last_insert int;
		SET @last_insert = NEW.id;
		
		INSERT INTO matches_version
		SELECT * FROM matches WHERE  matches.id=@last_insert;
		
		UPDATE matches_version
		SET version_id = 1
		WHERE matches_version.id = @last_insert;

	END;//

DELIMITER ;
DELIMITER //

CREATE OR REPLACE DEFINER='root'@'localhost' TRIGGER update_match
	AFTER UPDATE ON matches FOR EACH ROW BEGIN
		DECLARE last_insert int;
		DECLARE last_version int;
		SET @last_insert = NEW.id;
		SELECT version_id INTO @last_version FROM matches_version WHERE matches_version.id=@last_insert;
		INSERT INTO matches_version
		SELECT * FROM matches where matches.id=@last_insert;

		UPDATE matches_version
		SET version_id = @last_version + 1
		WHERE match_version.id = @last_insert
		AND matches_version.version_id IS NULL;
	END;//

DELIMITER ;
