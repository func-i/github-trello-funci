#!/usr/bin/env ruby
$LOAD_PATH.unshift ::File.expand_path(::File.dirname(__FILE__) + "/lib")
require "github-trello/server"

use Rack::ShowExceptions
run GithubTrello::Server.new

$stdout.sync = true # make puts output to logs on heroku immediately