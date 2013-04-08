require "json"
require 'yaml'

require "sinatra/base"
require "github-trello/version"
require "github-trello/http"


module GithubTrello
  class Server < Sinatra::Base
    
    configure do 
      path = 'trello.yml'
      puts "Loading configuration from #{path} ..."
      unless File.exists?(path)
        puts "[ERROR] No configuration file found, exiting."
        exit
      end
      
      config = YAML::load(File.read(path))
      set :config, config
    end

    helpers do
      def merge_commit?(commit, card)
        card['actions'].each do |action|
          return true if action['data'] && action['data']['text'].include?(commit['url'])
        end
        false
      end
    end
    
    post "/posthook" do
      config = self.class.config

      payload = JSON.parse(params[:payload])

      board_id = config["board_ids"][payload["repository"]["name"]]
      unless board_id
        puts "[ERROR] Commit from #{payload["repository"]["name"]} but no board_id entry found in config"
        return
      end

      branch = payload["ref"].gsub("refs/heads/", "")
      if config["blacklist_branches"] and config["blacklist_branches"].include?(branch)
        return
      elsif config["whitelist_branches"] and !config["whitelist_branches"].include?(branch)
        return
      end

      payload["commits"].each do |commit|
        # Figure out the card short id
        match = commit["message"].match(/((case|card|close|archive|fix)e?s? \D?([0-9]+))/i)
        card_id = (match && match[3].to_i > 0) ? match[3].to_i : nil
        next unless card_id

        puts "Received commit from user #{commit["author"]["name"]} for https://trello.com/card/card-title-placeholder/#{board_id}/#{card_id} ..."
        
        user = config["users"][commit["author"]["name"]]
        fallback_user = false
        unless user
          fallback_user = true
          user = config["users"][config["fallback_user"]] if config["fallback_user"]
        end
        
        http = GithubTrello::HTTP.new(user["oauth_token"], user["api_key"])
        
        results = http.get_card(board_id, card_id)
        unless results
          puts "[ERROR] Cannot find card matching ID #{match[3]}"
          next
        end

        results = JSON.parse(results)

        # Add the commit comment
        message = "#{commit['author']['name'] + ': ' if fallback_user}[#{branch}] #{commit["message"]}\n#{commit["url"]}"
        message.gsub!(match[1], "")
        message.gsub!(/\(\)$/, "")

        http.add_comment(results["id"], message) unless merge_commit?(commit, results)

        # Determine the action to take
        update_config = case match[2].downcase
          when "case", "card" then config["on_start"]
          when "close", "fix" then config["on_close"]
          when "archive" then {:archive => true}
        end

        next unless update_config.is_a?(Hash)

        # Modify it if needed
        to_update = {}

        unless results["idList"] == update_config["move_to"]
          to_update[:idList] = update_config["move_to"]
        end

        if !results["closed"] and update_config["archive"]
          to_update[:closed] = true
        end

        unless to_update.empty?
          http.update_card(results["id"], to_update)
        end
      end

      ""
    end

    post "/deployed/:repo" do
      config, http = self.class.config, self.class.http
      if !config["on_deploy"]
        raise "Deploy triggered without a on_deploy config specified"
      elsif !config["on_close"] or !config["on_close"]["move_to"]
        raise "Deploy triggered and either on_close config missed or move_to is not set"
      end

      update_config = config["on_deploy"]

      to_update = {}
      if update_config["move_to"] and update_config["move_to"][params[:repo]]
        to_update[:idList] = update_config["move_to"][params[:repo]]
      end

      if update_config["archive"]
        to_update[:closed] = true
      end

      cards = JSON.parse(http.get_cards(config["on_close"]["move_to"]))
      cards.each do |card|
        http.update_card(card["id"], to_update)
      end

      ""
    end

    get "/" do
      #settings.config.inspect
      ''
    end

  end
end