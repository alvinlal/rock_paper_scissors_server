# Requirements
# 1. should be able to monitor a process
# 2. should be able to demonitor a process

defmodule RockPaperScissors.TerminatorTest do
  use ExUnit.Case, async: true
  alias RockPaperScissors.Terminator

  test "should be able to monitor a process" do
    pid = spawn(&test_process/0)
    res = Terminator.monitor(pid, {__MODULE__, :send_to_self, [self()]})
    assert res == :ok
    Process.exit(pid, :shutdown)
    assert_receive :ok, 3000
  end

  test "should be able to demonitor a process" do
    pid = spawn(&test_process/0)
    Terminator.monitor(pid, {__MODULE__, :send_to_self, [self()]})
    Terminator.demonitor(pid)
    Process.exit(pid, :shutdown)
    refute_receive :ok
  end

  # Helpers
  def send_to_self(pid) do
    send(pid, :ok)
  end

  defp test_process() do
    receive do
      {From, Ref, Msg} -> send(From, {Ref, Msg})
    end
  end
end
