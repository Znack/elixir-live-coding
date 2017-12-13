defmodule Bank.Server do
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

  defp loop(%State{} = initial) do
    state = initial # We can save it in ets, or on disk, or leave it here :)

    for _ <- Stream.cycle([:ok]) do
      Process.sleep(1000)
      {:ok, state} = iterate(state)
    end
  end

  defp iterate(%State{} = state) do
    IO.puts "Iterate"
    {:ok, state}
  end

  def create_account() do
    
  end
end
