Feature: Server Setup
	In order to prep a machine to run the game
	As a sysadmin
	I want to be able to do the necessary initialization using a command line tool

	Scenario: setting up a new MUES environment
		Given a running rabbitmq server with no MUES vhosts or users
		When I run "bin/mues setup"
		Then a new environment is created
			And the initial vhosts are added to the rabbitmq server
			And the initial users are added to the rabbitmq server
	
	
	
