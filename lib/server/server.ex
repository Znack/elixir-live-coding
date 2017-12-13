defmodule Bank.Server do
  require Logger

  defmodule State do
    defmodule AccountingEntry do
      defstruct amount: 0, date: nil

      @type t :: %AccountingEntry{
        amount: integer(),
        date: DateTime.t(),
      }
    end
    defmodule Transaction do
      defstruct entries: [], comment: ""

      @type t :: %Transaction{
        entries: [AccountingEntry.t],
        comment: String.t,
      }
    end
    defmodule Account do
      defstruct id: -1, name: "", secret: nil, amount: 0, history: []

      @type t :: %Account{
        id: integer(),
        secret: reference(),
        name: String.t(),
        amount: integer(),
        history: [AccountingEntry.t],
      }
    end

    defstruct clients: %{}, history: []
    @type t :: %State{
      clients: %{
        optional(integer()) => Account.t
      },
      history: [Transaction.t()]
    }
  end

  # Public API
  def create_account(pid, name) do
    send(pid, {:message, {:create_account, name}, self()})
    :ok
  end

  def account_request(pid, property) do
    send(pid, {:message, {:account_request, property}, self()})
    :ok
  end

  def start_link(_args \\ []) do
    Task.start_link(fn -> loop(%State{}) end)
  end

  # Server implementation
  defp loop(%State{} = state) do
    receive do
      {:stop, reason} -> Logger.warn("Process stopped, reasion is: #{inspect(reason)}")
      {:message, msg, from} -> msg |> handle_message(state, from) |> loop
      _ ->
        Logger.warn("Unexpected message for server, ignoring it...")
        loop(state)
    end
  end

  defp handle_message({:create_account, name}, state = %State{clients: cur_clients}, from) do
    id = case cur_clients do
      clients when clients == %{} -> 1
      clients -> clients |> Map.keys |> Enum.max |> Kernel.+(1)
    end
    account = %State.Account{id: id, secret: make_ref(), name: name}

    send(from, {:account_created, account})

    %State{
      state |
      clients: Map.put_new(state.clients, id, account)
    }
  end

  defp handle_message({:account_request, name}, state = %State{clients: clients}, from) when is_bitstring(name) do
    send(from, {:account_request, find_client_by_prop(clients, :name, name)})
    state
  end

  defp handle_message({:account_request, secret}, state = %State{clients: clients}, from) when is_reference(secret) do
    send(from, {:account_request, find_client_by_prop(clients, :secret, secret)})
    state
  end

  def find_client_by_prop(clients, prop, value) do
    entry = clients
    |> Map.to_list
    |> Enum.find(fn {_, client} -> Map.get(client, prop) == value end)

    case entry do
      nil -> nil
      {_, client} -> client
    end
  end
end
