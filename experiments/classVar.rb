#!/usr/bin/ruby -w


class Foo
  @ivar = 'foo!'

  def ivar
    self.class.instance_eval do @ivar end
  end
end


f = Foo::new
puts f.ivar
