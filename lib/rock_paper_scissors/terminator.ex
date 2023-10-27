defmodule RockPaperScissors.Terminator do
  use GenServer
  require Logger

  ## Client API
  def monitor(pid, mfa) do
    GenServer.call(Terminator, {:monitor, pid, mfa})
  end

  def demonitor(pid) do
    GenServer.call(Terminator, {:demonitor, pid})
  end

  ## Server API
  def start_link(args) do
    Logger.info("started terminator")
    GenServer.start_link(__MODULE__, args, name: Terminator)
  end

  @impl true
  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %{channels: Map.new()}}
  end

  @impl true
  def handle_call({:monitor, pid, mfa}, _from, state) do
    Process.link(pid)
    {:reply, :ok, put_channel(state, pid, mfa)}
  end

  @impl true
  def handle_call({:demonitor, pid}, _from, state) do
    case Map.fetch(state.channels, pid) do
      :error ->
        {:reply, :ok, state}

      {:ok, _mfa} ->
        Process.unlink(pid)
        {:reply, :ok, drop_channel(state, pid)}
    end
  end

  @impl true
  def handle_info({:EXIT, pid, _reason}, state) do
    case Map.fetch(state.channels, pid) do
      :error ->
        {:noreply, state}

      {:ok, {mod, func, args}} ->
        Task.start_link(fn -> apply(mod, func, args) end)
        {:noreply, drop_channel(state, pid)}
    end
  end

  defp drop_channel(state, pid) do
    %{state | channels: Map.delete(state.channels, pid)}
  end

  defp put_channel(state, pid, mfa) do
    %{state | channels: Map.put(state.channels, pid, mfa)}
  end
end
