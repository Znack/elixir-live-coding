defmodule Bank.Server do
  require Logger
  alias Bank.Models.{AccountingEntry, Transaction, Cash, Account}
  defmodule State do
    defstruct clients: %{}, cash: %Cash{}, history: []
    @type t :: %State{
      clients: %{
        optional(integer()) => Account.t()
      },
      cash: Cash.t(),
      history: [Transaction.t()]
    }
  end

  ## Public Owner API
  def start_link(_args) do
    Task.start_link(fn -> loop(%State{}) end)
  end

  def stop(pid) do
    send(pid, {:stop, :normal})
  end

  ## Public Client API
  def create_account(pid, name) do
    call(pid, {:create_account, name})
  end

  def account_request(pid, secret) do
    call(pid, {:account_request, secret})
  end

  def make_deposit(pid, to: id, amount: amount) do
    call(pid, {:make_deposit, id, amount})
  end

  def send_payment(pid, from: from, to: to, amount: amount) do
    call(pid, {:make_deposit, from, to, amount})
  end

  ## Private Server Implementation
  defp loop(state = %State{}) do
    receive do
      {:stop, :normal} -> {:stop, :normal}
      {:stop, reason} -> exit(reason)
      {:handle_message, {ref, from}, message} ->
        case handle_message(message, state) do
          {:reply, response, new_state} ->
            send(from, {:reply, {ref, from}, response})
            loop(new_state)
          {:noreply, new_state} ->
            loop(new_state)
        end
      other ->
        Logger.info("Unrecognized message received #{inspect other}")
        loop(state)
    end
  end

  defp call(pid, message) do
    ref = make_ref()
    current_pid = self()
    send(pid, {:handle_message, {ref, current_pid}, message})
    receive do
      {:reply, {^ref, ^current_pid}, reply} -> reply
    end
  end


  # Private message handlers
  defp handle_message(
    {:create_account, name}, 
    state = %State{
      clients: clients,
    }
  ) do
    id = case Map.keys(clients) do
      [] -> 1
      ids -> ids |> Enum.max() |> Kernel.+(1)
    end
    account = %Account{
      id: id, name: name, secret: make_ref()
    }
    new_state = %{state |
      clients: Map.put(clients, id, account)
    }
    {:reply, {:ok, account}, new_state}
  end

  defp handle_message(
    {:account_request, secret},
    state
  ) do
    case find_account(secret, state) do
      nil -> {:reply, {:ok, nil}, state}
      account when is_map(account) -> {:reply, {:ok, account}, state}
    end
  end

  defp handle_message(
    {:make_deposit, to, amount},
    state = %State{
      clients: clients,
      cash: cash, 
    }
  ) do
    case Map.get(clients, to) do
      nil -> {:reply, {:deposit_error, :account_not_found}, state}
      account = %Account{} -> 
        now = DateTime.utc_now()
        new_account = add_entry_to_account(account, amount, now)
        new_cash = add_entry_to_account(cash, -amount, now)
        new_state = %{state |
          cash: new_cash,
          clients: Map.put(clients, to, new_account)
        }
        {:reply, {:ok, new_account}, new_state}
    end
  end

  defp handle_message(
    {:make_deposit, from, to, amount},
    state = %State{
      clients: clients,
    }
  ) do
    case {Map.has_key?(clients, from), Map.has_key?(clients, to)} do
      {true, true} -> 
        now = DateTime.utc_now()
        new_from_account = clients
          |> Map.get(from) 
          |> add_entry_to_account(-amount, now)
        case new_from_account.amount do
          balance when balance < 0 ->
            {:reply, {:deposit_error, :insufficient_amount} , state}
          _ ->
            new_to_account = clients
              |> Map.get(to) 
              |> add_entry_to_account(amount, now)
    
            new_state = %{state |
              clients: clients 
                |> Map.put(from, new_from_account)
                |> Map.put(to, new_to_account)
            }
            {:reply, {:ok, new_from_account, new_to_account}, new_state}
        end
      _ -> {:reply, {:deposit_error, :account_not_found}, state}
    end
  end

  defp find_account(
    secret, 
    %State{clients: clients}
  ) when is_reference(secret) do
    Map.values(clients) |> Enum.find(&(&1.secret == secret))
  end

  defp add_entry_to_account(account, amount, now) do
    %{account |
      amount: account.amount + amount,
      history: [%AccountingEntry{amount: amount, date: now} | account.history],
    }
  end
end

