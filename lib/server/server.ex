defmodule Bank.Server do
  require Logger
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
  defmodule Cash do
    defstruct id: :cash, amount: 0, history: []

    @type t :: %Account{
      id: :cash,
      amount: integer(),
      history: [AccountingEntry.t],
    }
  end
  defmodule State do
    defstruct clients: %{}, cash: %Cash{}, history: []
    @type t :: %State{
      clients: %{
        optional(integer()) => Account.t
      },
      cash: Cash.t, 
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
  
  def account_request(pid, ref) do
    send(pid, {:message, self(), {:account_request, ref}})
    :ok
  end
  
  def make_deposit(pid, to: id, amount: amount) do
    send(pid, {:message, self(), {:make_deposit, id, amount}})
    :ok
  end
  
  def send_payment(pid, from: from, to: to, amount: amount) do
    send(pid, {:message, self(), {:send_payment, from, to, amount}})
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

  defp handle_message(
    {:create_account, name},
    state = %{clients: clients}
  ) do
    id = case Map.keys(clients) do
      [] -> 1
      ids -> ids |> Enum.max() |> Kernel.+(1)
    end
    account = %Account{id: id, name: name, secret: make_ref()}
    {{:account_created, account}, put_in(state.clients, Map.put(clients, id, account))}
  end

  defp handle_message(
    {:account_request, ref},
    state = %{clients: clients}
  ) do
    accounts = Map.values(clients) |> Enum.filter(&(&1.secret == ref))
    {:found, account} = case accounts do
      [] ->
        {:found, nil}
      [found] ->
        {:found, found}
      other ->
        {:inconsistent_accounts, {:expected, :list_with_one_item}, {:got, other}}
    end
    {{:account_request, account}, state}
  end

  defp handle_message(
    {:make_deposit, id, amount},
    state = %{cash: cash, clients: clients}
  ) do
    case Map.has_key?(clients, id) do
      false -> {{:deposit_error, :account_not_found}, state}
      true -> 
        now = DateTime.utc_now()
        account = Map.get(clients, id)
        new_cash = update_account_with_entry(cash, now, -amount)
        new_account = update_account_with_entry(account, now, amount)
        new_state = %{state |
          clients: Map.put(clients, id, new_account),
          cash: new_cash
        }
        {{:deposit_succeed, new_account}, new_state}
    end
  end

  defp handle_message(
    {:send_payment, from_id, to_id, amount},
    state = %{clients: clients}
  ) do
    case {Map.has_key?(clients, from_id), Map.has_key?(clients, to_id)} do
      {true, true} ->
        now = DateTime.utc_now()
        from = Map.get(clients, from_id)
        to = Map.get(clients, to_id)
        case from.amount - amount > 0 do
          true -> 
            new_from = update_account_with_entry(from, now, -amount)
            new_to = update_account_with_entry(to, now, amount)
            new_state = %{state |
              clients: clients
                |> Map.put(from_id, new_from)
                |> Map.put(to_id, new_to),
            }
            {{:payment_succeed, new_from, new_to}, new_state}
          false ->
            {{:deposit_error, :insufficient_amount}, state}
        end
      _  -> {{:deposit_error, :account_not_found}, state}
    end
  end

  defp update_account_with_entry(account, date, amount) do
    %{account |
      amount: account.amount + amount,
      history: [%AccountingEntry{amount: amount, date: date} | account.history]
    }
  end
end
