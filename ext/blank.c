/*
 *	blank.c - The BlankObject class.
 *	$Id: blank.c,v 1.1 2003/04/19 06:50:16 deveiant Exp $
 *
 *	This module defines the MUES::BlankObject class, which is an object class
 *	which exists outside of the regular Ruby class heirarchy, and contains only
 *	the barest minimum of functionality. It is useful for setting up a
 *	restrictive execution environment for untrusted code. The MUES::ClassLibrary
 *	uses this class as the default base class for metaclass libraries.
 *
 *	This code is based on the "KernellessObject" in the RubyTreasures
 *	distribution by Paul Brannan. The license for that module is:
 *
 *	  Ruby Treasures 0.4
 *	  Copyright (C) 2002, 2003 Paul Brannan <paul@atdesk.com>
 *
 *	  You may distribute this software under the same terms as Ruby (see the
 *	  file COPYING that was distributed with this library).
 *
 *	Authors:
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

VALUE mues_cMuesBlankObject;

typedef struct {
	double	capability;
} mues_BLANK;


static mues_BLANK *
mues_blank_alloc()
{
	mues_BLANK *ptr = ALLOC( mues_BLANK );
	ptr->capability = 0;
	return ptr;
}


/*
 * GC Mark function
 */
/* static void */
/* mues_blank_gc_mark( ptr ) */
/* 	 mues_BLANK *ptr; */
/* { */
	
/* } */


/*
 * GC Free function
 */
static void
mues_blank_gc_free( ptr )
	 mues_BLANK *ptr;
{
	if ( ptr ) {
		xfree( ptr );
		ptr = NULL;
	}
	else {
		DebugMsg(( "Not freeing uninitialized mues_BLANK" ));
	}
}


/*
 * Object validity checker. Returns the data pointer.
 */
static mues_BLANK *
check_blank( self )
	 VALUE	self;
{
	DebugMsg(( "Checking a MUES::BlankObject object (%d).", self ));
	Check_Type( self, T_DATA );

    if ( !rb_obj_is_instance_of(self, mues_cMuesBlankObject) ) {
		rb_raise( rb_eTypeError, "wrong argument type %s (expected MUES::BlankObject)",
				  rb_class2name(CLASS_OF( self )) );
    }
	
	return DATA_PTR( self );
}


/*
 * Fetch the data pointer and check it for sanity.
 */
static mues_BLANK *
get_blank( self )
	 VALUE self;
{
	mues_BLANK *ptr = check_blank( self );
	if ( !ptr ) rb_raise( rb_eRuntimeError, "uninitialized Blank" );
	return ptr;
}



/* --------------------------------------------------
 * Class Methods
 * -------------------------------------------------- */

/*
 * allocate()
 * --
 * Allocate a new MUES::BlankObject object.
 */
static VALUE
mues_blank_s_alloc( klass )
{
	DebugMsg(( "Wrapping an uninitialized MUES::BlankObject pointer." ));
	return Data_Wrap_Struct( klass, 0, mues_blank_gc_free, 0 );
}



/* --------------------------------------------------
 * Instance Methods
 * -------------------------------------------------- */

/*
 * initialize()
 * --
 * Initialize a new BlankObject.
 */
static VALUE
mues_blank_init( self )
	 VALUE self;
{
	mues_BLANK	*ptr;

	DATA_PTR(self) = ptr = mues_blank_alloc();
	return self;
}


/*
 * capability
 * --
 * Returns the capability mask of the object as a Numeric.
 */
static VALUE
mues_blank_capability( self )
	 VALUE self;
{
	mues_BLANK	*ptr = get_blank(self);
	return LONG2NUM( ptr->capability );
}


/*
 * capability=( newvalue )
 * --
 * Set the capability mask of the object. Fails if called from $SAFE >= 3.
 */
static VALUE
mues_blank_capability_eq( self, newval )
	 VALUE self, newval;
{
	mues_BLANK *ptr = get_blank(self);

	rb_secure(3);
	ptr->capability = FIX2LONG( newval );

	return LONG2FIX(ptr->capability);
}


void
Init_Mues_BlankObject()
{
	ID id;

	DebugMsg(( "Initializing MUES::BlankObject C extension." ))

#if FOR_RDOC_PARSER
	mues_mMUES = rb_define_module( "MUES" );
#endif

	/* Set up the BlankObject class as a class outside the Ruby hierarchy. */
	id = rb_intern( "BlankObject" );
	mues_cMuesBlankObject = rb_class_boot(0);
	rb_name_class( mues_cMuesBlankObject, id );
	
	//metaclass = rb_make_metaclass( mues_cMuesBlankObject, mues_cMuesStorableObject );
	rb_define_alloc_func( mues_cMuesBlankObject, mues_blank_s_alloc );
	rb_define_singleton_method( mues_cMuesBlankObject, "initialize", mues_blank_init, 0 );

	rb_define_method( mues_cMuesBlankObject, "capability", mues_blank_capability, 0 );
	rb_define_method( mues_cMuesBlankObject, "capability=", mues_blank_capability_eq, 1 );
}
