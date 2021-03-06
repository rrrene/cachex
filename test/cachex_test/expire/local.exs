defmodule CachexTest.Expire.Local do
  use PowerAssert

  setup do
    { :ok, cache: TestHelper.create_cache() }
  end

  test "expire with an existing key and no ttl", state do
    set_result = Cachex.set(state.cache, "my_key", 5)
    assert(set_result == { :ok, true })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, 5 })

    ttl_result = Cachex.ttl(state.cache, "my_key")
    assert(ttl_result == { :ok, nil })

    expire_result = Cachex.expire(state.cache, "my_key", :timer.seconds(5))
    assert(expire_result == { :ok, true })

    { status, ttl } = Cachex.ttl(state.cache, "my_key")
    assert(status == :ok)
    assert_in_delta(ttl, 5000, 5)
  end

  test "expire with an existing key and an existing ttl", state do
    set_result = Cachex.set(state.cache, "my_key", 5, ttl: :timer.seconds(10))
    assert(set_result == { :ok, true })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, 5 })

    { status, ttl } = Cachex.ttl(state.cache, "my_key")
    assert(status == :ok)
    assert_in_delta(ttl, 10000, 5)

    expire_result = Cachex.expire(state.cache, "my_key", :timer.seconds(5))
    assert(expire_result == { :ok, true })

    { status, ttl } = Cachex.ttl(state.cache, "my_key")
    assert(status == :ok)
    assert_in_delta(ttl, 5000, 5)
  end

  test "expire with a missing key", state do
    expire_result = Cachex.expire(state.cache, "my_key", :timer.seconds(5))
    assert(expire_result == { :missing, false })
  end

  test "expire with async is faster than non-async", state do
    set_result = Cachex.set(state.cache, "my_key", 5)
    assert(set_result == { :ok, true })

    get_result = Cachex.get(state.cache, "my_key")
    assert(get_result == { :ok, 5 })

    { async_time, _res } = :timer.tc(fn ->
      Cachex.expire(state.cache, "my_key", :timer.seconds(10), async: true)
    end)

    { sync_time, _res } = :timer.tc(fn ->
      Cachex.expire(state.cache, "my_key", :timer.seconds(10), async: false)
    end)

    assert(async_time < sync_time / 2)
  end

end
