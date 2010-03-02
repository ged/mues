Feature: Login
	In order to play the game
	As a player
	I want to be able to connect as one of my characters
	
	Scenario: Logging in successfully
		Given a running server
		When a player provides a valid character name
			And provides a valid password
			And connects
		Then she is given a success message


  
  
