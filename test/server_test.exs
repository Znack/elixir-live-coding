defmodule BankServerTest do
  use ExUnit.Case
  doctest Bank
  alias Bank.Server
  alias Bank.Server.{AccountingEntry, Account}

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
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 10, "DOWN message expected but not got"
      assert Process.info(pid) == nil
    end
  end

  describe "create_account" do
    test "add account for the client to state and return account data" do
      {:ok, pid} = Server.start_link([])

      {:ok, arkadiy} = Server.create_account(pid, "Arkadiy")
      assert %Account{
        id: 1,
        name: "Arkadiy",
        secret: arkadiy_ref,
        history: []
      } = arkadiy
      assert is_reference(arkadiy_ref)

      {:ok, %Account{
        id: 2,
        name: "Alesha",
        secret: alesha_ref,
        history: []
      }} = Server.create_account(pid, "Alesha")
      assert is_reference(alesha_ref)
    end
  end

  describe "account_request" do
    test "return existed account by secret ref" do
      {:ok, pid} = Server.start_link([])

      {:ok, %Account{secret: secret}} = Server.create_account(pid, "Arkadiy")

      {:ok, account} = Server.account_request(pid, secret)
      assert %Account{id: 1, secret: ^secret, name: "Arkadiy", history: []} = account
    end
    test "return nil if account doesnt exists" do
      {:ok, pid} = Server.start_link([])
      {:ok, nil} = Server.account_request(pid, make_ref())
    end
  end

  describe "make_deposit" do
    test "allow to make a deposit" do
      {:ok, pid} = Server.start_link([])

      {
        :ok,
        %Account{id: 1, name: "Arkadiy", secret: secret, history: []},
      } = Server.create_account(pid, "Arkadiy")

      {:ok, deposit_reply} = Server.make_deposit(pid, to: 1, amount: 30)
      assert %Account{id: 1, amount: 30, history: [_]} = deposit_reply
      assert [%AccountingEntry{amount: 30}] = deposit_reply.history

      {:ok, arkadiy_account} = Server.account_request(pid, secret)

      assert %Account{
        id: 1, secret: ^secret, amount: 30, name: "Arkadiy", history: [_]
      } = arkadiy_account
    end
    test "error if account doesn't exists" do
      {:ok, pid} = Server.start_link([])

      {:deposit_error, :account_not_found} = Server.make_deposit(pid, to: 1, amount: 30)
    end
  end
  describe "send_payment" do
    test "send 20 from Arkadiy to Alesha" do
      {:ok, pid} = Server.start_link([])

      {:ok, %Account{secret: arkadiy_secret}} = Server.create_account(pid, "Arkadiy")
      {:ok, %Account{secret: alesha_secret}} = Server.create_account(pid, "Alesha")

      {:ok, _} = Server.make_deposit(pid, to: 1, amount: 30)
      {:ok, from, to} = Server.send_payment(pid, from: 1, to: 2, amount: 20)

      assert %Account{
        id: 1, name: "Arkadiy", secret: ^arkadiy_secret, history: arkadiy_history
      } = from
      assert %Account{
        id: 2, name: "Alesha", secret: ^alesha_secret, history: alesha_history
      } = to

      assert [%AccountingEntry{amount: -20}, %AccountingEntry{amount: 30}] = arkadiy_history
      assert [%AccountingEntry{amount: 20}] = alesha_history

      {:ok, arkadiy_account} = Server.account_request(pid, arkadiy_secret)
      assert %Account{
        id: 1, secret: ^arkadiy_secret, name: "Arkadiy", history: ^arkadiy_history
      } = arkadiy_account

      {:ok, alesha_account} = Server.account_request(pid, alesha_secret)
      assert %Account{
        id: 2, secret: ^alesha_secret, name: "Alesha", history: ^alesha_history
      } = alesha_account
    end
    test "error if account doesn't exists" do
      {:ok, pid} = Server.start_link([])

      {:deposit_error, :account_not_found} = Server.send_payment(pid, from: 1, to: 2, amount: 20)
    end
    test "error if account has no enough money" do
      {:ok, pid} = Server.start_link([])
      {:ok, _} = Server.create_account(pid, "Arkadiy")
      {:ok, _} = Server.create_account(pid, "Alesha")
      response = Server.send_payment(pid, from: 1, to: 2, amount: 20)
      assert {:deposit_error, :insufficient_amount} = response
    end
  end
end
