/*
 *	polymorphic.c - A polymorphic object class for Ruby
 *	$Id: storable.c,v 1.1 2002/05/28 15:55:09 stillflame Exp $
 *
 *	This module defines a StorableObject class which is capable of exchanging its
 *	identity with another StorableObject by calling its #become() method. It is
 *	based on code by Mathieu Bouchard <matju@cam.org>.
 *
 *	Authors:
 *		Martin Chase <stillflame@FaerieMUD.org>
 *		Michael Granger <ged@FaerieMUD.org>
 *
 *	Copyright (c) 2002 The FaerieMUD Consortium. All rights reserved.
 *
 *	This library is free software; you can redistribute it and/or modify it
 *	under the terms of the GNU Lesser General Public License as published by the
 *	Free Software Foundation; either version 2.1 of the License, or (at your
 *	option) any later version.
 *
 *	This library is distributed in the hope that it will be useful, but WITHOUT
 *	ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 *	FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
 *	for more details.
 *
 *	You should have received a copy of the GNU Lesser General Public License
 *	along with this library (see the file LICENSE.TXT); if not, write to the
 *	Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *	02111-1307 USA.
 *
 */

#include <ruby.h>

// Global class object
VALUE cStorableObject;
VALUE cMUES;

/*
 * become( other ) -> anObject
 * ---
 * Cause the receiver to switch itself with the specified +other+ object. The
 * +other+ object must also be a StorableObject. Returns the new receiver.
 */
VALUE
polyobj_become( self, other ) 
	 VALUE self, other;
{
  long t[5];

  // Check to make sure the other object is also polymorphic
  if (!rb_obj_is_kind_of( other, cStorableObject ))
	rb_raise(rb_eTypeError, "%s is not a storable object class",
			 rb_class2name(CLASS_OF(other)));

  // ?
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

// MUES initializer
void Init_MUES() {
  cMUES = rb_define_module("MUES");
}

// StorableObject Initializer
void Init_StorableObject() {
  cStorableObject = rb_define_class_under(cMUES, "StorableObject", rb_cObject );
  rb_define_method( cStorableObject, "become", polyobj_become, 1 );
}
