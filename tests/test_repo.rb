require 'minitest/reporters'
MiniTest::Reporters.use!
require 'minitest/autorun'

require_relative('../src/repo')

class RepoTest < MiniTest::Unit::TestCase

  def setup
    @repo = Repo.new
  end

  def test_initialize
    assert_nil( @repo.name)

  end

end