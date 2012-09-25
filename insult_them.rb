#!/usr/bin/ruby

require 'rubygems'
require 'twitter'
require 'yaml'
require 'logger'

$responses
$logger = Logger.new( 'log.log', 'daily' )
$logger.level = Logger::INFO

def authorize
  auth_keys=YAML.load_file("oauth_keys.yml")
  Twitter.configure do |config|
	  config.consumer_key=auth_keys["consumer_key"]
	  config.consumer_secret=auth_keys["consumer_secret"]
	  config.oauth_token=auth_keys["oauth_token"]
	  config.oauth_token_secret=auth_keys["oauth_token_secret"]
  end
end

def get_mentions
  idstore=YAML.load_file("idstore.yml")
  last_mention=idstore["last_mention"]
  begin
    mentions=Twitter.mentions(:include_entities=>true,:since_id=>last_mention)
  rescue
    $logger.error("Error Getting Mentions")
  end
  if mentions.length!=0
    idstore["last_mention"]=mentions.last.id
    File.open("idstore.yml","w") { |file| YAML.dump(idstore,file) }
  end
  return mentions
end

def parse_and_process_status(status)
  mentioned_users=status.user_mentions
  if mentioned_users.length==1
    general_reply(status)
  elsif mentioned_users.length>1
    mentioned_users.each do |user|
      if user.screen_name!="insult_them"
        insult(user.screen_name)
      end
    end
  end
end

def search_and_insult
  idstore=YAML.load_file("idstore.yml")
  last_search=idstore["last_search"]
  temp_last_search=0
  Twitter.search("insult",:result_type=>"recent",:since_id=>last_search,:rpp=>5).results.map do |status|
    insult(status.from_user,status.id)
    temp_last_search=status.id
  end
  if temp_last_search!=0
    idstore["last_search"]=temp_last_search
    File.open("idstore.yml","w") { |file| YAML.dump(idstore,file) }
  end
end

def insult(screen_name,status_id=nil)
  insult=$responses["insults"].sample
  begin
    Twitter.update("@#{screen_name} #{insult} #ROFL",:in_reply_to_status_id=>status_id)
  rescue
    $logger.error("Error Tweeting")
    $logger.error("#{$!}")
    $logger.error("#{$@}")
  end
end

def general_reply(status)
  reply=$responses["replies"].sample
  begin
    Twitter.update("@#{status.from_user} #{reply}",:in_reply_to_status_id=>status.id)
  rescue
    $logger.error("Error Tweeting")
    $logger.error("#{$!}")
    $logger.error("#{$@}")
  end
end



$logger.info("###########BOT STARTED#########")
authorize
$responses=YAML.load_file("responses.yml")
mentions=get_mentions
if mentions.length!=0
  mentions.each do |mention|
    parse_and_process_status(mention)
  end
end
search_and_insult

$logger.info("###########BOT TERMINATED##")
