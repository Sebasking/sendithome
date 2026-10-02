defmodule ShipperDirectory.Claims.PhoneSender do
  @moduledoc """
  Delivers a claim code to a phone by SMS or voice call. The adapter is
  configured with `config :shipper_directory, :phone_sender`. It's
  `PhoneSender.Twilio` in prod and `PhoneSender.Log` in dev/test.

  The owner starts this themselves for the number on their own listing,
  so it's a transactional message, not marketing outreach.
  """

  @callback deliver(method :: :sms | :call, to :: String.t(), code :: String.t()) ::
              :ok | {:error, term()}

  def deliver(method, to, code), do: adapter().deliver(method, to, code)

  defp adapter,
    do:
      Application.get_env(
        :shipper_directory,
        :phone_sender,
        ShipperDirectory.Claims.PhoneSender.Log
      )
end
