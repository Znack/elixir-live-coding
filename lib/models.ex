defmodule Bank.Models do
  defmodule AccountingEntry do
    defstruct amount: 0, date: nil

    @type t :: %AccountingEntry{
      amount: integer(),
      date: DateTime.t(),
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

  defmodule Cash do
    defstruct id: :cash, amount: 0, history: []

    @type t :: %Account{
      id: :cash,
      amount: integer(),
      history: [AccountingEntry.t],
    }
  end
end