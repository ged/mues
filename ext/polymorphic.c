/* @(#)monadic.c
 */

#include <ruby.h>

VALUE cMonadicObject;

VALUE mo_become( VALUE self, VALUE other ) {
  long t[5];

  if (!rb_obj_is_kind_of( other, cMonadicObject ))
	rb_raise(rb_eTypeError, "%s is not a monadic object class",
			 rb_class2name(CLASS_OF(other)));
  if (IMMEDIATE_P(self))
	rb_raise(rb_eTypeError, "%s is not boxed",
			 rb_class2name(CLASS_OF(self)));
  if (IMMEDIATE_P(other))
	rb_raise(rb_eTypeError, "%s is not boxed",
			 rb_class2name(CLASS_OF(other)));

  memcpy((long *)t    ,(long *)self ,5*sizeof(long));
  memcpy((long *)self ,(long *)other,5*sizeof(long));
  memcpy((long *)other,(long *)t    ,5*sizeof(long));
  return self;
}

extern void Init_MonadicObject() {
  cMonadicObject = rb_define_class( "MonadicObject", rb_cObject );
  rb_define_protected_method( cMonadicObject, "become", mo_become, 1 );
}

