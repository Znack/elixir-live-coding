defmodule BankServerTest do
  use ExUnit.Case
  doctest Bank
  alias Bank.Server
  alias Bank.Server.State

  describe "start_link" do
    test "return pid of the process" do
      {:ok, pid} = BankServer.start_link()
      assert is_pid(pid)
    end
  end
  
  describe "create_account" do
    test "add account for the client to state and return account data" do
      {:ok, pid} = BankServer.start_link()

      :ok = BankServer.create_account(pid, "Arkadiy")
      assert_received {
        :account_created, %State.Account{id: 1, name: "Arkadiy", secret: arkadiy_ref, history: []
      }, ":account_created expected for Arkadiy but not got"

      {:ok, alesha_account} = BankServer.create_account(pid, "Alesha")
      assert_received {
        :account_created, %State.Account{id: 2, name: "Alesha", secret: alesha_ref, history: []
      }, ":account_created expected for Alesha but not got"
    end
  end

  describe "account_request" do
    test "return existed account by secret ref" do
      {:ok, pid} = BankServer.start_link()

      :ok = BankServer.create_account(pid, "Arkadiy")
      assert_received {
        :account_created, %State.Account{id: 1, name: "Arkadiy", secret: secret, history: []
      }, ":account_created expected for Arkadiy but not got"

      :ok = BankServer.account_request(pid, secret)
      assert_received {
        :account_request, %State.Account{id: 1, secret: ^secret, name: "Arkadiy", history: []},
      }, ":accounts expected with all accounts but not got"
    end
  end

  describe "make_transaction" do
    test "allow to make a deposit" do
      {:ok, pid} = BankServer.start_link()

      :ok = BankServer.create_account(pid, "Arkadiy")

      :ok = BankServer.send_payment(pid, from: :cash, to: 1, amount: 30)
      assert_received {
        :deposit_succeed, %State.Account{id: 1, name: "Arkadiy", secret: _, history: [entry]}
      }, ":deposit_succeed expected for Arkadiy but not got"
      assert entry.amount == 30
    end
    test "send 20 from Arkadiy to Alesha" do
      {:ok, pid} = BankServer.start_link()

      :ok = BankServer.create_account(pid, "Arkadiy")
      :ok = BankServer.create_account(pid, "Alesha")
      assert_received {
        :account_created, %State.Account{id: 1, name: "Arkadiy", secret: arkadiy_secret, history: []
      }, ":account_created expected for Arkadiy but not got"
      assert_received {
        :account_created, %State.Account{id: 2, name: "Alesha", secret: alesha_secret, history: []
      }, ":account_created expected for Alesha but not got"

      :ok = BankServer.send_payment(pid, from: :cash, to: 1, amount: 30)
      :ok = BankServer.send_payment(pid, from: 1, to: 2, amount: 20)
      assert_received {
        :payment_succeed, 
        %State.Account{id: 1, name: "Arkadiy", secret: ^arkadiy_secret, history: arkadiy_history},
        %State.Account{id: 2, name: "Alesha", secret: ^alesha_secret, history: alesha_history},
      }, ":payment_succeed expected between Arkadiy and Alesha but not got"

      assert [%State.Entry{amount: 30}, %State.Entry{amount: -20}] = arkadiy_history
      assert [%State.Entry{amount: 20}] = alesha_history

      :ok = BankServer.account_request(pid, arkadiy_secret)
      assert_received {
        :account_request, %State.Account{id: 1, secret: ^arkadiy_secret, name: "Arkadiy", history: ^arkadiy_history},
      }, ":accounts expected with Arkadiy data but not got"

      :ok = BankServer.account_request(pid, alesha_history)
      assert_received {
        :account_request, %State.Account{id: 2, secret: ^alesha_secret, name: "Arkadiy", history: ^alesha_history},
      }, ":accounts expected with Arkadiy data but not got"
    end
  end
end
