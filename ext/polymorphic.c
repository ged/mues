/*
 *	polymorphic.c - Polymorphic backend for MUES::StorableObject
 *	$Id: polymorphic.c,v 1.14 2003/04/19 06:54:45 deveiant Exp $
 *
 *	This module defines the MUES::PolymorphicObject class which is a derivative
 *	of MUES::Object that allows it to exchange its identity with another
 *	PolymorphicObject via its #polymorph() method. It is based on code suggested
 *	by Mathieu Bouchard <matju@cam.org>.
 *
 *	Authors:
 *		Martin Chase <stillflame@FaerieMUD.org>
 *		Michael Granger <ged@FaerieMUD.org>
 *
 *	Copyright (c) 2002, 2003 The FaerieMUD Consortium. All rights reserved.
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

VALUE mues_cMuesPolymorphicObject;

/*
 * polymorph( other ) -> anObject
 * ---
 * Cause the receiver to switch itself with the specified +other+
 * MUES::PolymorphicObject. A SecurityError will be raised if $SAFE is greater
 * than 0 and only one of the objects is tainted, or if $SAFE is 4 or greater
 * and either of the objects are tainted. Returns the new receiver.
 */
static VALUE
mues_polymorphic_polymorph( self, other ) 
	 VALUE self, other;
{
	long t[5];

	// Restrict what self can polymorph in $SAFE >= 1.
	if ( rb_safe_level() >= 1 ) {
		if ( OBJ_TAINTED(self) && !OBJ_TAINTED(other) )
			rb_raise( rb_eSecurityError, "Insecure: can't polymorph into an untainted object." );
		if ( !OBJ_TAINTED(self) && OBJ_TAINTED(other) )
			rb_raise( rb_eSecurityError, "Insecure: can't polymorph into a tainted object." );

		// Objects can't polymorph at all in $SAFE >= 4.
		if ( rb_safe_level() >= 4 && (OBJ_TAINTED( self ) || OBJ_TAINTED( other )) )
			rb_raise( rb_eSecurityError, "Insecure: cannot polymorph a tainted object." );
	}

	// Check to make sure the other object is also polymorphic
	if ( !rb_obj_is_kind_of(other, mues_cMuesPolymorphicObject) )
		rb_raise( rb_eTypeError, "Cannot polymorph a non-polymorphic object.",
				  rb_class2name(CLASS_OF( other )) );

	// Make sure both objects are real objects (this shouldn't be a concern, as
	// they should all be PolymorphicObjects, but better safe than sorry).
	if ( IMMEDIATE_P(self) )
		rb_raise( rb_eTypeError, "%s is not boxed",
				  rb_class2name(CLASS_OF( self )) );
	if ( IMMEDIATE_P(other) )
		rb_raise( rb_eTypeError, "%s is not boxed",
				  rb_class2name(CLASS_OF( other )) );

	// Exchange the ids of the two objects
	memcpy( (long *)t    , (long *)self , 5 * sizeof(long) );
	memcpy( (long *)self , (long *)other, 5 * sizeof(long) );
	memcpy( (long *)other, (long *)t    , 5 * sizeof(long) );

	return self;
}


/*
 *	Initializer
 */
void
Init_Mues_PolymorphicObject()
{
	static char
		rcsid[]		= "$Id: polymorphic.c,v 1.14 2003/04/19 06:54:45 deveiant Exp $",
		revision[]	= "$Revision: 1.14 $";

	VALUE vstr		= rb_str_new( (revision+11), strlen(revision) - 11 - 2 );
	VALUE rcsstr	= rb_str_new( rcsid, strlen(rcsid) );

	DebugMsg(( "Initializing MUES::PolymorphicObject C extension." ));

#if FOR_RDOC_PARSER
	mues_mMUES = rb_define_module( "MUES" );
#endif

	// Define the new class, the Version and Rcsid constants, and the #polymorph
	// method
	mues_cMuesPolymorphicObject = rb_define_class_under( mues_mMUES, "PolymorphicObject", mues_cMuesObject );
	rb_define_const( mues_cMuesPolymorphicObject, "Rcsid", rcsstr );
	rb_define_const( mues_cMuesPolymorphicObject, "Version", vstr );
	rb_define_method( mues_cMuesPolymorphicObject, "polymorph", mues_polymorphic_polymorph, 1 );
}
