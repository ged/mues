/*
 *	polymorphic.c - Polymorphic backend for MUES::StorableObject
 *	$Id: polymorphic.c,v 1.8 2002/05/28 17:39:33 deveiant Exp $
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
VALUE cMuesPolymorphicObject;


/*
 * become( other ) -> anObject
 * ---
 * Cause the receiver to switch itself with the specified +other+
 * MUES::PolymorphicObject. A SecurityError will be raised if $SAFE is greater
 * than 0 and only one of the objects is tainted, or if $SAFE is 4 or greater
 * and either of the objects are tainted. Returns the new receiver.
 */
static VALUE
polymorphic_become( self, other ) 
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

  // Check to make sure the other object is also polymorphic
  if (!rb_obj_is_kind_of( other, cMuesPolymorphicObject ))
	rb_raise(rb_eTypeError, "Cannot become a non-polymorphic object.",
			 rb_class2name(CLASS_OF(other)));

  // Make sure both objects are real objects (this shouldn't be a concern, as
  // they should all be PolymorphicObjects, but better safe than sorry).
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
Init_PolymorphicObject()
{
  VALUE mMues, cMuesObject;

  // Make sure the MUES module and MUES::Object are loaded.
  rb_require( "mues" );

  // Fetch the MUES module object and the Object class object to use in the
  // class definition.
  mMues = rb_const_get( rb_cObject, rb_intern("MUES") );
  cMuesObject = rb_const_get( mMues, rb_intern("Object") );

  // Define the new class and the #become method
  cMuesPolymorphicObject = rb_define_class_under( mMues, "PolymorphicObject", cMuesObject );
  rb_define_method( cMuesPolymorphicObject, "become", polymorphic_become, 1 );
}
