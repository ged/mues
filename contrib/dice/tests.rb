#!/usr/bin/env ruby
require "dice"

# test out the dice

foo = Dice.new(4,6)

foo.rolls.each do |roll| printf("%s ", roll.to_s) end
puts "\n"

i = 0
while i < (foo.rolls.size)
    printf("Roll %d was: %s\n", i + 1, foo.rolls[i].to_s)
    i += 1
end

puts "#{foo.number}d#{foo.sides}#{foo.modifier}"
puts "The subtotal was #{foo.subtotal}"
puts "The total was #{foo.total}", "\n"

my_test = d20vs(18)
puts my_test