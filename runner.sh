#!/bin/bash

exec 2> /tmp/rc.local.log      # send stderr from rc.local to a log file
exec 1>&2                      # send stdout to the same log file
set -x  

export PATH

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
#cd /home/ec2-user
# ruby Worker.rb
/home/ec2-user/.rvm/wrappers/ruby-2.3.0/ruby /home/ec2-user/worker/Worker.rb
