#!/usr/bin/ruby
#
#	The default questionnaire script used to log in.
#	$SvnId$
#

[
	# Username
	{
		:name		=> "username",
		:question   => "Login: ",
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
				MUES::Logger[self].debug "In the success callback"
				cancelScheduledEvents( qnaire.data[:timeoutEvent] )
				user.lastLoginDate = Time::now
				user.lastHost = qnaire.data[:filter].peerName
				qnaire.answers[:user] = user

				qnaire.restart( true )
				[]
			}

			# Failure callback
			failure = lambda {|user|
				MUES::Logger[self].debug "In the failure callback"
				qnaire.stream.addEvents OutputEvent::new("\nAuthentication failure.\n")

				tries = qnaire.data[:tries]
				if tries >= 3
					MUES::Logger[self].notice "Max login tries (%d) exceeded for %s" %
						[ tries, qnaire.stream ]
					qnaire.stream.addEvents OutputEvent::new( ">>> Max tries exceeded. <<<" )
					qnaire.finish
					return LoginFailureEvent::new("Too many attempts.")

				else
					MUES::Logger[self].notice "Failed login attempt %d from %s" %
						[ tries, qnaire.stream ]
					qnaire.undoSteps(1) # :FIXME: This might be 2...
					qnaire.restart( false )
				end
				return []
			}

			# Authentication event
			laevent = LoginAuthEvent::new(
				qnaire.stream,
				qnaire.answers[:username],
				answer,
				qnaire.data[:filter],
				success,
				failure )
			MUES::Logger[self].debug "Dispatching a login auth event: %p" % laevent
			dispatchEvents( laevent )


		}, # lambda
	},



]

