defmodule ShipperDirectory.ClaimsTest do
  use ShipperDirectory.DataCase, async: true

  import Swoosh.TestAssertions

  alias ShipperDirectory.{Claims, Directory}
  alias ShipperDirectory.Claims.PhoneSender

  defp company(attrs \\ %{}) do
    Directory.create_company!(
      Map.merge(
        %{
          name: "FCS Shipping LLC",
          website_url: "https://www.fcsshipping.com",
          phone: "(718) 483-8006",
          status: :published
        },
        attrs
      )
    )
  end

  defp code_from_email do
    assert_received {:email, %{subject: subject}}
    [code] = Regex.run(~r/^\d{6}/, subject)
    code
  end

  test "email_matches_site?/2" do
    assert Claims.email_matches_site?("info@fcsshipping.com", "https://www.fcsshipping.com")
    assert Claims.email_matches_site?("a@mail.fcsshipping.com", "https://fcsshipping.com")
    assert Claims.email_matches_site?("a@fcsshipping.com", "https://shop.fcsshipping.com/x")
    refute Claims.email_matches_site?("fcs@gmail.com", "https://www.fcsshipping.com")
    refute Claims.email_matches_site?("a@notfcsshipping.com", "https://fcsshipping.com")
    refute Claims.email_matches_site?("a@fcsshipping.com", nil)
  end

  test "claim by email at the domain: owner assigned, sign-in link sent" do
    c = company()

    {:ok, claim} =
      Claims.start(c, %{"method" => "email", "name" => "Pat", "email" => "info@fcsshipping.com"})

    refute claim.code_hash =~ ~r/^\d{6}$/
    code = code_from_email()

    assert {:ok, %{owner_id: owner_id, claimed_at: %DateTime{}}} = Claims.verify(claim, code)
    assert owner_id

    assert_email_sent(
      to: "info@fcsshipping.com",
      subject: "Your sign-in link for SendItHome"
    )

    assert %{status: :verified, user_id: ^owner_id} = Directory.get_claim!(claim.id)
    refute Claims.claimable?(Directory.get_company!(c.id))
  end

  test "claim by phone call uses the listed number, signs in with any email" do
    c = company()

    {:ok, claim} =
      Claims.start(c, %{"method" => "call", "name" => "Pat", "email" => "pat@gmail.com"})

    assert claim.destination == "+17184838006"
    code = PhoneSender.Log.last_code("+17184838006")

    assert {:ok, _} = Claims.verify(claim, code)
    assert_email_sent(to: "pat@gmail.com")
  end

  test "email method rejects addresses not at the company's domain" do
    c = company()

    assert {:error, :email_not_at_domain} =
             Claims.start(c, %{"method" => "email", "name" => "Pat", "email" => "fcs@gmail.com"})

    assert {:error, :invalid_email} =
             Claims.start(c, %{"method" => "call", "name" => "Pat", "email" => "nope"})

    assert {:error, {:required, :name}} =
             Claims.start(c, %{"method" => "call", "name" => " ", "email" => "a@b.co"})
  end

  test "only published, unowned companies can be claimed" do
    params = %{"method" => "call", "name" => "Pat", "email" => "pat@example.com"}

    assert {:error, :not_claimable} =
             Claims.start(company(%{status: :prospect, phone: "(718) 555-0198"}), params)

    c = company(%{name: "Other", phone: "(718) 555-0199"})
    {:ok, claim} = Claims.start(c, params)
    {:ok, _} = Claims.verify(claim, PhoneSender.Log.last_code("+17185550199"))
    assert {:error, :not_claimable} = Claims.start(Directory.get_company!(c.id), params)
  end

  test "methods depend on what the listing has" do
    assert Claims.methods(company()) == [:email, :call, :sms]
    assert Claims.methods(company(%{name: "No phone", phone: nil})) == [:email]

    assert {:error, :invalid_method} =
             Claims.start(company(%{name: "B", phone: nil}), %{
               "method" => "sms",
               "name" => "P",
               "email" => "p@e.co"
             })
  end

  test "wrong codes count attempts and lock after the maximum" do
    {:ok, claim} =
      Claims.start(company(), %{"method" => "sms", "name" => "Pat", "email" => "p@e.co"})

    for n <- 1..(Claims.max_attempts() - 1) do
      assert {:error, :invalid_code} = Claims.verify(Directory.get_claim!(claim.id), "000000x")
      assert Directory.get_claim!(claim.id).attempts == n
    end

    assert {:error, :locked} = Claims.verify(Directory.get_claim!(claim.id), "000000x")

    # Even the right code is refused once locked.
    code = PhoneSender.Log.last_code("+17184838006")
    assert {:error, :locked} = Claims.verify(Directory.get_claim!(claim.id), code)
  end

  test "expired codes are refused" do
    {:ok, claim} =
      Claims.start(company(), %{"method" => "sms", "name" => "Pat", "email" => "p@e.co"})

    code = PhoneSender.Log.last_code("+17184838006")
    expired = %{claim | expires_at: DateTime.add(DateTime.utc_now(), -1, :minute)}
    assert {:error, :expired} = Claims.verify(expired, code)
  end

  test "at most 3 claims per company per hour" do
    c = company()
    params = %{"method" => "sms", "name" => "Pat", "email" => "p@e.co"}
    for _ <- 1..3, do: assert({:ok, _} = Claims.start(c, params))
    assert {:error, :rate_limited} = Claims.start(c, params)
  end
end
