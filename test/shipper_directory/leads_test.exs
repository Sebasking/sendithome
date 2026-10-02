defmodule ShipperDirectory.LeadsTest do
  use ShipperDirectory.DataCase, async: false

  import ShipperDirectory.Fixtures
  import Swoosh.TestAssertions

  alias ShipperDirectory.{Directory, Leads}
  alias ShipperDirectory.Leads.Ledger

  setup do
    Application.put_env(:shipper_directory, :lead_price_cents, 1500)
    on_exit(fn -> Application.put_env(:shipper_directory, :lead_price_cents, 0) end)
  end

  test "only published, claimed, opted-in companies are eligible" do
    yes = company(%{name: "Yes", owner: "yes@example.com"})
    unclaimed = company(%{name: "Unclaimed"})

    opted_out =
      company(%{name: "Out", owner: "out@example.com"}) |> Directory.set_accepts_leads!(false)

    company(%{name: "Prospect", owner: "p@example.com"})
    |> Directory.set_company_status!(:prospect)

    assert Enum.map(Leads.eligible("brooklyn", "guyana"), & &1.id) == [yes.id]
    assert Leads.eligible("brooklyn", "jamaica") == []
    refute Leads.eligible?(unclaimed)
    refute Leads.eligible?(opted_out)
  end

  test "submit sends to the chosen shippers, prices each delivery, and stores consent naming them" do
    a = company(%{name: "Alpha Shipping", owner: "alpha@example.com"})
    b = company(%{name: "Beta Cargo", owner: "beta@example.com"})

    {:ok, lead} = Leads.submit(lead_params(), [a.id, b.id], source_path: "/quote")

    assert lead.consent_text =~ "Alpha Shipping and Beta Cargo may contact me"
    assert lead.consented_at
    assert lead.normalized_phone == "3475550101"

    lead = Ash.load!(lead, :deliveries)
    assert [1500, 1500] = Enum.map(lead.deliveries, & &1.price_cents)

    assert Enum.sort(Enum.map(lead.deliveries, & &1.sent_to)) == [
             "alpha@example.com",
             "beta@example.com"
           ]

    assert_email_sent(to: "alpha@example.com", subject: "New quote request: Brooklyn → Guyana")
    assert_email_sent(to: "beta@example.com")
    assert_email_sent(to: "marcia@example.com", subject: "Your shipping request was sent")
  end

  test "rejects ineligible companies, none, or too many" do
    eligible = for i <- 1..4, do: company(%{name: "E#{i}", owner: "e#{i}@example.com"})
    unclaimed = company(%{name: "Unclaimed"})

    assert {:error, :ineligible_company} = Leads.submit(lead_params(), [unclaimed.id])
    assert {:error, :no_companies} = Leads.submit(lead_params(), [])

    assert {:error, :too_many_companies} =
             Leads.submit(lead_params(), Enum.map(eligible, & &1.id))

    assert {:error, :ineligible_company} = Leads.submit(lead_params(), [Ecto.UUID.generate()])
  end

  test "needs an email or phone, and a known route" do
    a = company(%{owner: "a@example.com"})

    assert {:error, %Ash.Error.Invalid{}} =
             Leads.submit(lead_params(%{"email" => "", "phone" => ""}), [a.id])

    assert {:error, %Ash.Error.Invalid{}} =
             Leads.submit(lead_params(%{"destination" => "atlantis"}), [a.id])

    assert_no_email_sent()
  end

  test "honeypot submissions are accepted silently and dropped" do
    a = company(%{owner: "a@example.com"})
    assert {:ok, :ignored} = Leads.submit(lead_params(%{"website" => "http://spam"}), [a.id])
    assert Directory.recent_leads!() == []
    assert_no_email_sent()
  end

  test "at most 3 requests per contact per day" do
    a = company(%{owner: "a@example.com"})
    for _ <- 1..3, do: assert({:ok, _} = Leads.submit(lead_params(), [a.id]))
    assert {:error, :rate_limited} = Leads.submit(lead_params(%{"email" => ""}), [a.id])
  end

  test "ledger totals billable deliveries per company, excluding credited and free" do
    a = company(%{name: "Alpha", owner: "a@example.com"})
    b = company(%{name: "Beta", owner: "b@example.com"})
    {:ok, _} = Leads.submit(lead_params(), [a.id, b.id])
    {:ok, lead} = Leads.submit(lead_params(%{"email" => "x@example.com", "phone" => ""}), [a.id])

    [delivery] = Ash.load!(lead, :deliveries).deliveries

    delivery
    |> Directory.owner_update_lead_delivery!(%{status: :disputed, dispute_reason: "spam"})
    |> Directory.resolve_dispute!(true)

    Application.put_env(:shipper_directory, :lead_price_cents, 0)
    {:ok, _} = Leads.submit(lead_params(%{"email" => "free@example.com", "phone" => ""}), [b.id])

    assert [
             %{company: %{name: "Alpha"}, count: 1, total_cents: 1500},
             %{company: %{name: "Beta"}, count: 1, total_cents: 1500}
           ] =
             Ledger.for_month(Date.utc_today())

    assert Ledger.for_month(Date.add(Date.utc_today(), -40)) == []
  end

  test "removing an owner turns leads off" do
    a = company(%{owner: "a@example.com"})
    refute a |> Directory.remove_owner!() |> Leads.eligible?()
  end
end
