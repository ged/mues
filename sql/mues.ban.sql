/*
   MUES Engine Table Schema (MySQL)
	$Id: mues.ban.sql,v 1.1 2001/03/15 02:22:16 deveiant Exp $
	Time-stamp: <28-Jan-2001 02:17:10 deveiant>

	Michael Granger <ged@FaerieMUD.org>
	Copyright (c) 1998-2001 The FaerieMUD Consortium. All rights reserved.

	This schema is free software. You may use, modify, and/or redistribute
	this software under the terms of the Perl Artistic License. (See
	http://language.perl.com/misc/Artistic.html)

 */

/* The banned host/player table */
DROP TABLE IF EXISTS ban;
CREATE TABLE ban (
	id					INT				UNSIGNED auto_increment PRIMARY KEY,
	ts					TIMESTAMP(14),
	
	/* Associations */
	creatorId			INT				UNSIGNED NOT NULL REFERENCES player(id),

	/* Data fields */
	username			VARCHAR(50)		NOT NULL,
	host				VARCHAR(85)		NOT NULL DEFAULT '*',
	startTime			TIME			NOT NULL DEFAULT '0:00',
	endTime				TIME			NOT NULL DEFAULT '23:59',

	description			VARCHAR(255)	NOT NULL,

	dateCreated			DATETIME		NOT NULL,
	endDate				DATETIME
);


