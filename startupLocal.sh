#!/bin/bash

# To be run from the root.
# You should do one build first by calling both the build_.rb files
# Starts a simple python http server
# Will build the html and js everytime a file in there is modified

python3 -m http.server --directory build/artifacts &
fswatch -or ./src | xargs -n1 sh -c 'cd build && bundle exec ruby build_src.rb' &
wait
