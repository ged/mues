/*
   MUES Player Table Schema (MySQL)
	$Id: mues.user.sql,v 1.1 2001/03/15 02:22:16 deveiant Exp $
	Time-stamp: <28-Jan-2001 02:38:09 deveiant>

	Michael Granger <ged@FaerieMUD.org>
	Copyright (c) 1998-2001 The FaerieMUD Consortium. All rights reserved.

	This schema is free software. You may use, modify, and/or redistribute
	this software under the terms of the Perl Artistic License. (See
	http://language.perl.com/misc/Artistic.html)

 */

/* The Player table */
DROP TABLE IF EXISTS player;
CREATE TABLE player (
	
	/* Tableadapter fields */
	id					INT				UNSIGNED auto_increment PRIMARY KEY,
	ts					TIMESTAMP(12),
	
	/* Data fields */
	username			VARCHAR(50) 	NOT NULL,
	cryptedPass			VARCHAR(20)		NOT NULL,
	realname			VARCHAR(75),
	emailAddress		VARCHAR(75),
	lastLogin			DATETIME,
	lastHost			VARCHAR(75),

	dateCreated			DATETIME,
	age					INT				UNSIGNED NOT NULL DEFAULT 0,

	level				ENUM(
							"player",
							"creator",
							"implementor",
							"admin"
							)			NOT NULL DEFAULT 'player',

	preferences			BLOB,
	characters			BLOB,

	/* Indexes */
	UNIQUE( username )
);


