require "js"

puts RUBY_VERSION # (Printed to the Web browser console)
JS.global[:test] = "set this var from ruby"
JS.global[:mycallback] = lambda do |param1|
    puts param1
end
