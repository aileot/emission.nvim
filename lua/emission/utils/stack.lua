local Stack = {}
Stack.__index = Stack
Stack.new = function()
  local self = setmetatable({_stack = {}}, Stack)
  return self
end
Stack["push!"] = function(self, item)
  return table.insert(self._stack, item)
end
Stack["pop!"] = function(self)
  return table.remove(self._stack)
end
Stack.get = function(self)
  return self._stack
end
Stack["empty?"] = function(self)
  return (0 == #self._stack)
end
return {Stack = Stack}
