# self is same throughout due to the use of instance_eval. Caller
# is Shoes instance.

Shoes.app do
 self.stack do
   self.para "First"
   self.para "Second"
   self.para "Third"
 end
end
