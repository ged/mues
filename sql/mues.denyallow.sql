/*
   MUES Engine Table Schema (MySQL)
	$Id: mues.denyallow.sql,v 1.1 2001/05/14 11:11:35 deveiant Exp $
	Time-stamp: <31-Mar-2001 10:22:43 deveiant>

	Michael Granger <ged@FaerieMUD.org>
	Copyright (c) 1998-2001 The FaerieMUD Consortium. All rights reserved.

	This schema is free software. You may use, modify, and/or redistribute
	this software under the terms of the Perl Artistic License. (See
	http://language.perl.com/misc/Artistic.html)

 */

/* The denied host/player table */
DROP TABLE IF EXISTS deny;
CREATE TABLE deny (
	id					INT				UNSIGNED auto_increment PRIMARY KEY,
	ts					TIMESTAMP(14),
	
	/* Associations */
	creatorId			INT				UNSIGNED NOT NULL REFERENCES player(id),

	/* Data fields */
	username			VARCHAR(50)		NOT NULL DEFAULT '*',
	host				VARCHAR(85)		NOT NULL DEFAULT '*',
	startTime			TIME			NOT NULL DEFAULT '0:00',
	endTime				TIME			NOT NULL DEFAULT '23:59',

	description			VARCHAR(255)	NOT NULL,

	dateCreated			DATETIME		NOT NULL,
	endDate				DATETIME
);

/* The allowed host/player table */
DROP TABLE IF EXISTS allow;
CREATE TABLE allow (
	id					INT				UNSIGNED auto_increment PRIMARY KEY,
	ts					TIMESTAMP(14),
	
	/* Associations */
	creatorId			INT				UNSIGNED NOT NULL REFERENCES player(id),

	/* Data fields */
	username			VARCHAR(50)		NOT NULL DEFAULT '*',
	host				VARCHAR(85)		NOT NULL DEFAULT '*',
	startTime			TIME			NOT NULL DEFAULT '0:00',
	endTime				TIME			NOT NULL DEFAULT '23:59',

	description			VARCHAR(255)	NOT NULL,

	dateCreated			DATETIME		NOT NULL,
	endDate				DATETIME
);


