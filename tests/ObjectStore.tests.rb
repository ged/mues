#!/usr/bin/ruby -w

require 'md5'

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/Namespace'
require 'mues/User'
require 'mues/ObjectStore'
require 'mues/Config'

### Adapter tests
module MUES

	### An object class for testing storage and retrieval
	class TestObject < MUES::Object
		attr_reader :args

		def initialize( *args )
			super()
			@args = args
		end
	end

	### A more intelligent version of the test object
	class IntelligentTestObject < TestObject
		attr_reader :checksum

		def initialize( *args )
			super( *args )
			@checksum = nil
		end

		def lull
			@checksum = MD5.new( @args.collect {|a| a.to_s}.join(':') ).hexdigest
		end

		def awaken
			@checksum = nil
		end
	end

	# Subclass of ObjectStore: exposes protected methods as public so we can
	# test them.
	class TestingObjectStore < ObjectStore
		public
		class << self
			def loadAdapters; ObjectStore::_loadAdapters; end
		end
	end

	### Test the objectstore class itself
	class ObjectStoreTestCase < RUNIT::TestCase

		@config = nil

		def setup
			@config = MUES::Config.new
			@config['objectstore'] = MUES::Config::Section::new( 'objectstore' )
			@config['objectstore']['driver'] = 'Dummy'
			@config['objectstore']['directory'] = 'testobjectstore'
			@config['rootdir'] = '.'

			super
		end

		def teardown
			super
		end

		def test_LoadAdapters
			assert TestingObjectStore::loadAdapters
		end

		def test_HasAdapter
			assert TestingObjectStore::hasAdapter?( "Dummy" ) 
		end

		def test_GetAdapter
			a = TestingObjectStore::getAdapter( @config )
			assert_instance_of MUES::ObjectStore::DummyAdapter, a
		end
	end

	### Base adapter test class
	class BaseObjectStoreAdapter < RUNIT::TestCase

		@@TestData = %w{a few test words}
		@@UserTestData = MUES::User::DefaultDbInfo
		@@ObjectStore = nil
		@@Id = nil

		def setup
			config = MUES::Config::new
			config['objectstore'] = MUES::Config::Section::new( 'objectstore' )
			config['objectstore']['driver'] = 'Dummy'
			config['objectstore']['directory'] = 'testobjectstore'
			config['rootdir'] = '.'

			@@ObjectStore = ObjectStore::new( config )
		end

		def teardown
			@@ObjectStore = nil
		end

		def test_00New
			assert_instance_of( MUES::ObjectStore, @@ObjectStore )
		end

		def test_01StoreObject
			obj = TestObject::new(*@@TestData)

			assert_no_exception {
				@@Id = @@ObjectStore.storeObjects( obj )[0]
			}
			assert_equals( "MUES::TestObject:#{obj.muesid}", @@Id )
		end

		def test_02FetchObject
			obj = nil
			assert_no_exception {
				obj = @@ObjectStore.fetchObjects( @@Id )[0]
			}
			assert_equals( @@Id, "MUES::TestObject:#{obj.muesid}" )
			assert_equals( @@TestData, obj.args )
		end

		def test_03StoreIntelligentObject
			obj = IntelligentTestObject::new(*@@TestData)

			assert_no_exception {
				@@Id = @@ObjectStore.storeObjects( obj )[0]
			}
			assert_equals( "MUES::IntelligentTestObject:#{obj.muesid}", @@Id )
			assert_not_nil( obj.checksum )
		end

		def test_04FetchIntelligentObject
			obj = nil
			assert_no_exception {
				obj = @@ObjectStore.fetchObjects( @@Id )[0]
			}
			assert_equals( @@Id, "MUES::IntelligentTestObject:#{obj.muesid}" )
			assert_equals( @@TestData, obj.args )
			assert_nil( obj.checksum )
		end

		def test_05CreateUser
			pl = nil
			assert_no_exception {
				pl = @@ObjectStore.createUser( @@UserTestData['username'] )
			}
			assert_instance_of( MUES::User, pl )
		end

		def test_06CreateUserWithBlock
			assert_no_exception {
				@@ObjectStore.createUser( @@UserTestData['username'] ) {|pl|
					pl.password = @@UserTestData['password']
				}
			}
		end

		def test_07FetchUser
			user = nil
			assert_no_exception {
				user = @@ObjectStore.fetchUser( @@UserTestData['username'] )
			}
			@@UserTestData.each_key {|k|
				assert_equals( @@UserTestData[k], user.dbInfo[k] )
			}
		end

		def test_08ListUsers
			list = nil
			assert_no_exception {
				list = @@ObjectStore.listUsers
			}
			assert( list.find {|u| u == @@UserTestData['username']} )
		end

		def test_09DeleteUser
			assert_no_exception {
				@@ObjectStore.deleteUser(@@UserTestData['username'])
			}
		end
	end

	### Test suite for Berkeley DB adapter
	class ObjectStoreBdbAdapterTestCase < BaseObjectStoreAdapter
		def setup
			@@ObjectStore = ObjectStore::new( 'Bdb', 'test' )
		end
	end

	### :FIXME: Segfaults for some reason
	### Test suite for Mysql DB adapter
	class ObjectStoreMysqlAdapterTestCase < BaseObjectStoreAdapter
		def setup
			@@ObjectStore = ObjectStore::new( 'Mysql', 'mues', 'localhost', 'deveiant', '3l3g4nt' )
		end
	end
end


if $0 == __FILE__

	### Define a suite for all tests in this collection
	class TestAll
		def TestAll.suite
			suite = RUNIT::TestSuite.new
			ObjectSpace.each_object( Class ) {|klass|
				next unless klass < RUNIT::TestCase
				suite.add_test( klass.suite )
			}
			suite
		end
	end

	### Run all the tests
	RUNIT::CUI::TestRunner.run( TestAll::suite )
end

