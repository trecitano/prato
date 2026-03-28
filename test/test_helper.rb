# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "prato"

require "minitest/autorun"

require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::QueryLogs.taggings = { source_location: true }
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  caller_line = caller.find { |l| l.include?("prato") && !l.include?("vendor") }
  puts "  ↳ #{caller_line}" if caller_line
end

ActiveRecord::Schema.define do
  create_table :companies do |t|
    t.string :name, null: false
    t.string :industry
    t.string :country
    t.timestamps
  end

  create_table :users do |t|
    t.string  :name,   null: false
    t.string  :email
    t.integer :age
    t.boolean :active, default: true
    t.belongs_to :company
    t.timestamps
  end

  create_table :posts do |t|
    t.belongs_to :user, null: false
    t.belongs_to :category
    t.string     :title
    t.text       :body
    t.boolean    :published, default: false
    t.integer    :score
    t.timestamps
  end

  create_table :comments do |t|
    t.belongs_to :post, null: false
    t.belongs_to :user, null: false
    t.text       :body
    t.integer    :score
    t.timestamps
  end

  create_table :categories do |t|
    t.string :name, null: false
    t.belongs_to :parent_category, foreign_key: { to_table: :categories }
    t.timestamps
  end

  create_table :tags do |t|
    t.string :name, null: false
    t.timestamps
  end

  create_table :post_tags do |t|
    t.belongs_to :post, null: false
    t.belongs_to :tag, null: false
    t.timestamps
  end
end

class Company < ActiveRecord::Base
  has_many :users
  has_many :posts, through: :users
end

class User < ActiveRecord::Base
  belongs_to :company, optional: true
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
  has_many :comments
  has_many :commented_posts, through: :comments, source: :post

  scope :active, -> { where(active: true) }
  scope :with_latest_post_summary, -> {
    select("(#{latest_post_summary_sql}) AS latest_post_summary")
  }

  def self.latest_post_summary_sql
    "SELECT title FROM posts WHERE posts.user_id = users.id ORDER BY created_at DESC LIMIT 1"
  end

  def self.post_count_above_sql(min_score)
    "SELECT COUNT(*) FROM posts WHERE posts.user_id = users.id AND posts.score >= #{min_score.to_i}"
  end
end

class Post < ActiveRecord::Base
  belongs_to :user
  belongs_to :category, optional: true
  has_many :comments
  has_many :commenters, through: :comments, source: :user
  has_many :post_tags
  has_many :tags, through: :post_tags
end

class Comment < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  has_one :post_author, through: :post, source: :user
end

class Category < ActiveRecord::Base
  belongs_to :parent_category, class_name: "Category", optional: true
  has_many :subcategories, class_name: "Category", foreign_key: :parent_category_id
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
end

class Tag < ActiveRecord::Base
  has_many :post_tags
  has_many :posts, through: :post_tags
end

class PostTag < ActiveRecord::Base
  belongs_to :post
  belongs_to :tag
end

# --- Seed data ---

acme = Company.create!(name: "Acme Corp", industry: "tech", country: "US")
globex = Company.create!(name: "Globex", industry: "finance", country: "UK")

alice = User.create!(name: "Alice", email: "alice@example.com", age: 30, active: true, company: acme)
bob = User.create!(name: "Bob", email: "bob@example.com", age: 17, active: true, company: acme)
carol = User.create!(name: "Carol", email: "carol@example.com", age: 25, active: false, company: globex)
dave = User.create!(name: "Dave", email: "dave@example.com", age: 40, active: true)

tech = Category.create!(name: "Technology")
ruby_cat = Category.create!(name: "Ruby", parent_category: tech)
general = Category.create!(name: "General")

# Alice: 4 posts (3 published, 1 draft)
post1 = alice.posts.create!(title: "Hello", body: "World", published: true, category: ruby_cat, created_at: "2025-01-10", score: 4)
post2 = alice.posts.create!(title: "Draft", body: "WIP", published: false, created_at: "2025-03-05", score: 2)
post3 = alice.posts.create!(title: "Ruby tips", body: "Use frozen strings", published: true, category: tech, created_at: "2025-06-20", score: 5)
post4 = alice.posts.create!(title: "More Ruby", body: "Gems are great", published: true, category: ruby_cat, created_at: "2025-09-15", score: 3)

# Bob: 2 posts (both published)
post5 = bob.posts.create!(title: "Young dev", body: "First post", published: true, category: tech, created_at: "2025-02-14", score: 1)
post6 = bob.posts.create!(title: "Learning Rails", body: "Day one", published: true, category: ruby_cat, created_at: "2025-08-01", score: 4)

# Carol: 3 posts (2 published, 1 draft)
post7 = carol.posts.create!(title: "Finance tips", body: "Save money", published: true, category: general, created_at: "2025-04-12", score: 3)
post8 = carol.posts.create!(title: "Market update", body: "Stocks are up", published: true, category: general, created_at: "2025-07-30", score: 5)
post9 = carol.posts.create!(title: "Unpublished", body: "Not ready", published: false, created_at: "2025-11-01", score: 2)

# post1: 3 comments (post created 2025-01-10)
Comment.create!(post: post1, user: bob, body: "Great post!", created_at: "2025-01-11", score: 2)
Comment.create!(post: post1, user: carol, body: "Thanks for sharing", created_at: "2025-01-12", score: 4)
Comment.create!(post: post1, user: dave, body: "Really helpful", created_at: "2025-01-15", score: 3)

# post3: 2 comments (post created 2025-06-20)
Comment.create!(post: post3, user: bob, body: "Good tip!", created_at: "2025-06-21", score: 3)
Comment.create!(post: post3, user: carol, body: "I agree", created_at: "2025-06-25", score: 2)

# post4: 4 comments (post created 2025-09-15)
Comment.create!(post: post4, user: bob, body: "Love gems", created_at: "2025-09-16", score: 4)
Comment.create!(post: post4, user: carol, body: "Me too", created_at: "2025-09-17", score: 1)
Comment.create!(post: post4, user: dave, body: "Which ones?", created_at: "2025-09-20", score: 3)
Comment.create!(post: post4, user: bob, body: "Puma is great", created_at: "2025-09-22", score: 2)

# post5: 5 comments (post created 2025-02-14)
Comment.create!(post: post5, user: alice, body: "Welcome!", created_at: "2025-02-15", score: 3)
Comment.create!(post: post5, user: carol, body: "Nice start", created_at: "2025-02-16", score: 2)
Comment.create!(post: post5, user: dave, body: "Keep going!", created_at: "2025-02-18", score: 4)
Comment.create!(post: post5, user: alice, body: "You got this", created_at: "2025-02-20", score: 1)
Comment.create!(post: post5, user: carol, body: "Agreed", created_at: "2025-02-25", score: 5)

# post6: 2 comments (post created 2025-08-01)
Comment.create!(post: post6, user: alice, body: "Rails is fun", created_at: "2025-08-02", score: 4)
Comment.create!(post: post6, user: dave, body: "Good luck", created_at: "2025-08-05", score: 5)

# post7: 3 comments (post created 2025-04-12)
Comment.create!(post: post7, user: alice, body: "Good advice", created_at: "2025-04-13", score: 5)
Comment.create!(post: post7, user: bob, body: "Very useful", created_at: "2025-04-15", score: 3)
Comment.create!(post: post7, user: dave, body: "Saving now", created_at: "2025-04-20", score: 4)

# post8: 4 comments (post created 2025-07-30)
Comment.create!(post: post8, user: alice, body: "Interesting take", created_at: "2025-07-31", score: 4)
Comment.create!(post: post8, user: bob, body: "Bull market?", created_at: "2025-08-01", score: 5)
Comment.create!(post: post8, user: dave, body: "Thanks for the update", created_at: "2025-08-03", score: 3)
Comment.create!(post: post8, user: alice, body: "What about bonds?", created_at: "2025-08-05", score: 4)

rails_tag = Tag.create!(name: "rails")
ruby_tag = Tag.create!(name: "ruby")
finance_tag = Tag.create!(name: "finance")

PostTag.create!(post: post1, tag: rails_tag)
PostTag.create!(post: post1, tag: ruby_tag)
PostTag.create!(post: post5, tag: ruby_tag)
PostTag.create!(post: post7, tag: finance_tag)
