#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/Config.rb'


module MUES
	class ConfigTestCase < MUES::TestCase

		@config = nil

		@@MethodTests = {
			# Method chain								# Expected value
			[ :general, :server_name ]					=> "Experimental MUD",
			[ :general, :server_admin ]					=> "MUES Admin <muesadmin@localhost>",

			[ :engine, :debug_level ]					=> "0",
		}

		@@AttributeTests = {
			[ [:engine, :backend], "class" ]			=> "BerkeleyDB",
			[ [:engine, :garbagecollector], "class"]	=> "Simple",
		}

		def set_up
			super
			@config = MUES::Config::new TestConfig::Source
		end

		def tear_down
			@config = nil
			super
		end


		def test_MethodChain
			@@MethodTests.each {|chain,expectedResult|
				lastRes = @config
				chain.each {|sym|
					assert_nothing_raised { lastRes = lastRes.send( sym ) }
				}

				assert_instance_of MUES::Config::Item, lastRes
				assert_equal expectedResult, lastRes.to_s
			}
		end

	end

end


module TestConfig
	Source = <<'END'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE muesconfig SYSTEM "muesconfig.dtd">

<muesconfig version="1.1">

  <!-- General server configuration -->
  <general>
	<server-name>Experimental MUD</server-name>
	<server-description>An experimental MUES server.</server-description>
	<server-admin>MUES Admin &lt;muesadmin@localhost&gt;</server-admin>
	<root-dir>server</root-dir>
  </general>


  <!-- Engine (core) configuration -->
  <engine>

	<!-- Number of floating-point seconds between tick events -->
	<tick-length>1.0</tick-length>
	<exception-stack-size>10</exception-stack-size>
	<debug-level>0</debug-level>

	<!-- Engine objectstore config -->
	<objectstore>
	  <backend class="BerkeleyDB"></backend>
	  <garbagecollector class="Simple">
		<param name="trash_rate">50</param>
	  </garbagecollector>
	</objectstore>

	<!-- Listener objects -->
	<listeners>

	  <!-- Telnet listener: MUES::TelnetOutputFilter -->
	  <listener name="telnet">
		<filter-class>MUES::TelnetOutputFilter</filter-class>
		<bind-port>23</bind-port>
		<bind-address>0.0.0.0</bind-address>
		<use-wrapper>true</use-wrapper>
	  </listener>

	  <!-- Client listener: MUES::ClientOutputFilter (BEEP) -->
	  <listener name="client">
		<filter-class>MUES::ClientOutputFilter</filter-class>
		<bind-port>2424</bind-port>
		<bind-address>0.0.0.0</bind-address>
		<use-wrapper>false</use-wrapper>
	  </listener>
	</listeners>
  </engine>


  <!-- Logging system configuration (Log4R format) -->
  <logging>
	<log4r_config>

	  <!-- Log4R pre-config -->
	  <pre_config>
		<parameters>
		  <logpath>server/log</logpath>
		  <mypattern>%l [%d] %m</mypattern>
		</parameters>
	  </pre_config>

	  <!-- Log Outputters -->
	  <outputter type="IOOutputter" name="console" fdno="2" />
	  <outputter type="FileOutputter" name="serverlog"
		filename="#{logpath}/server.log" trunc="false" />
	  <outputter type="FileOutputter" name="errorlog"
		filename="#{logpath}/error.log" trunc="true" />
	  <outputter type="FileOutputter" name="environmentlog"
		filename="#{logpath}/environments.log" trunc="false" />
	  <outputter type="EmailOutputter" name="mailadmin">
		<server>localhost</server>
		<port>25</port>
		<from>mueslogs@localhost</from>
		<to>muesadmin@localhost</to>
	  </outputter>

	  <!-- Loggers -->
	  <logger name="MUES"   level="INFO"  outputters="serverlog" />
	  <logger name="error"  level="WARN"  outputters="errorlog,console" />
	  <logger name="dire"   level="ERROR" outputters="errorlog,console,mailadmin" />
	</log4r_config>
  </logging>


  <!-- Environments which are to be loaded at startup -->
  <environments>
	<environment name="FaerieMUD" class="FaerieMUD::World">
	  <objectstore name="FaerieMUD">
		<backend class="BerkeleyDB"></backend>
		<garbagecollector class="PMOS"></garbagecollector>
	  </objectstore>
	</environment>

	<environment name="testing" class="MUES::ObjectEnv">
	  <objectstore name="testing-objectenv">
		<backend class="Flatfile" />
		<garbagecollector class="Simple">
		  <param name="trash_rate">100</param>
		</garbagecollector>
	  </objectstore>
	</environment>
  </environments>


  <!-- Services which are to be loaded at startup -->
  <services>
	<service name="objectstore" class="MUES::ObjectStoreService" />
	<service name="soap" class="MUES::SOAPService">
	  <param name="listen-port">7680</param>
	  <param name="listen-address">0.0.0.0</param>
	  <param name="use-wrappers">true</param>
	</service>
	<service name="physics" class="MUES::ODEService" />
	<service name="weather" class="MUES::WeatherService" />
  </services>

</muesconfig>

END
end

