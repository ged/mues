class Dice
	
    def initialize(number=1, sides=20, modifier="")
	number=(number)
	sides=(sides)
	modifier=(modifier)
	roll(number, sides, modifier)
    end
	
    def roll(number=1, sides=20, modifier="")
	value = 0
	@rollArray = Array::new
	@subtotal = 0
	@total = 0

	number.times do
	    @rollArray.push(1 + rand(sides))
	end

	@rollArray.each {|roll| @subtotal += roll}

	modifier.strip
	value = modifier[1,modifier.length].to_i

	if modifier.include?("+")
	    @total = (@subtotal) + (value)
	elsif modifier.include?("-")
	    @total = (@subtotal) - (value)
	elsif modifier.include?("*")
	    @total = (@subtotal) * (value)
	elsif modifier.include?("/")
	    @total = (@subtotal.to_f) / (value.to_f)
	    @total = @total.floor
	else
	    @total = @subtotal
	end
	
    end

    def number
	@number
    end

    def sides
	@sides
    end

    def modifier
	@modifier
    end
	
    def rollArray
	@rollArray
    end

    def subtotal
	@subtotal
    end

    def total
	@total
    end

    def number=(newNumber)
	@number = newNumber
    end

    def sides=(newSides)
	@sides = newSides
    end

    def modifier=(newModifier)
	@modifier = newModifier
    end

end