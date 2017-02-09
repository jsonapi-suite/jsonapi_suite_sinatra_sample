require 'json'

Bundler.require(:default)
require 'sinatra/base'
require 'jsonapi/serializable'
require 'sequel'
require 'pry'
require 'pry-byebug'

DB = Sequel.sqlite(logger: Logger.new($stdout))
DB.extension(:pagination)

DB.create_table :authors do
  primary_key :id
  String :name
end

DB.create_table :tweets do
  primary_key :id
  Integer :author_id
  String :content
end

class Tweet < Sequel::Model
  many_to_one :author
end

class Author < Sequel::Model
  one_to_many :tweets
end

Author.insert(name: 'author1')
Author.insert(name: 'author2')

# Populate the table
Tweet.insert(content: 'tweet1', author_id: 1)
Tweet.insert(content: 'tweet2', author_id: 1)
Tweet.insert(content: 'tweet3', author_id: 2)

class SerializableTweet < JSONAPI::Serializable::Resource
  type 'tweets'

  attribute :content

  belongs_to :author
end

class SerializableAuthor < JSONAPI::Serializable::Resource
  type 'authors'

  attribute :name
end

class TwitterApp < Sinatra::Application
  include JsonapiCompliable

  jsonapi do
    sort do |scope, att, dir|
      dir == :desc ? scope.reverse_order(att) : scope.order(att)
    end

    paginate do |scope, current_page, per_page|
      scope.paginate(current_page, per_page, 100) # fake total count to avoid query
    end
  end

  configure do
    mime_type :jsonapi, 'application/vnd.api+json'
  end

  before do
    content_type :jsonapi
  end

  get '/api/tweets' do
    resource.with_context self, :index do
      scope = jsonapi_scope(Tweet)
      render_jsonapi(scope.resolve.all, scope: false)
    end
  end
end
