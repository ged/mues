#!/usr/bin/ruby
#
#	The default questionnaire script used to log in.
#	$Id$
#

[
	# Username
	{
		:name		=> "username",
		:question   => "Username: ",
		:validator	=> lambda {|qnaire,answer|
			qnaire.data[:tries] ||= 0
			qnaire.data[:tries] += 1

			# Set up a timeout
			unless qnaire.data[:timeoutEvent]
				seconds = qnaire.data[:timeout] || 600
				msg = "Timeout (%d seconds)." % seconds
				event = MUES::LoginFailureEvent::new( qnaire.stream, msg )
				scheduleEvents( Time.now + seconds, event )
				qnaire.data[:timeoutEvent] = event
			end

			# If there have been more than 3 attempts, dispatch a failure event
			if qnaire.data[:tries] > 3
				qnaire.error( "--- Too many attempts ---" )
				dispatchEvents( MUES::LoginFailureEvent::new("Too many attempts") )
				qnaire.finish
			end

			return false if answer.strip.empty?
			return answer.strip
		}, # lambda
	},

	# Password
	{
		:name		=> 'password',
		:question	=> "Password: ",
		:hidden		=> true,
		:blocking	=> true,
		:validator	=> lambda {|qnaire,answer|

			# Success callback
			success = lambda {|user|
				cancelScheduledEvents( qnaire.data[:timeoutEvent] )
				user.lastLoginDate = Time::now
				user.lastHost = qnaire.data[:filter].peerName

				cshell = @commandShellFactory.createShellForUser( user )
				cshell.debugLevel = 1

				qnaire.stream.addFilters( cshell )
				qnaire.restart( true )
			}

			# Failure callback
			failure = lambda {|user|
				qnaire.stream.addEvents OutputEvent::new("\nAuthentication failure.\n")

				tries = qnaire.data[:tries]
				if tries >= 3
					self.log.notice "Max login tries (%d) exceeded for %s" %
						[ tries, qnaire.stream ]
					qnaire.stream.addEvents OutputEvent::new( ">>> Max tries exceeded. <<<" )
					dispatchEvents( LoginFailureEvent::new("Too many attempts.") )
					qnaire.finish

				else
					self.log.notice "Failed login attempt %d from %s" %
						[ tries, qnaire.stream ]
					qnaire.undoSteps(1) # :FIXME: This might be 2...
					qnaire.restart( false )
				end

			}

			# Authentication event
			laevent = LoginAuthEvent::new(
				qnaire.stream,
				qnaire.answers[:username],
				answer,
				qnaire.data[:filter],
				success,
				failure )
			dispatchEvents( laevent )


		}, # lambda
	},



]

