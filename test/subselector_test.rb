# /usr/local/bin/ruby -Ilib:test "/usr/local/lib/ruby/gems/1.8/gems/rake-0.8.1/lib/rake/rake_test_loader.rb" test/subselector_test.rb
$:.unshift "#{File.dirname(__FILE__)}/.."
require 'test/unit'

require 'rubygems'
gem 'activerecord', '>= 2.0.0'
require 'active_record'

require "init"

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

def setup_db
  ActiveRecord::Schema.define(:version => 1) do
    create_table :critics do |t|
      t.column "login", :string
      t.column "active", :boolean
    end
    create_table :rankings do |t|
      t.column "critic_id", :integer
      t.column "nominee_id", :integer
      t.column "order", :integer
      t.column "week", :integer
    end
    create_table :nominees do |t|
      t.column "name", :string
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Critic < ActiveRecord::Base ; end
class Ranking < ActiveRecord::Base ; end
class Nominee < ActiveRecord::Base ; end

CRITICS = [
  { :login => 'reid', :active => true },
  { :login => 'dewey', :active => true },
  { :login => 'doug', :active => false }
]

RANKINGS = [
  { :critic_id => 1, :nominee_id => 1, :order => 1, :week => 39 }, 
  { :critic_id => 1, :nominee_id => 2, :order => 2, :week => 39 },
  { :critic_id => 3, :nominee_id => 1, :order => 2, :week => 39 }
]

def setup_fixtures
  CRITICS.each { |values| Critic.new(values).save! }
  RANKINGS.each { |values| Ranking.new(values).save! }
end

class SubselectorTest < Test::Unit::TestCase

  def setup
    setup_db
    setup_fixtures
  end

  def teardown
    teardown_db
  end

  def test_same_table_string_subquery
    c = Critic.find(:all, :conditions => { :id => {:in => 'select id from critics where active = "t"' } })
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end

  def test_same_table_hash_subquery_with_string_conditions
    c = Critic.find(:all, :conditions => { :id => {:in => {:select => :id, :conditions => 'active = "t"' } } })
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end

  def test_same_table_hash_subquery
    c = Critic.find(:all, :conditions => { :id => {:in => {:select => :id, :conditions => {:active => false} } } })
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_same_table_hash_subquery_negated
    c = Critic.find(:all, :conditions => { :id => {:not_in => {:select => :id, :conditions => {:active => true} } } })
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_different_model_hash_subquery
    c = Critic.find(:all, :conditions => { :id => {:in => {:model => :rankings, :select => :critic_id, :conditions => {:week => 39} } } })
    assert_equal [["reid", true], ["doug", false]], c.map { |c| [c.login, c.active] }
  end
  
  def test_equal_subquery
    c = Critic.find(:all, :conditions => { :id => {:equal => {:select => :id, :conditions => {:active => false} } } })
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_not_equal_subquery
    c = Critic.find(:all, :conditions => { :id => {:not_equal => {:select => :id, :conditions => {:active => false} } } })
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end
end
