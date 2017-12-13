defmodule Bank.Server do
  require Logger
  alias Bank.Models.{Account, Transaction}

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

  def start_link(_args \\ []) do
    Task.start_link(fn -> loop(%State{}) end)
  end

  # Server implementation
  defp loop(%State{} = state) do
    receive do
      {:stop, reason} ->
        Logger.warn("Process stopped, reasion is: #{inspect(reason)}")

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
      {:reply, ^request_ref, ^current_pid, response} -> {:ok, response}
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
      account
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

  def find_client_by_prop(clients, prop, value) do
    entry =
      clients
      |> Map.to_list()
      |> Enum.find(fn {_, client} -> Map.get(client, prop) == value end)

    case entry do
      nil -> nil
      {_, client} -> client
    end
  end
end