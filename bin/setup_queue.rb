#!/usr/bin/env ruby1.9

BEGIN {
	require 'pathname'
	basedir = Pathname( __FILE__ ).dirname.parent
	libdir = basedir + 'lib'
	extdir = basedir + 'ext'

	$LOAD_PATH.unshift( libdir.to_s )
	$LOAD_PATH.unshift( extdir.to_s )
}

require 'mues'
require 'mues/utils'

include MUES::UtilityFunctions

PERMS_UNLIMITED = '.*'
PERMS_NONE = ''

VHOSTS = %w[
	/players
	/env
]
USERS = {
	# $username => { $vhost => [$configperm, $writeperm, $readperm], ... }
	'engine' => {
		:password  => 'Iuv{o8veeciNgoh0', # :TODO: auto-generate this or read it from a config file
		:perms     => {
			'/env'     => [ PERMS_UNLIMITED, PERMS_UNLIMITED, PERMS_UNLIMITED ],
			'/players' => [ PERMS_UNLIMITED, PERMS_UNLIMITED, PERMS_UNLIMITED ],
		},
	},
	'testplayer' => {
		:password  => 'test',
		:perms => {
			'/players' => [
				'^testplayer(:.*)?$',
				'^(login|testplayer)$',
				'^testplayer$',
			],
		}
	},
	'ged' => {
		:password  => 'toy*59washes',
		:perms => {
			'/players' => [
				'^(ged\.agent(in|out)put))$',
				'^(login|testplayer\..*)$',
				'^testplayer\..*$',
			],
		}
	}
}

$rabbitmqctl = (ENV['RABBITMQCTL'] || which('rabbitmqctl') ) or
	abort "Can't find rabbitmqctl in your PATH. Try running with RABBITMQCTL=/path/to/rabbitmqctl"


vhosts = []
readfrom( $rabbitmqctl, 'list_vhosts' ) do |io|
	io.readlines.each do |line|
		vhosts << line.chomp unless line.index('...')
	end
end

VHOSTS.each do |vhost|
	if vhosts.include?( vhost )
		log "Excellent, we already have a #{vhost} vhost."
	else
		run $rabbitmqctl, 'add_vhost', vhost
	end
end

users = []
readfrom( $rabbitmqctl, 'list_users' ) do |io|
	io.readlines.each do |line|
		users << line.chomp unless line.index('...')
	end
end


USERS.each do |username, config|
	if users.include?( username )
		log "Excellent, we already have a #{username} user. Ensuring the password is correct."
		run $rabbitmqctl, 'change_password', username, config[:password]
	else
		run $rabbitmqctl, 'add_user', username, config[:password]
	end

	config[:perms].each do |vhost, perms|
		if vhost == ''
			log "  setting global permissions to: %p" % [ perms ]
			run $rabbitmqctl, 'set_permissions', username, *perms
		else
			log "  setting permissions for the %s vhost to: %p" % [ vhost, perms ]
			run $rabbitmqctl, 'set_permissions', '-p', vhost, username, *perms
		end
	end
end

