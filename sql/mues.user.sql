/*

   MUES User Table Schema (MySQL)
	$Id: mues.user.sql,v 1.4 2001/09/26 13:35:45 deveiant Exp $
	Time-stamp: <20-Sep-2001 17:05:08 deveiant>

	Michael Granger <ged@FaerieMUD.org>
	Copyright (c) 1998-2001 The FaerieMUD Consortium. All rights reserved.

	This schema is free software. You may use, modify, and/or redistribute
	this software under the terms of the Perl Artistic License. (See
	http://language.perl.com/misc/Artistic.html)

 */

/* The User table */
DROP TABLE IF EXISTS muesuser;
CREATE TABLE muesuser (
	
	/* Tableadapter fields */
	id					INT				UNSIGNED auto_increment PRIMARY KEY,
	ts					TIMESTAMP(12),
	
	/* Data fields */
	userVersion			VARCHAR(10)		NOT NULL,
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

	/* Indexes */
	UNIQUE( username )
);


