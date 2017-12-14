defmodule Bank.Server do
  require Logger
  alias Bank.Models.{AccountingEntry, Cash, Account}
  defmodule State do
    defstruct clients: %{}, cash: %Cash{}, history: []
    @type t :: %State{
      clients: %{
        optional(integer()) => Account.t()
      },
      cash: Cash.t()
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

  def make_deposit(pid, to: to, amount: amount) do
  end

  def send_payment(pid, from: from, to: to, amount: amount) do
  end
end
