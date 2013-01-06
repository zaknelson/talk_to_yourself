talk_to_yourself
================

A ruby app for parsing, analyzing gmail chats.

Setup
-------------

1. Install [gmvault](http://gmvault.org/)
2. `gmvault sync username@gmail.com --chats-only`
3. `ln -s ~/gmvault-db/db/chats archived-chats`
4. `bundle install`
5. `./talk_to_yourself.rb`