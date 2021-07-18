defmodule MagikTelegramNotiTest do
  use ExUnit.Case
  require Magik.TelegramNoti

  # test "send error default conversation should pass" do
  #   data = %{}

  #   try do
  #     data.hello
  #   rescue
  #     err ->
  #       {status, _} =
  #         Magik.TelegramNoti.send_error("message to default chat", %{
  #           kind: :error,
  #           reason: err,
  #           stack: __STACKTRACE__
  #         })

  #       assert status == :ok
  #   end
  # end

  # test "send error to admin conversation should pass" do
  #   data = %{}

  #   try do
  #     data.hello
  #   rescue
  #     err ->
  #       {status, _} =
  #         Magik.TelegramNoti.send_error(:admin, "message to admin chat", %{
  #           kind: :error,
  #           reason: err,
  #           stack: __STACKTRACE__
  #         })

  #       assert status == :ok
  #   end
  # end

  # def divide(number) do
  #   Magik.TelegramNoti.watch to: :admin, label: "divide function" do
  #     10 / number
  #   end
  # end

  # test "watch should not send noti if no exception occurs" do
  #   assert 5 == divide(2)
  # end

  # test "watch should send noti if exception occurs" do
  #   assert_raise ArithmeticError, "bad argument in arithmetic expression", fn ->
  #     divide(0)
  #   end
  # end

  # def divide2(number) do
  #   Magik.TelegramNoti.watch to: :admin do
  #     10 / number
  #   end
  # end

  # @tag :wip
  # test "watch use function name as label if no label is specified" do
  #   assert_raise ArithmeticError, "bad argument in arithmetic expression", fn ->
  #     divide2(0)
  #   end
  # end
end
