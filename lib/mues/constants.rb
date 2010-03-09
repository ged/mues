#!/usr/bin/env ruby

require 'mues'

# A collection of constants used throughout the MUES source.
module MUES::Constants

	# The domain to put Arrow objects into
	YAML_DOMAIN = "faeriemud.org,2009-06-15"

	# The default port to listen on
	DEFAULT_PORT = 2424

	# The user to use when connecting to amqp
	DEFAULT_MQ_USER = 'engine'

	# The password to use when connecting to amqp -- obviously this will
	# need to change for anything but the spike.
	DEFAULT_MQ_PASS = 'Iuv{o8veeciNgoh0'

	# The name of the vhost that will be used to communicate with players.
	DEFAULT_PLAYERS_VHOST = '/players'

	# The name of the vhost that will be used for environment events.
	DEFAULT_ENVIRONMENT_VHOST = '/env'

end # module MUES::Constants

