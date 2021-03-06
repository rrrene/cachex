defmodule CachexTest.Hook do
  use PowerAssert

  import ExUnit.CaptureLog

  @testhost Cachex.Util.create_node_name("cachex_test")

  setup do
    { :ok, name: String.to_atom(TestHelper.gen_random_string_of_length(16)) }
  end

  test "hooks can fire a synchronous pre-notification", state do
    hooks = %Cachex.Hook{
      args: self(),
      async: false,
      max_timeout: 250,
      module: CachexTest.Hook.TestHook,
      type: :pre
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])

    { sync_time, _res } = :timer.tc(fn ->
      Cachex.get(state.name, "sync_pre_hook")
    end)

    assert(sync_time > 20000)
  end

  test "hooks can fire an asynchronous pre-notification", state do
    hooks = %Cachex.Hook{
      args: self(),
      async: true,
      max_timeout: 250,
      module: CachexTest.Hook.TestHook,
      type: :pre
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])

    { async_time, _res } = :timer.tc(fn ->
      Cachex.get(state.name, "async_pre_hook")
    end)

    assert(async_time < 125)
  end

  test "hooks can time out a synchronous notification", state do
    hooks = %Cachex.Hook{
      args: self(),
      async: false,
      module: CachexTest.Hook.TestHook,
      type: :pre
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])

    { sync_time, _res } = :timer.tc(fn ->
      Cachex.get(state.name, "sync_pre_hook")
    end)

    assert(sync_time > 5000 && sync_time < 7500)
  end

  test "hooks with synchronous notifications have minimal overhead", state do
    hooks = %Cachex.Hook{
      args: self(),
      async: false,
      module: CachexTest.Hook.TestHook,
      type: :pre
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])

    { sync_time, _res } = :timer.tc(fn ->
      Cachex.get(state.name, "fast_sync_hook")
    end)

    assert(sync_time < 125)
  end

  test "hooks can handle old messages in synchronous hooks", state do
    hooks = %Cachex.Hook{
      args: state.name,
      async: false,
      module: CachexTest.Hook.TestHook,
      type: :pre
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])

    { sync_time, _res } = :timer.tc(fn ->
      Cachex.get(state.name, "sync_double_hook")
    end)

    assert(sync_time > 5000 && sync_time < 7500)
  end

  test "hooks with results attached in a pre-hook", state do
    hooks = %Cachex.Hook{
      args: self(),
      async: false,
      module: CachexTest.Hook.TestHook,
      results: true,
      type: :pre
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])
    Cachex.get(state.name, "key_without_results")

    wait_for("key_without_results")
  end

  test "hooks with results attached in a post-hook", state do
    hooks = %Cachex.Hook{
      args: self(),
      async: false,
      module: CachexTest.Hook.TestHook,
      results: true,
      type: :post
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])
    Cachex.get(state.name, "key_with_results")

    wait_for("key_with_results")
  end

  test "hooks can be provisioned with a worker", state do
    hook_mod = CachexTest.Hook.ModifyTestHook

    hooks = %Cachex.Hook{
      args: %{},
      module: hook_mod,
      provide: :worker,
      type: :pre
    }

    Cachex.start_link([ name: state.name, hooks: hooks ])

    worker_state = Cachex.inspect!(state.name, :worker)

    hook = Cachex.Hook.hook_by_module(worker_state.options.pre_hooks, hook_mod)
    hook_state = Cachex.Hook.call(hook, :state)

    assert(worker_state == hook_state.worker)
    assert(worker_state.actions == Cachex.Worker.Local)

    add_result = Cachex.add_node(state.name, @testhost)
    assert(add_result == { :ok, true })

    worker_state = Cachex.inspect!(state.name, :worker)

    hook = Cachex.Hook.hook_by_module(worker_state.options.pre_hooks, hook_mod)
    hook_state = Cachex.Hook.call(hook, :state)

    assert(worker_state == hook_state.worker)
    assert(worker_state.actions == Cachex.Worker.Remote)
  end

  test "hooks with invalid module provided", state do
    hooks = [
      %Cachex.Hook{
        args: self(),
        async: false,
        module: CachexTest.Hook.FakeHook,
        results: true,
        server_args: [
          name: :test_multiple_hooks
        ],
        type: :post
      }
    ]

    io_output = capture_log(fn ->
      Cachex.start_link([ name: state.name, hooks: hooks ])
    end)

    chunks = String.split(io_output, "\n")

    error = Enum.at(chunks, 1)
    line = Enum.at(chunks, 2)
    context = Enum.at(chunks, 3)

    expected_pattern = ~r/Unable to assign hook \(uncaught error\): %UndefinedFunctionError{arity: 1, function: :__info__, module: CachexTest\.Hook\.FakeHook, reason: nil}/
    assert(String.match?(error, expected_pattern))

    expected_pattern = ~r/    CachexTest\.Hook\.FakeHook\.__info__\(:module\)/
    assert(String.match?(line, expected_pattern))

    expected_pattern = ~r/    \(cachex\) lib\/cachex\/hook\.ex:\d+: Cachex.Hook.verify_hook\/1/
    assert(String.match?(context, expected_pattern))
  end

  defp wait_for(msg, timeout \\ 5) do
    receive do
      ^msg -> nil
    after
      timeout -> raise "Message not received in time: #{msg}"
    end
  end

end

defmodule CachexTest.Hook.TestHook do
  use Cachex.Hook

  def handle_notify({ :get, "async_pre_hook", _options }, state) do
    :timer.sleep(100)
    { :ok, state }
  end

  def handle_notify({ :get, "sync_pre_hook", _options }, state) do
    :timer.sleep(100)
    { :ok, state }
  end

  def handle_notify({ :get, "sync_double_hook", _options }, state) do
    send(state, { :ack, self, 1111 })
    :timer.sleep(100)
    { :ok, state }
  end

  def handle_notify({ :get, "key_without_results", _options }, state) do
    { :ok, send(state, "key_without_results") }
  end

  def handle_notify(_missing, state) do
    { :ok, state }
  end

  def handle_notify({ :get, "key_with_results", _options }, _results, state) do
    { :ok, send(state, "key_with_results") }
  end

  def handle_notify(_missing, _results, state) do
    { :ok, state }
  end

end

defmodule CachexTest.Hook.SecondTestHook do
  use Cachex.Hook

  def handle_notify(_missing, state) do
    IO.inspect("TEST #{__MODULE__}")
    { :ok, state }
  end

end

defmodule CachexTest.Hook.ModifyTestHook do
  use Cachex.Hook

  def handle_info({ :provision, { :worker, worker } }, state) do
    { :ok, Map.put(state, :worker, worker) }
  end

  def handle_call(:state, state) do
    { :ok, state, state }
  end

end
