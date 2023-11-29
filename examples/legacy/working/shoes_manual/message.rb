class Messenger
 def initialize(stack)
   @stack = stack
 end
 def add(msg)
   @stack.app do
     @stack.append do
       para msg
     end
   end
 end
end

Shoes.app do
  @stack = stack do
  end
  Messenger.new(@stack).add('Hii')
end
