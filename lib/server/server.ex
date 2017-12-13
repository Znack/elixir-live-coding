defmodule Bank.Server do
  alias Bank.Models.{AccountingEntry, Transaction, Account}
  defmodule State do
    defstruct clients: %{}, history: []
    @type t :: %State{
      clients: %{
        optional(integer()) => Account.t
      },
      history: [Transaction.t()]
    }
  end

  ## Public Owner API
  def start_link(args) do
  end

  def stop(pid) do
  end

  ## Public Client API
  def create_account(pid, name) do
  end

  def account_request(pid, ref) do
  end

  def make_deposit(pid, to: id, amount: amount) do
  end

  def send_payment(pid, from: from, to: to, amount: amount) do
  end
end
