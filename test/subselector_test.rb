#!/usr/local/bin/ruby -Ilib:test "/usr/local/lib/ruby/gems/1.8/gems/rake-0.8.1/lib/rake/rake_test_loader.rb" test/subselector_test.rb
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

# only need to set up once
setup_db
setup_fixtures

class SubselectorTest < Test::Unit::TestCase

  # verify
  
  def test_conditions_with_string_unchanged
    c = Critic.find(:all, :conditions => ['active = ?', 't'])
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }  
  end

  # subselect in array conditions
  
  def test_same_table_hash_subquery_with_string_conditions_in_array_conditions
    c = Critic.find(:all, :conditions => ['id in (?)', {:select => :id, :conditions => 'active = "t"' }])
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end
  
  def test_same_table_hash_subquery_in_array_conditions
    c = Critic.find(:all, :conditions => ['id in (?)', {:select => :id, :conditions => {:active => false} }])
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_same_table_hash_subquery_negated_in_array_conditions
    c = Critic.find(:all, :conditions => ['id not in (?)', {:select => :id, :conditions => {:active => true} }])
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_different_model_hash_subquery_in_array_conditions
    c = Critic.find(:all, :conditions => ['id in (?)', {:model => :rankings, :select => :critic_id, :conditions => {:week => 39} }])
    assert_equal [["reid", true], ["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_equal_subquery_in_array_conditions
    c = Critic.find(:all, :conditions => ['id = (?)', {:select => :id, :conditions => {:active => false} }])
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_not_equal_subquery_in_array_conditions
    c = Critic.find(:all, :conditions => ['id != (?)', {:select => :id, :conditions => {:active => false} }])
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end
  
  # subselect in hash conditions

  def test_same_table_string_subquery_in_hash_conditions
    c = Critic.find(:all, :conditions => { :id => {:in => 'select id from critics where active = "t"' } })
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end

  def test_same_table_hash_subquery_with_string_conditions_in_hash_conditions
    c = Critic.find(:all, :conditions => { :id => {:in => {:select => :id, :conditions => 'active = "t"' } } })
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end

  def test_same_table_hash_subquery_in_hash_conditions
    c = Critic.find(:all, :conditions => { :id => {:in => {:select => :id, :conditions => {:active => false} } } })
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_same_table_hash_subquery_negated_in_hash_conditions
    c = Critic.find(:all, :conditions => { :id => {:not_in => {:select => :id, :conditions => {:active => true} } } })
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_different_model_hash_subquery_in_hash_conditions
    c = Critic.find(:all, :conditions => { :id => {:in => {:model => :rankings, :select => :critic_id, :conditions => {:week => 39} } } })
    assert_equal [["reid", true], ["doug", false]], c.map { |c| [c.login, c.active] }
  end
  
  def test_equal_subquery_in_hash_conditions
    c = Critic.find(:all, :conditions => { :id => {:equal => {:select => :id, :conditions => {:active => false} } } })
    assert_equal [["doug", false]], c.map { |c| [c.login, c.active] }
  end

  def test_not_equal_subquery_in_hash_conditions
    c = Critic.find(:all, :conditions => { :id => {:not_equal => {:select => :id, :conditions => {:active => false} } } })
    assert_equal [["reid", true], ["dewey", true]], c.map { |c| [c.login, c.active] }
  end

  # extract_subselect_model! tests
  
  def test_extract_subselect_model_string
    assert_equal Critic, Critic.send(:extract_subselect_model!, "this is a string")
  end

  def test_extract_subselect_model_hash_without_model
    assert_equal Critic, Critic.send(:extract_subselect_model!, {:no_model => :yeah})
  end

  def test_extract_subselect_model_hash_with_model
    assert_equal Nominee, Critic.send(:extract_subselect_model!, {:model => :nominee})
  end

  # get_subselect_key test
  
  [:in, :not_in, :equal, :not_equal].each do |key|
    define_method("test_getting_#{key}_subselect_key") do
      assert_equal Critic.send(:get_subselect_key, {key => :test}), key
    end
  end
  
  def test_getting_nil_for_unmatched_subselect_key
    assert_nil Critic.send(:get_subselect_key, {:foo => :test})
  end

  def test_getting_first_key_for_multiple_subselect_keys
    assert_include Critic.send(:get_subselect_key, {:in => :test, :equal => :test}), [:in, :equal]
  end

  def test_getting_first_key_for_multiple_subselect_keys
    assert_include Critic.send(:get_subselect_key, {:in => :test, :equal => :test}), [:in, :equal]
  end
  
  class Duck; def keys; [:in] end end
  def test_getting_subselect_key_for_a_duck    
    assert_equal Critic.send(:get_subselect_key, Duck.new), :in    
  end

  def test_getting_nil_for_a_nonsensical_subselect
    assert_nil Critic.send(:get_subselect_key, "foo")
    assert_nil Critic.send(:get_subselect_key, [:in])
  end

  private
    def assert_include(element, enumeration, message=nil)
      assert enumeration.include?(element), message
    end
end
