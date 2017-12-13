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
      defstruct entries: [], comment: String.t

      @type t :: %Transaction{
        entries: [AccountingEntry.t]
      }
    end
    defmodule Account do
      defstruct id: -1, name: "", amount: 0, history: []

      @type t :: %Account{
        id: integer(),
        secret: reference(),
        name: String.t(),
        amount: integer(),
        history: [AccountingEntry.t],
      }
    end
    defstruct clients: %{}, history: [],
    @type t :: %State{
      clients: %{
        optional(integer()) => Account.t
      },
      history: [Transaction.t()]
    }
  end
end
