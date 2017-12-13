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

  def start_link(_args) do
    Task.start_link(fn -> loop(%State{}) end)
  end

  def stop(pid) do
    send(pid, {:stop, :normal})
  end
  
  def create_account(pid, name) do
    send(pid, {:message, self(), {:create_account, name}})
    :ok
  end

  defp loop(state) do
    receive do
      {:stop, :normal} ->
        {:stop, :normal}
      {:stop, reason} ->
        exit(reason)
      {:message, source, message} ->
        case handle_message(message, state) do
          {reply, new_state} ->
            send(source, reply)
            loop(new_state)
          new_state -> 
            loop(new_state)
        end
      _ ->
        Logger.warn("Receive unexpected message, just ignore it")
        loop(state)
    end
  end

  def handle_message(
    {:create_account, name},
    state = %{clients: clients}
  ) do
    id = case Map.keys(clients) do
      [] -> 1
      ids -> ids |> Enum.max() |> Kernel.+(1)
    end
    account = %State.Account{id: id, name: name, secret: make_ref()}
    {{:account_created, account}, put_in(state.clients, Map.put(clients, id, account))}
  end
end
