/*
 *	object.c - C extensions for the MUES::Object class
 *	$Id: object.c,v 1.4 2002/10/13 23:19:00 deveiant Exp $
 *
 *	This file contains extensions for the MUES::Object base class.
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


VALUE mues_cMuesObject;

/* 
 * mues_dummy_method( VALUE self, int argc, VALUE *argv )
 * --
 * The default method body for abstract methods declared by the
 * <tt>abstract</tt> function. Raises a MUES::VirtualMethodError.
 *
 */
VALUE
mues_dummy_method(self, argc, argv)
	 VALUE self, *argv;
	 int argc;
{
	rb_raise( mues_eVirtualMethodError, "Unimplemented virtual method" );

	// Not reached
	return Qnil;
}


/* 
 * abstract( VALUE self, int argc, VALUE *argv )
 * --
 * Declare a method as abstract or unimplemented in the current namespace:
 *   abstract :myVirtualMethod, :myOtherVirtualMethod
 * Calling a method declared in this fashion will result in a
 * VirtualMethodError being raised.
 *
 */
VALUE
mues_abstract( argc, argv, self )
	 VALUE self, *argv;
	 int argc; 
{
	int i;
	VALUE absClass;


	// Check to make sure the abstract method is being declared in an abstract
	// class
	absClass = rb_const_get(mues_mMUES, rb_intern( "AbstractClass" ));
	mues_debug( "Checking <%s> class to make sure it implements AbstractClass",
				rb_class2name(self) );
	if( rb_mod_include_p(self, absClass) == Qfalse )
		rb_raise( rb_eScriptError, "Cannot declare abstract methods for a concrete class" );

	mues_debug( "Adding %d virtual methods.", argc );

	// Iterate over each symbol, adding an abstract method for each one.
	for(i = 0; i < argc; i++) {
		mues_debug( "...adding abstract method '%s'", rb_id2name(SYM2ID( argv[i] )) );
		rb_define_method( self, rb_id2name(SYM2ID( argv[i] )), mues_dummy_method, -1 );
	}

	return Qtrue;
}


/* 
 * abstract_arity( VALUE self, int argc, VALUE *argv )
 * --
 * Declare a method as abstract or unimplemented in the current namespace, with
 * checks for a given arity:
 *   abstract_arity :myVirtualMethod, 5
 * Calling a method declared in this fashion that has not been overridden will
 * result in a MUES::VirtualMethodError being raised. Overriding the abstract
 * method with a method which doesn't have the specified arity or greater will
 * cause a MUES::VirtualMethodError to be raised when the overriding class's
 * initializer is called.
 */
VALUE
mues_abstract_arity(argc, argv, self)
	 VALUE self, *argv;
	 int argc;
{
	VALUE symbol, arity, virtualMethodTable;

	if ( argc != 2 )
		rb_raise( rb_eArgError, "wrong number of arguments (%d for 2)", argc );

	symbol = *(argv);
	arity  = *(argv+1);

	mues_abstract( 1, (VALUE *)&symbol, self );
  
	// If the class already has a virtual method table, fetch it; otherwise make a
	// new one.
	if ( RTEST(rb_ivar_defined( self, rb_intern("@virtualMethods") )) )
		virtualMethodTable = rb_iv_get( self, "@virtualMethods" );
	else
		virtualMethodTable = rb_hash_new();

	// Now set the tuple for this method and set it back in the class
	rb_hash_aset( virtualMethodTable, symbol, arity );
	mues_debug( "Virtual method '%s' required arity set to %d in virtual methods table of %s class",
				rb_id2name(SYM2ID( symbol )),
				FIX2INT(arity),
				rb_class2name(self) );

	rb_iv_set( self, "@virtualMethods", virtualMethodTable );
	if ( !RTEST(rb_ivar_defined( self, rb_intern("@virtualMethods") )) )
		rb_raise( rb_eScriptError, "Failed to set @virtualMethods on %s class.", rb_class2name(self) );

	return Qtrue;
}



/* 
 * mues_check_definition( VALUE meth_arity, VALUE klass )
 * --
 * Iterator function: Check the method and arity requirement specified by the
 * <tt>spec</tt> tuple (method symbol => target arity) for the specified
 * <tt>klass</tt>.
 */
VALUE
mues_check_definition(spec, klass)
	 VALUE spec, klass;
{
	int targetArity, actualArity;
	VALUE unboundMethod, methodSym[1];

	methodSym[0]	= rb_ary_entry(spec, 0);
	targetArity	= FIX2INT( rb_ary_entry(spec, 1) );

	mues_debug( "Checking method %s of %s for target arity %d",
				rb_id2name(SYM2ID( methodSym[0] )),
				rb_class2name(klass),
				targetArity );

	// Get the unbound method from the tested class
	unboundMethod = rb_funcall( klass, rb_intern("instance_method"), 1, methodSym );
	mues_debug( "   calling unboundMethod.arity()" );
	actualArity   = NUM2INT( rb_funcall(unboundMethod, rb_intern("arity"), 0, 0) );

	mues_debug( "   actual arity for %s is %d", rb_id2name(SYM2ID( methodSym )), actualArity );

	// Normalize optional-argument arity
	if ( actualArity < 0 ) actualArity = abs( actualArity + 1 );

	// Test actual against target
	if ( targetArity > actualArity )
		mues_debug( "...%d > %d: raising an error", targetArity, actualArity );
	rb_raise( mues_eVirtualMethodError,
			  "Insufficient arity for overridden method");

	return Qtrue;
}


/* 
 * mues_check_virtual_methods( VALUE self )
 * --
 * Check for any unoverridden virtual methods defined by the specified
 * <tt>klass</tt>, raising a MUES::VirtualMethodError for any which are not
 * defined.
 */
VALUE
mues_check_virtual_methods(self)
     VALUE self;
{
	VALUE virtualMethods, klass;
  
	klass = CLASS_OF( self );
	mues_debug( "Checking virtual methods for %s class (id = %d)",
				rb_class2name(klass),
				(int)klass );
  
	while( klass && klass != mues_cMuesObject ) {
		mues_debug( "  Inspecting class %s", rb_class2name(klass) );

		// If the class in question has a virtual method table, test each of them
		if ( RTEST(rb_ivar_defined( klass, rb_intern("@virtualMethods") )) ) {
			virtualMethods = rb_iv_get( klass, "@virtualMethods" );

			if ( TYPE(virtualMethods) == T_HASH ) {
				mues_debug( "  Found %d hash entries in @virtualMethods",
							RHASH(virtualMethods)->tbl->num_entries );
				rb_iterate( rb_each, virtualMethods, mues_check_definition, (VALUE)klass );
			}
		} else {
			mues_debug( "  Skipping: No virtual methods table for %s class.", rb_class2name(klass) );
		}

		klass = RCLASS(klass)->super;
	}

	return Qtrue;
}

void
Init_Mues_Object()
{
#if FOR_RDOC_PARSER
	mues_mMUES = rb_define_module( "MUES" );
	mues_cMuesObject = rb_define_class_under( mues_mMUES, "Object", rb_cObject );
#endif

	mues_debug( "Initializing MUES::Object C extensions." );
	mues_cMuesObject = rb_const_get( mues_mMUES, rb_intern("Object") );

	// Add abstract() and abstract_arity() to the Module class as private methods
	rb_define_private_method( rb_cModule, "abstract", mues_abstract, -1 );
	rb_define_private_method( rb_cModule, "abstract_arity", mues_abstract_arity, -1 );

	rb_define_method( mues_cMuesObject, "checkVirtualMethods", mues_check_virtual_methods, 0 );
}
