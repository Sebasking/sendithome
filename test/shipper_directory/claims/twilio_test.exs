defmodule ShipperDirectory.Claims.PhoneSender.TwilioTest do
  use ExUnit.Case, async: true

  alias ShipperDirectory.Claims.PhoneSender.Twilio

  setup do
    Application.put_env(:shipper_directory, :twilio,
      account_sid: "AC123",
      auth_token: "secret",
      from_number: "+15550000000"
    )

    Application.put_env(:shipper_directory, :twilio_req_options,
      plug: {Req.Test, Twilio},
      retry: false
    )

    :ok
  end

  defp capture(status) do
    test = self()

    Req.Test.stub(Twilio, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(test, {:twilio, conn.request_path, URI.decode_query(body)})
      Plug.Conn.send_resp(conn, status, "{}")
    end)
  end

  test "SMS goes to the Messages API with the code" do
    capture(201)
    assert :ok = Twilio.deliver(:sms, "+17184838006", "123456")
    assert_received {:twilio, "/2010-04-01/Accounts/AC123/Messages.json", form}
    assert %{"To" => "+17184838006", "From" => "+15550000000"} = form
    assert form["Body"] =~ "123456"
  end

  test "voice calls read the code digit by digit" do
    capture(201)
    assert :ok = Twilio.deliver(:call, "+17184838006", "123456")
    assert_received {:twilio, "/2010-04-01/Accounts/AC123/Calls.json", %{"Twiml" => twiml}}
    assert twiml =~ "1, 2, 3, 4, 5, 6"
  end

  test "errors surface" do
    capture(400)
    assert {:error, {:twilio, 400, _}} = Twilio.deliver(:sms, "+17184838006", "123456")
  end
end
