defexception ExUnit.AssertionError, message: "assertion failed"

defmodule ExUnit.Assertions do
  @moduledoc """
  This module contains a set of assertions functions that are
  imported by default into your test cases.

  In general, a developer will want to use the general
  `assert` macro in tests. The macro tries to be smart
  and provide good reporting whenever there is a failure.
  For example, `assert some_fun() == 10` will fail (assuming
  `some_fun()` returns 13):

      Expected 10 to be equal to 13

  This module also provides other small convenient functions
  like `assert_empty`, and `assert_raise` to easily handle other
  common cases as checking if an enumerable is empty and handling
  exceptions.
  """

  @doc """
  Asserts the `expected` value is true.

  `assert` in general tries to be smart and provide a good
  reporting whenever there is a failure. For example,
  `assert 10 > 15` is going to fail with a message:

      Expected 10 to be more than 15

  ## Examples

      assert true

  """
  defmacro assert(expected) do
    translate_assertion(expected, fn ->
      quote do
        value = unquote(expected)
        assert value, "Expected #{inspect value} to be true"
      end
    end)
  end

  @doc """
  Refutes the `expected` value is true.

  `refute` in general tries to be smart and provide a good
  reporting whenever there is a failure.

  ## Examples

      refute false

  """
  defmacro refute(expected) do
    contents = translate_assertion({ :!, 0, [expected] }, fn ->
      quote do
        value = unquote(expected)
        assert !value, "Expected #{inspect value} to be false"
      end
    end)

    { :!, 0, [contents] }
  end

  @doc """
  Asserts the `expected` value is true.
  If it fails, raises the given message.

  ## Examples

      assert false, "it will never be true"

  """
  def assert(expected, message) when is_binary(message) do
    unless expected, do: flunk message
    true
  end

  ## START HELPERS

  defmacrop negation?(op) do
    quote do: (var!(op) == :! or var!(op) == :not)
  end

  defp translate_assertion({ :=, _, [expected, received] }, _else) do
    quote do
      try do
        unquote(expected) = unquote(received)
      rescue
        x in [MatchError] ->
          raise ExUnit.AssertionError, message: x.message
      end
    end
  end

  defp translate_assertion({ :==, _, [left, right] }, _else) do
    assert_operator :==, left, right, "be equal to (==)"
  end

  defp translate_assertion({ :<, _, [left, right] }, _else) do
    assert_operator :<, left, right, "be less than"
  end

  defp translate_assertion({ :>, _, [left, right] }, _else) do
    assert_operator :>, left, right, "be more than"
  end

  defp translate_assertion({ :<=, _, [left, right] }, _else) do
    assert_operator :<=, left, right, "be less than or equal to"
  end

  defp translate_assertion({ :>=, _, [left, right] }, _else) do
    assert_operator :>=, left, right, "be more than or equal to"
  end

  defp translate_assertion({ :===, _, [left, right] }, _else) do
    assert_operator :===, left, right, "be equal to (===)"
  end

  defp translate_assertion({ :!==, _, [left, right] }, _else) do
    assert_operator :!==, left, right, "be not equal to (!==)"
  end

  defp translate_assertion({ :!=, _, [left, right] }, _else) do
    assert_operator :!=, left, right, "be not equal to (!=)"
  end

  defp translate_assertion({ :=~, _, [left, right] }, _else) do
    assert_operator :=~, left, right, "match (=~)"
  end

  defp translate_assertion({ :in, _, [left, right] }, _else) do
    quote do
      left  = unquote(left)
      right = unquote(right)
      assert(Enum.find(right, &1 == left), "Expected #{inspect left} to be in #{inspect right}")
    end
  end

  ## Negative versions

  defp translate_assertion({ op, _, [{ :=, _, [expected, received] }] }, _else) when negation?(op) do
    quote do
      try do
        unquote(expected) = x = unquote(received)
        flunk "Unexpected right side #{inspect x} match"
      rescue
        x in [MatchError] -> true
      end
    end
  end

  defp translate_assertion({ op, _, [{ :=~, _, [left, right] }] }, _else) when negation?(op) do
    quote do
      left  = unquote(left)
      right = unquote(right)
      assert(!(left =~ right), "Expected #{inspect left} to not match #{inspect right}")
    end
  end

  defp translate_assertion({ op, _, [{ :in, _, [left, right] }] }, _else) when negation?(op) do
    quote do
      left  = unquote(left)
      right = unquote(right)
      assert(!Enum.find(right, &1 == left), "Expected #{inspect left} to not be in #{inspect right}")
    end
  end

  ## Fallback

  defp translate_assertion(_expected, fallback) do
    fallback.()
  end

  defp assert_operator(operator, expected, actual, text) do
    quote do
      left  = unquote(expected)
      right = unquote(actual)
      assert unquote(operator).(left, right),
        "Expected #{inspect left} to #{unquote(text)} #{inspect right}"
    end
  end

  ## END HELPERS

  @doc """
  Assert a message was received and is in the current process mailbox.
  Timeout is set to 0, so there is no waiting time.

  ## Examples

      self <- :hello
      assert_received :hello

  """
  defmacro assert_received(content, message // nil) do
    binary = Macro.to_binary(content)

    quote do
      receive do
        unquote(content) = received -> received
      after
        0 -> flunk unquote(message) || "Expected to have received message matching: #{unquote binary}"
      end
    end
  end

  @doc false
  defmacro assert_match(expected, received) do
    IO.puts "assert_match is deprecated in favor of assert left = right"

    quote do
      try do
        unquote(expected) = unquote(received)
        true
      rescue
        x in [MatchError] ->
          raise ExUnit.AssertionError, message: x.message
      end
    end
  end

  @doc false
  def assert_member(base, container, message // nil) do
    IO.puts "assert_member is deprecated in favor of assert left in right"
    message = message || "Expected #{inspect container} to include #{inspect base}"
    assert(Enum.find(container, &1 == base), message)
  end

  @doc """
  Asserts the `exception` is raised during `function` execution with the expected message.

  ## Examples

      assert_raise ArithmeticError, "bad argument in arithmetic expression", fn ->
        1 + "test"
      end
  """
  def assert_raise(exception, expected_message, function) do
    error = assert_raise(exception, function)
    assert error.message == expected_message
    error
  end

  @doc """
  Asserts the `exception` is raised during `function` execution.

  ## Examples

      assert_raise ArithmeticError, fn ->
        1 + "test"
      end

  """
  def assert_raise(exception, function) do
    try do
      function.()
      flunk "Expected #{inspect exception} exception but nothing was raised"
    rescue
      error in [exception] -> error
      error ->
        name = error.__record__(:name)

        if name == ExUnit.AssertionError do
          raise(error)
        else
          flunk "Expected exception #{inspect exception}, got #{inspect name}"
        end
    end
  end

  @doc """
  Asserts the `enum` collection is empty.

  ## Examples

      assert_empty []
      assert_empty [1, 2]

  """
  def assert_empty(enum, message // nil) do
    message = message || "Expected #{inspect enum} to be empty"
    assert Enum.empty?(enum), message
  end

  @doc """
  Asserts the `value` is nil.

  """
  def assert_nil(value, message // nil) do
    message = message || "Expected #{inspect value} to be nil"
    assert value == nil, message
  end

  @doc """
  Asserts the `expected` and `received` are within `delta`.

  ## Examples

      assert_in_delta 1.1, 1.5, 0.2
      assert_in_delta 10, 15, 4

  """
  def assert_in_delta(expected, received, delta, message // nil) do
    diff = abs(expected - received)
    message = message ||
      "Expected |#{inspect expected} - #{inspect received}| (#{inspect diff}) to be < #{inspect delta}"
    assert diff < delta, message
  end

  @doc """
  Asserts the throw `expected` during `function` execution.

  ## Examples

      assert_throw 1, fn ->
        throw 1
      end

  """
  def assert_throw(expected, function) do
    assert_catch(:throw, expected, function)
  end

  @doc """
  Asserts the exit `expected` during `function` execution.

  ## Examples

      assert_exit 1, fn ->
        exit 1
      end

  """
  def assert_exit(expected, function) do
    assert_catch(:exit, expected, function)
  end

  @doc """
  Asserts the error `expected` during `function` execution.

  ## Examples

      assert_error :function_clause, fn ->
        List.flatten(1)
      end

  """
  def assert_error(expected, function) do
    assert_catch(:error, expected, function)
  end

  defp assert_catch(expected_type, expected_value, function) do
    try do
      function.()
      flunk "Expected #{expected_type} #{inspect expected_value}, got nothing"
    catch
      ^expected_type, ^expected_value ->
        expected_value
      ^expected_type, actual_value ->
        flunk "Expected #{expected_type} #{inspect expected_value}, got #{inspect actual_value}"
    end
  end

  @doc """
  Asserts the `not_expected` value is nil or false.
  In case it is a truthy value, raises the given message.

  ## Examples

      refute true, "This will obviously fail"

  """
  def refute(not_expected, message) do
    not assert(!not_expected, message)
  end

  @doc false
  defmacro refute_match(expected, received) do
    IO.puts "refute_match is deprecated in favor of refute left = right"

    quote do
      try do
        unquote(expected) = unquote(received)
        flunk "Unexpected right side #{inspect unquote(received)} match"
      rescue
        x in [MatchError] -> true
      end
    end
  end

  @doc """
  Refutes a message was not received (i.e. it is not in the current process mailbox).
  Timeout is set to 0, so there is no waiting time.

  ## Examples

      self <- :hello
      refute_received :bye

  """
  defmacro refute_received(content, message // nil) do
    binary = Macro.to_binary(content)

    quote do
      receive do
        unquote(content) -> flunk unquote(message) || "Expected to not have received message matching: #{unquote binary}"
      after
        0 -> false
      end
    end
  end

  @doc """
  Asserts the `enum` collection is not empty.

  ## Examples

      refute_empty []
      refute_empty [1, 2]

  """
  def refute_empty(enum, message // nil) do
    message = message || "Expected #{inspect enum} to not be empty"
    refute Enum.empty?(enum), message
  end

  @doc """
  Asserts the `value` is not nil.
  """
  def refute_nil(value, message // nil) do
    message = message || "Expected #{inspect value} to not be nil"
    refute value == nil, message
  end

  @doc """
  Asserts the `expected` and `received` are not within `delta`.

  ## Examples

      refute_in_delta 1.1, 1.2, 0.2
      refute_in_delta 10, 11, 2

  """
  def refute_in_delta(expected, received, delta, message // nil) do
    diff = abs(expected - received)
    message = message ||
      "Expected |#{inspect expected} - #{inspect received}| (#{inspect diff}) to not be < #{inspect delta}"
    refute diff < delta, message
  end

  def refute_member(base, container, message // nil) do
    IO.puts "refute_member is deprecated in favor of refute left in right"
    message = message || "Expected #{inspect container} to not include #{inspect base}"
    refute(Enum.find(container, &1 == base), message)
  end

  @doc """
  Fails with a message.

  ## Examples

      flunk "This should raise an error"

  """
  def flunk(message // "Epic Fail!") do
    raise ExUnit.AssertionError, message: message
  end
end