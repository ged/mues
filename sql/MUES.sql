/*
   MUES Database Schema (MySQL)
	$Id: MUES.sql,v 1.2 2001/05/14 12:34:22 deveiant Exp $
	Time-stamp: <31-Mar-2001 10:23:30 deveiant>

	Michael Granger <ged@FaerieMUD.org>
	Copyright (c) 1998-2001 The FaerieMUD Consortium. All rights reserved.

	This schema is free software. You may use, modify, and/or redistribute
	this software under the terms of the Perl Artistic License. (See
	http://language.perl.com/misc/Artistic.html)

	Load the whole schema with: '/lib/cpp MUES.sql | mysql -v'

 */

DROP DATABASE IF EXISTS mues;
CREATE DATABASE mues;
USE mues;

/* --- CHANGE THE PASSWORD IN THIS STATEMENT --- */
GRANT SELECT,INSERT,UPDATE,DELETE ON mues.*
	TO mues@localhost
	IDENTIFIED BY 'changeme';

#include "mues.player.sql"
#include "mues.denyallow.sql"
#include "mues.object.sql"


