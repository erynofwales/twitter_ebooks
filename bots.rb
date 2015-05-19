require 'fileutils'
require 'twitter_ebooks'


# Information about a particular Twitter user we know
class UserInfo
  attr_reader :username

  # @return [Integer] how many times we can pester this user unprompted
  attr_accessor :pesters_left

  # @param username [String]
  def initialize(username)
    @username = username
    @pesters_left = 1
  end
end


class ERWEbooksBot < Ebooks::Bot
  attr_accessor :original, :model, :model_path

  def configure
    self.consumer_key = "62TFTbFio3IPinwFh0VLCRC3l"
    self.consumer_secret = "OSXSsFbhNNNX5J1IU15zvX8xuNVPHzfunhybdWR7oZdos27Qsz"
    self.blacklist = []
    self.delay_range = 1..6
    @userinfo = {}
  end

  def top100; @top100 ||= model.keywords.take(100); end
  def top20;  @top20  ||= model.keywords.take(20); end

  def on_startup
    log "Starting up bot for @#{original} at #{Time.now}"

    @model_path ||= "model/#{original}.model"
    @archive_path ||= "model/#{original}.json"

    # Post a tweet every two hours
    scheduler.every '2h' do
      tweet(model.make_statement)
    end

    # Update the corpus every day
    scheduler.every '24h', :first => :now do
      archive!
      load_model!
    end
  end

  def on_message(dm)
    delay do
      reply(dm, model.make_response(dm.text))
    end
  end

  def on_mention(tweet)
    # Become more inclined to pester a user when they talk to us
    userinfo(tweet.user.screen_name).pesters_left += 1

    delay do
      reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
    end
  end

  def on_timeline(tweet)
    return if tweet.retweeted_status?
    return unless can_pester?(tweet.user.screen_name)

    tokens = Ebooks::NLP.tokenize(tweet.text)

    interesting = tokens.find { |t| top100.include?(t.downcase) }
    very_interesting = tokens.find_all { |t| top20.include?(t.downcase) }.length > 2

    delay do
      if very_interesting
        favorite(tweet) if rand < 0.5
        retweet(tweet) if rand < 0.1
        if rand < 0.01
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
        end
      elsif interesting
        favorite(tweet) if rand < 0.05
        if rand < 0.001
          userinfo(tweet.user.screen_name).pesters_left -= 1
          reply(tweet, model.make_response(meta(tweet).mentionless, meta(tweet).limit))
        end
      end
    end
  end

  # Find information we've collected about a user
  # @param username [String]
  # @return [Ebooks::UserInfo]
  def userinfo(username)
    @userinfo[username] ||= UserInfo.new(username)
  end

  # Check if we're allowed to send unprompted tweets to a user
  # @param username [String]
  # @return [Boolean]
  def can_pester?(username)
    userinfo(username).pesters_left > 0
  end

  # Only follow our original user or people who are following our original user
  # @param user [Twitter::User]
  def can_follow?(username)
    @original.nil? || username == @original || twitter.friendship?(username, @original)
  end

  def favorite(tweet)
    if can_follow?(tweet.user.screen_name)
      super(tweet)
    else
      log "Unfollowing @#{tweet.user.screen_name}"
      twitter.unfollow(tweet.user.screen_name)
    end
  end

  def on_follow(user)
    if can_follow?(user.screen_name)
      follow(user.screen_name)
    else
      log "Not following @#{user.screen_name}"
    end
  end

  private
  def load_model!
    log "Loading model #{@model_path}"
    @model = Ebooks::Model.load(@model_path)
  end

  private
  def archive!
      log "Archiving tweets #{@archive_path}"
      Ebooks::Archive.new(@original, @archive_path).sync
      Ebooks::Model.consume(@archive_path).save(@model_path)
  end
end

ERWEbooksBot.new("erw_ebooks") do |bot|
  bot.access_token = "709877880-0bmPoDjNQBy52HSzRqT6MWspaphKFE9qAx1GMzxw"
  bot.access_token_secret = "fqmLg3BuGOQG2osrTTDm6VEhaDMj0CKGpFl7aYCv6cxB3"
  bot.original = "erynofwales"
end
