/*
 *	mues.c - C extensions for MUES
 *	$Id: mues.c,v 1.1 2002/06/04 06:44:21 deveiant Exp $
 *
 *	This module loads various subordinate C extensions for MUES.
 *
 *	Authors:
 *		Martin Chase <stillflame@FaerieMUD.org>
 *		Michael Granger <ged@FaerieMUD.org>
 *
 *	Copyright (c) 2002 The FaerieMUD Consortium. All rights reserved.
 *
 *  This module is free software. You may use, modify, and/or redistribute this
 *  software under the terms of the Perl Artistic License. (See
 *  http://language.perl.com/misc/Artistic.html)
 *  
 *  THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
 *  WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
 *  MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 * 
 *
 */

#include "mues.h"

VALUE mues_mMUES;
VALUE mues_eVirtualMethodError;


/*
 * mues_debug( formatChar, ... )
 * --
 * Output a debugging message via sprintf if $VERBOSE is true.
 */
void
#ifdef HAVE_STDARG_PROTOTYPES
mues_debug(const char *fmt, ...)
#else
mues_debug(fmt, va_alist)
    const char *fmt;
    va_dcl
#endif
{
  char		buf[BUFSIZ], buf2[BUFSIZ];
  va_list	args;

  if (!RTEST(ruby_verbose)) return;

  snprintf( buf, BUFSIZ, "MUES Debug>>> %s", fmt );

  va_init_list( args, fmt );
  vsnprintf( buf2, BUFSIZ, buf, args );
  fputs( buf2, stderr );
  fputs( "\n", stderr );
  fflush( stderr );
  va_end( args );
}


/*
 * Initialize the C extensions
 */
void
Init_mues()
{
  // Load the Ruby code first to define most of the class heirarchy.
  rb_require("mues.rb");
  mues_debug( "Initializing the MUES C extensions." );

  // Fetch the MUES module and the VirtualMethodError class.
  mues_mMUES = rb_const_get( rb_cObject, rb_intern("MUES") );
  mues_eVirtualMethodError = rb_const_get(mues_mMUES, rb_intern( "VirtualMethodError" ));

  // Initialize the extensions -- Object must come before Polymorphic so the
  // MUES::Object constant is loaded.
  Init_Mues_Object();
  Init_Mues_PolymorphicObject();
}
