#!/usr/bin/ruby -w

unless defined? MUES && defined? MUES::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )

	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/ext" unless
		$LOAD_PATH.include?( "#{basedir}/ext" )
	$LOAD_PATH.unshift "#{basedir}/tests" unless
		$LOAD_PATH.include?( "#{basedir}/tests" )

	require 'muestestcase'
end

require 'mues/classlibrary'
require 'mues/metaclasses'

### Log tests
module MUES
	class ClassLibraryTestCase < MUES::TestCase

		TestData = {
			:libname	=> "testLibrary",
			:classname	=> "TestClass",
		}


		#############################################################
		###	T E S T S
		#############################################################

		def test_00_Class
			printTestHeader "ClassLibrary: Class"
			assert_instance_of Class, MUES::ClassLibrary
		end

		def test_01_Instantiation
			printTestHeader "ClassLibrary: Instantiation"
			rval = nil

			assert_nothing_raised {
				rval = MUES::ClassLibrary::new( TestData[:libname] )
			}
			assert_instance_of MUES::ClassLibrary, rval

			addSetupBlock {
				@clib = MUES::ClassLibrary::new( TestData[:libname] )
			}
			addTeardownBlock {
				@clib = nil
			}
		end

		def test_02_Name
			printTestHeader "ClassLibrary: Instantiation"
			assert_equal TestData[:libname], @clib.name
		end

		def test_10_CreateClass
			printTestHeader "ClassLibrary: Instantiation"
			rval = nil

			assert_nothing_raised {
				rval = @clib.createClass( TestData[:classname] )
			}
			assert_instance_of MUES::Metaclass::Class, rval
		end

	end
end


