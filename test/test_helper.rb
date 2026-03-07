# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "prato"

require "minitest/autorun"

require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string  :name,   null: false
    t.string  :email
    t.integer :age
    t.boolean :active, default: true
    t.timestamps
  end

  create_table :posts do |t|
    t.belongs_to :user, null: false
    t.string     :title
    t.text       :body
    t.timestamps
  end
end

class User < ActiveRecord::Base
  has_many :posts
  scope :active, -> { where(active: true) }
end

class Post < ActiveRecord::Base
  belongs_to :user
end
