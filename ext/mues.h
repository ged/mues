/*
 *	mues.h - header file for MUES C extensions
 *	$Id: mues.h,v 1.1 2002/06/04 06:44:21 deveiant Exp $
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

#ifndef _MUES_H
#define _MUES_H 1

/* Rubyish include */
#include <ruby.h>
#include <node.h>
#include <st.h>			// Hash functions
#include <intern.h>		// For rb_ivar_defined() and friends

/* System includes */
#include <stdio.h>

// Debugging function
#ifdef HAVE_STDARG_PROTOTYPES
#include <stdarg.h>
#define va_init_list(a,b) va_start(a,b)
void mues_debug(const char *fmt, ...);
#else
#include <varargs.h>
#define va_init_list(a,b) va_start(a)
void mues_debug(fmt, va_alist);
#endif

/*
 * Globals
 */

// MUES module
extern VALUE mues_mMUES;

// Classes
extern VALUE mues_cMuesObject;				// MUES::Object
extern VALUE mues_cMuesPolymorphicObject;	// MUES::PolymorphicObject

// Exception classes
extern VALUE mues_eVirtualMethodError;


// Prototypes for external symbols
extern void Init_mues						_(());
extern void Init_Mues_PolymorphicObject		_(());
extern void Init_Mues_Object				_(());


#endif /* _MUES_H */

