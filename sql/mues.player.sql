/*

   MUES Player Table Schema (MySQL)
	$Id: mues.player.sql,v 1.2 2001/05/14 12:35:59 deveiant Exp $
	Time-stamp: <25-Apr-2001 12:22:35 deveiant>

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
	playerVersion		VARCHAR(10)		NOT NULL,
	username			VARCHAR(50) 	NOT NULL,
	cryptedPass			VARCHAR(20)		NOT NULL,							-- MD5 hexdigest
	realname			VARCHAR(75),
	emailAddress		VARCHAR(75),
	lastLogin			DATETIME,
	lastHost			VARCHAR(75),

	timeCreated			DATETIME,
	firstLoginTick		INT				UNSIGNED NOT NULL DEFAULT 0,		-- Tick of first login

	role				TINYINT			UNSIGNED NOT NULL DEFAULT 0,		-- Permissions role
	flags				INT				UNSIGNED NOT NULL DEFAULT 0,		-- Bitfield
	preferences			BLOB,												-- Frozen Ruby hash
	characters			BLOB,												-- Frozen Ruby hash

	/* Indexes */
	UNIQUE( username )
);


