/*
 *	monadic.c - A monadic object class for Ruby
 *	$Id: polymorphic.c,v 1.2 2002/02/12 00:39:39 deveiant Exp $
 *
 *	Author: Michael Granger <ged@FaerieMUD.org>
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
VALUE cMonadicObject;

// MonadicObject#become( otherObj )
VALUE mo_become( VALUE self, VALUE other ) {
  long t[5];

  // Check to make sure the other object is also monadic
  if (!rb_obj_is_kind_of( other, cMonadicObject ))
	rb_raise(rb_eTypeError, "%s is not a monadic object class",
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

// Initializer
void Init_MonadicObject() {
  cMonadicObject = rb_define_class( "MonadicObject", rb_cObject );
  rb_define_protected_method( cMonadicObject, "become", mo_become, 1 );
}

