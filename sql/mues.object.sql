/*
   MUES Object Table Schema (MySQL)
	$Id: mues.object.sql,v 1.2 2001/05/14 12:34:43 deveiant Exp $
	Time-stamp: <31-Mar-2001 10:24:02 deveiant>

	Michael Granger <ged@FaerieMUD.org>
	Copyright (c) 1998-2001 The FaerieMUD Consortium. All rights reserved.

	This schema is free software. You may use, modify, and/or redistribute
	this software under the terms of the Perl Artistic License. (See
	http://language.perl.com/misc/Artistic.html)

 */

/* The frozen object table */
DROP TABLE IF EXISTS object;
CREATE TABLE object (
	
	/* Tableadapter fields */
	id					INT				UNSIGNED auto_increment PRIMARY KEY,
	ts					TIMESTAMP(12),
	
	/* Data fields */
	muesid				VARCHAR(200)	NOT NULL,
	data				MEDIUMBLOB

);


DROP TABLE IF EXISTS objectlock;
CREATE TABLE objectlock (
	objectId			INT				UNSIGNED NOT NULL REFERENCES object(id)
);


