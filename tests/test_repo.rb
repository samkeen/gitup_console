require 'minitest/reporters'
MiniTest::Reporters.use!
require 'minitest/autorun'

require_relative('../src/repo')

# see http://www.ruby-doc.org/stdlib-1.9.3/libdoc/minitest/unit/rdoc/MiniTest/Assertions.html

class RepoTest < MiniTest::Unit::TestCase

  def setup
    @repo = Repo.new
  end

  def test_initialize
    assert_nil( @repo.name)
    assert_nil( @repo.target_branch)
    assert_equal([], @repo.submodules)
  end

end