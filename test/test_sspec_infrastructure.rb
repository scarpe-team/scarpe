# frozen_string_literal: true

require "test_helper"

# Having trouble here - need to make sure we're getting
# assertions and exceptions as expected.
class TestSSpecInfrastructure < ShoesSpecLoggedTest
  self.logger_dir = File.expand_path("#{__dir__}/../logger")

  def test_simple_assertion_success
    run_scarpe_sspec_code(<<~'SSPEC')
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      assert_equal true, true
    SSPEC
  end

  def test_empty_assertions
    run_scarpe_sspec_code(<<~'SSPEC')
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      # Without at least a comment, the file parser doesn't catch that this section is here.
    SSPEC
  end

  # Here's a weird thing: we want to detect the test failure somehow. And right now we
  # can't usefully tell the timeout to cause the *process* to fail just from the timeout.
  # We'll still notice test failures or not hitting enough assertions.
  def test_timeout_no_fail
    run_scarpe_sspec_code(<<~'SSPEC', timeout: 1.0, wait_after_test: true, expect_assertions_min: 1)
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      assert_equal true, true
    SSPEC
  end

  def test_timeout_test_fail
    run_scarpe_sspec_code(<<~'SSPEC', timeout: 1.0, wait_after_test: true, expect_result: :fail)
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      assert_equal false, true
    SSPEC
  end

  # Specify ":none" for timeout. In this case it will still finish promptly -- just checking
  # that the setting works.
  def test_no_timeout
    run_scarpe_sspec_code(<<~'SSPEC', timeout: :none)
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      assert_equal true, true
    SSPEC
  end

  def test_exception
    run_scarpe_sspec_code(<<~'SSPEC', expect_result: :error)
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      raise "Yup, that's an exception!"
    SSPEC
  end

  def test_many_assertions
    run_scarpe_sspec_code(<<~'SSPEC', expect_assertions_min: 10)
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      10.times { assert_equal true, true }
    SSPEC
  end

  def test_skip
    run_scarpe_sspec_code(<<~'SSPEC', expect_result: :skip)
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      skip
    SSPEC
  end

  def test_assertion_fail
    run_scarpe_sspec_code(<<~'SSPEC', expect_result: :fail)
      ---
      ----------- app code
      Shoes.app do
      end
      ----------- test code
      assert_equal true, false, "This should always fail!"
    SSPEC
  end
end
