#!/usr/bin/ruby -w

require 'md5'

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/Namespace'
require 'mues/Player'
require 'mues/ObjectStore'

### Adapter tests
module MUES
	class TestObject < MUES::Object
		attr_reader :args

		def initialize( *args )
			super()
			@args = args
		end
	end

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

	### Test the objectstore class itself
	class TestObjectStore < RUNIT::TestCase

		def setup
			super
		end

		def teardown
			super
		end

		def test_LoadAdapters
			assert MUES::ObjectStore._loadAdapters
		end

		def test_HasAdapter
			assert MUES::ObjectStore._hasAdapter?( "Dummy" ) 
		end

		def test_GetAdapter
			a = MUES::ObjectStore._getAdapter( "Dummy", "test", "host", "user", "password" )
			assert_instance_of MUES::ObjectStore::DummyAdapter, a
			assert_equals( "test", a.db )
			assert_equals( "host", a.host )
			assert_equals( "user", a.user )
			assert_equals( "password", a.password )
		end
	end

	### Base adapter test class
	class BaseObjectStoreAdapter < RUNIT::TestCase

		@@TestData = %w{a few test words}
		@@PlayerTestData = {
			'username'		=> 'ged',
			'cryptedPass'	=> '1c7bf49fb32388100dff7464abf9c588',
			'realname'		=> 'Michael Granger',
			'emailAddress'	=> 'ged@FaerieMUD.org',
			'lastLogin'		=> '2001-01-01 00:00:00',
			'lastHost'		=> 'galendril.FaerieMUD.org',

			'dateCreated'	=> '2001-01-01 00:00:00',
			'age'			=> 16,

			'role'			=> Player::Role::ADMIN,
			'preferences'	=> { 'prompt' => '%h [%c]>'},
			'characters'	=> %w{ged taliesin gond},
		}
		@@ObjectStore = nil
		@@Id = nil

		def setup
			@@ObjectStore = ObjectStore.new( 'Dummy', 'test' )
		end

		def teardown
			@@ObjectStore = nil
		end

		def test_00New
			assert_instance_of( MUES::ObjectStore, @@ObjectStore )
		end

		def test_01StoreObject
			obj = TestObject.new(*@@TestData)

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
			obj = IntelligentTestObject.new(*@@TestData)

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

		def test_05StorePlayer
			pl = Player.new( @@PlayerTestData )
			assert_no_exception {
				@@ObjectStore.storePlayer( pl )
			}
		end

		def test_06FetchPlayer
			player = nil
			assert_no_exception {
				player = @@ObjectStore.fetchPlayer( @@PlayerTestData['username'] )
			}
			@@PlayerTestData.each_key {|k|
				assert_equals( @@PlayerTestData[k], player.dbInfo[k] )
			}
		end
	end

	### Test suite for Berkeley DB adapter
	class TestObjectStoreBdbAdapter < BaseObjectStoreAdapter
		def setup
			@@ObjectStore = ObjectStore.new( 'Bdb', 'test' )
		end
	end

	### :FIXME: Segfaults for some reason
	### Test suite for Mysql DB adapter
	class TestObjectStoreMysqlAdapter < BaseObjectStoreAdapter
		def setup
			@@ObjectStore = ObjectStore.new( 'Mysql', 'mues', 'localhost', 'deveiant', '3l3g4nt' )
		end
	end
end


if $0 == __FILE__

	### Define a suite for all tests in this collection
	class TestAll
		def TestAll.suite
			suite = RUNIT::TestSuite.new
			ObjectSpace.each_object( Class ) {|klass|
				next unless klass < RUNIT::TestCase && klass.name =~ /^MUES::Test/
				suite.add_test( klass.suite )
			}
			suite
		end
	end

	### Run all the tests
	RUNIT::CUI::TestRunner.run( TestAll.suite )
end

