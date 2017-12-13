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

  defp loop(state) do
    receive do
      {:stop, :normal} ->
        {:stop, :normal}
      {:stop, reason} ->
        exit(reason)
      _ ->
        Logger.warn("Receive unexpected message, just ignore it")
        loop(state)
    end
  end
end
