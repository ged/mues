/*
 *	polymorphic.c - Polymorphic backend for MUES::StorableObject
 *	$Id: storable.c,v 1.3 2002/05/28 16:47:50 deveiant Exp $
 *
 *	This module defines the part of the MUES::StorableObject class which allows
 *	it to exchange its identity with another StorableObject by calling its
 *	#become() method. It is based on PolymorphicObject, which in turn is based
 *	on code by Mathieu Bouchard <matju@cam.org>.
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

#include <ruby.h>

// Global class object
VALUE cStorableObject;


/*
 * become( other ) -> anObject
 * ---
 * Cause the receiver to switch itself with the specified +other+ object. The
 * +other+ object must also be a MUES::StorableObject. Swapping tainted and
 * untainted objects is forbidden if $SAFE is greater than 0, and if $SAFE is 4
 * or greater, #become will not work for tainted objects at all. Returns the new
 * receiver.
 */
static VALUE
storable_become( self, other ) 
	 VALUE self, other;
{
  long t[5];

  // Restrict what self can become in $SAFE >= 1.
  if ( rb_safe_level() >= 1 ) {
	if ( OBJ_TAINTED(self) && !OBJ_TAINTED(other) )
	  rb_raise( rb_eSecurityError, "Insecure: can't become untainted object." );
	if ( !OBJ_TAINTED(self) && OBJ_TAINTED(other) )
	  rb_raise( rb_eSecurityError, "Insecure: can't become tainted object." );

	// Objects can't polymorph at all in $SAFE >= 4.
	if ( rb_safe_level() >= 4 && (OBJ_TAINTED(self)||OBJ_TAINTED(other)) )
	  rb_raise( rb_eSecurityError, "Insecure: cannot polymorph tainted object." );
  }

  // Check to make sure the other object is also storable
  if (!rb_obj_is_kind_of( other, cStorableObject ))
	rb_raise(rb_eTypeError, "%s is not a storable object class",
			 rb_class2name(CLASS_OF(other)));

  // Make sure both objects are real objects (this shouldn't be a concern, as
  // they should all be StorableObjects, but better safe than sorry).
  if (IMMEDIATE_P(self))
	rb_raise(rb_eTypeError, "%s is not boxed",
			 rb_class2name(CLASS_OF(self)));
  if (IMMEDIATE_P(other))
	rb_raise(rb_eTypeError, "%s is not boxed",
			 rb_class2name(CLASS_OF(other)));

  // Exchange the ids of the two objects
  memcpy((long *)t    ,(long *)self ,5*sizeof(long));
  memcpy((long *)self ,(long *)other,5*sizeof(long));
  memcpy((long *)other,(long *)t    ,5*sizeof(long));
  return self;
}


/*
 *	Initializer
 */
void
Init_StorableObject()
{
  VALUE mMUES;

  // Load the Ruby half of the StorableObject class
  rb_require( "mues/StorableObject.rb" );

  // Now fetch the class object from the MUES module so we can add methods to
  // it.
  mMUES = rb_const_get( rb_cObject, rb_intern("MUES") );
  cStorableObject = rb_const_get( mMUES, rb_intern("StorableObject") );

  // Add the become method
  rb_define_method( cStorableObject, "become", storable_become, 1 );
}
