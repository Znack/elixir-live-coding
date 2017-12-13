defmodule Bank.Server do
  require Logger
  alias Bank.Models.{Account, Transaction, AccountingEntry}

  defmodule State do
    defstruct clients: %{}, history: []

    @type t :: %State{
            clients: %{
              optional(integer()) => Account.t()
            },
            history: [Transaction.t()]
          }
  end

  # Public API
  def create_account(pid, name) do
    call(pid, {:create_account, name})
  end

  def account_request(pid, property) do
    call(pid, {:account_request, property})
  end

  def make_deposit(pid, [to: to, amount: amount]) do
    call(pid, {:make_deposit, to, amount})
  end

  def send_payment(pid, [from: from, to: to, amount: amount]) do
    call(pid, {:send_payment, from, to, amount})
  end

  def start_link(_args \\ []) do
    Task.start_link(fn -> loop(%State{}) end)
  end

  def stop(pid) do
    send(pid, {:stop, :normal})
  end

  # Server implementation
  defp loop(%State{} = state) do
    receive do
      {:stop, :normal} -> exit(:normal)
      {:stop, reason} -> Logger.warn("Process stopped, reasion is: #{inspect(reason)}")

      {:message, {req_ref, from_pid}, msg, from} ->
        case handle_call(msg, state, from) do
          {:reply, state, resp} ->
            send(from_pid, {:reply, req_ref, from_pid, resp})
            loop(state)
          {:noreply, state} -> loop(state)
        end
      message ->
        Logger.warn("Unexpected message for server: #{inspect(message)}, ignoring it...")
        loop(state)
    end
  end

  defp call(pid, payload) do
    current_pid = self()
    request_ref = make_ref()

    send(pid, {:message, {request_ref, current_pid}, payload, current_pid})

    receive do
      {:reply, ^request_ref, ^current_pid, response} -> response
    end
  end

  defp handle_call({:create_account, name}, state = %State{clients: cur_clients}, from) do
    id =
      case cur_clients do
        clients when clients == %{} -> 1
        clients -> clients |> Map.keys() |> Enum.max() |> Kernel.+(1)
      end

    account = %Account{id: id, secret: make_ref(), name: name}

    send(from, {:account_created, account})

    {
      :reply,
      %State{state | clients: Map.put_new(state.clients, id, account)},
      {:ok, account}
    }
  end

  defp handle_call({:account_request, name}, state = %State{clients: clients}, _from)
       when is_bitstring(name) do
    {:reply, state, find_client_by_prop(clients, :name, name)}
  end

  defp handle_call({:account_request, secret}, state = %State{clients: clients}, _from)
       when is_reference(secret) do
    {:reply, state, find_client_by_prop(clients, :secret, secret)}
  end

  defp handle_call({:make_deposit, to, amount}, state = %State{clients: clients}, _form) do
    case Map.get(clients, to) do
      nil -> {:reply, state, {:deposit_error, :account_not_found}}
      client ->
        {next_client, _} = add_accounting_entry(client, amount)
          {
            :reply,
            %State{state | clients: Map.put(state.clients, to, next_client)},
            {:ok, next_client}
          }
    end
  end

  defp handle_call({:send_payment, from, to, amount}, state = %State{clients: clients}, _from) do
    case {Map.get(clients, from), Map.get(clients, to)} do
      {from_client, to_client} when is_nil(from_client) or is_nil(to_client) ->
        {:reply, state, {:deposit_error, :account_not_found}}

      {%Account{amount: from_amount}, _} when from_amount < amount ->
        {:reply, state, {:deposit_error, :insufficient_amount}}

      {from_client, to_client} ->
        {next_from_client, _} = add_accounting_entry(from_client, -amount)
        {next_to_client, _} = add_accounting_entry(to_client, amount)
        {
          :reply,
          %State{state |
            clients: state.clients
              |> Map.put(from, next_from_client)
              |> Map.put(to, next_to_client)
          },
          {:ok, next_from_client, next_to_client}
        }
    end
  end

  defp add_accounting_entry(account = %Account{history: history}, amount) do
    entry = %AccountingEntry{amount: amount, date: DateTime.utc_now}
    next_account = account
    |> put_in([Access.key(:amount)], account.amount + amount)
    |> put_in(
      [Access.key(:history)],
      [entry | history]
    )

    {next_account, entry}
  end

  def find_client_by_prop(clients, prop, value) do
    entry =
      clients
      |> Map.to_list()
      |> Enum.find(fn {_, client} -> Map.get(client, prop) == value end)

    case entry do
      nil -> {:ok, nil}
      {_, client} -> {:ok, client}
    end
  end
end
