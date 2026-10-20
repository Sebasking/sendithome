defmodule ShipperDirectory.Claims.PhoneSender.Twilio do
  @moduledoc """
  Sends claim codes with Twilio: SMS via the Messages API, or a voice
  call reading the code aloud (works for landlines, which many small
  shippers use). Needs TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER.
  """
  @behaviour ShipperDirectory.Claims.PhoneSender

  @impl true
  def deliver(:sms, to, code) do
    post("Messages.json",
      To: to,
      From: config(:from_number),
      Body: "Your SendItHome verification code is #{code}. It expires in 15 minutes."
    )
  end

  def deliver(:call, to, code) do
    spoken = code |> String.graphemes() |> Enum.join(", ")

    twiml =
      "<Response><Say>Your Send It Home verification code is: #{spoken}.</Say>" <>
        ~s(<Pause length="1"/><Say>Again, your code is: #{spoken}.</Say></Response>)

    post("Calls.json", To: to, From: config(:from_number), Twiml: twiml)
  end

  defp post(path, form) do
    sid = config(:account_sid)

    [
      url: "https://api.twilio.com/2010-04-01/Accounts/#{sid}/#{path}",
      auth: {:basic, "#{sid}:#{config(:auth_token)}"},
      form: form
    ]
    |> Keyword.merge(Application.get_env(:shipper_directory, :twilio_req_options, []))
    |> Req.post()
    |> case do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:twilio, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp config(key),
    do: :shipper_directory |> Application.fetch_env!(:twilio) |> Keyword.fetch!(key)
end
