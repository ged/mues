/*
   MUES Database Schema (MySQL)
	$Id: MUES.sql,v 1.1 2001/03/15 02:22:16 deveiant Exp $
	Time-stamp: <28-Jan-2001 02:39:57 deveiant>

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
GRANT ALL PRIVILEGES ON mues.*
	TO mues@localhost
	IDENTIFIED BY 'changeme';


#include "mues.player.sql"
#include "mues.ban.sql"

