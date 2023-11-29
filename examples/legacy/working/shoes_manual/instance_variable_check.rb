# instance variables allowed as the code block is essentially running
# inside Shoes class due to the use of instance_eval

Shoes.app do
 @s = stack do
   @p1 = para "First"
   @p2 = para "Second"
   @p3 = para "Third"
 end
end
