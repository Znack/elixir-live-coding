defmodule BankServerTest do
  use ExUnit.Case
  doctest Bank
  alias Bank.Server
  alias Bank.Server.State
  alias Bank.Server.State.{AccountingEntry, Transaction, Account}

  describe "start_link" do
    test "return pid of the process" do
      {:ok, pid} = Server.start_link([])
      assert is_pid(pid)
      assert Process.info(pid) != nil
    end
  end
  describe "stop" do
    test "exit process on :stop message" do
      {:ok, pid} = Server.start_link([])
      ref = Process.monitor(pid)
      {:stop, :normal} = Server.stop(pid)
      assert_receive {:DOWN, ref, :process, pid, :normal}, 10, "DOWN message expected but not got"
      assert Process.info(pid) == nil
    end
  end

  describe "create_account" do
    test "add account for the client to state and return account data" do
      {:ok, pid} = Server.start_link([])

      :ok = Server.create_account(pid, "Arkadiy")
      assert_receive {
        :account_created, %Account{id: 1, name: "Arkadiy", secret: arkadiy_ref, history: []}
      }, 100, ":account_created expected for Arkadiy but not got"

      :ok = Server.create_account(pid, "Alesha")
      assert_receive {
        :account_created, %Account{id: 2, name: "Alesha", secret: alesha_ref, history: []}
      }, 100, ":account_created expected for Alesha but not got"
    end
  end

  describe "account_request" do
    test "return existed account by secret ref" do
      {:ok, pid} = Server.start_link([])

      :ok = Server.create_account(pid, "Arkadiy")
      assert_received {
        :account_created, %Account{id: 1, name: "Arkadiy", secret: secret, history: []}
      }, ":account_created expected for Arkadiy but not got"

      :ok = Server.account_request(pid, secret)
      assert_received {
        :account_request, %Account{id: 1, secret: ^secret, name: "Arkadiy", history: []},
      }, ":accounts expected with all accounts but not got"
    end
  end

  describe "make_transaction" do
    test "allow to make a deposit" do
      {:ok, pid} = Server.start_link([])

      :ok = Server.create_account(pid, "Arkadiy")

      :ok = Server.send_payment(pid, from: :cash, to: 1, amount: 30)
      assert_received {
        :deposit_succeed, %Account{id: 1, name: "Arkadiy", secret: _, history: [entry]}
      }, ":deposit_succeed expected for Arkadiy but not got"
      assert entry.amount == 30
    end
    test "send 20 from Arkadiy to Alesha" do
      {:ok, pid} = Server.start_link([])

      :ok = Server.create_account(pid, "Arkadiy")
      :ok = Server.create_account(pid, "Alesha")
      assert_received {
        :account_created, %Account{id: 1, name: "Arkadiy", secret: arkadiy_secret, history: []}
      }, ":account_created expected for Arkadiy but not got"
      assert_received {
        :account_created, %Account{id: 2, name: "Alesha", secret: alesha_secret, history: []}
      }, ":account_created expected for Alesha but not got"

      :ok = Server.send_payment(pid, from: :cash, to: 1, amount: 30)
      :ok = Server.send_payment(pid, from: 1, to: 2, amount: 20)
      assert_received {
        :payment_succeed, 
        %Account{id: 1, name: "Arkadiy", secret: ^arkadiy_secret, history: arkadiy_history},
        %Account{id: 2, name: "Alesha", secret: ^alesha_secret, history: alesha_history},
      }, ":payment_succeed expected between Arkadiy and Alesha but not got"

      assert [%AccountingEntry{amount: 30}, %AccountingEntry{amount: -20}] = arkadiy_history
      assert [%AccountingEntry{amount: 20}] = alesha_history

      :ok = Server.account_request(pid, arkadiy_secret)
      assert_received {
        :account_request, %Account{id: 1, secret: ^arkadiy_secret, name: "Arkadiy", history: ^arkadiy_history},
      }, ":accounts expected with Arkadiy data but not got"

      :ok = Server.account_request(pid, alesha_history)
      assert_received {
        :account_request, %Account{id: 2, secret: ^alesha_secret, name: "Arkadiy", history: ^alesha_history},
      }, ":accounts expected with Arkadiy data but not got"
    end
  end
end
