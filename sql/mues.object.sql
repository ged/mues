/*
   MUES Object Table Schema (MySQL)
	$Id: mues.object.sql,v 1.1 2001/03/15 02:22:16 deveiant Exp $
	Time-stamp: <28-Jan-2001 03:59:28 deveiant>

	Michael Granger <ged@FaerieMUD.org>
	Copyright (c) 1998-2001 The FaerieMUD Consortium. All rights reserved.

	This schema is free software. You may use, modify, and/or redistribute
	this software under the terms of the Perl Artistic License. (See
	http://language.perl.com/misc/Artistic.html)

 */

/* The Player table */
DROP TABLE IF EXISTS object;
CREATE TABLE object (
	
	/* Tableadapter fields */
	id					INT				UNSIGNED auto_increment PRIMARY KEY,
	ts					TIMESTAMP(12),
	
	/* Data fields */
	data				MEDIUMBLOB

);


DROP TABLE IF EXISTS objectlock;
CREATE TABLE objectlock (
	objectId			INT				UNSIGNED NOT NULL REFERENCES object(id)
);


