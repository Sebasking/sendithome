defmodule ShipperDirectory.Crm.OutreachTest do
  use ShipperDirectory.DataCase, async: true

  import Swoosh.TestAssertions

  alias ShipperDirectory.Crm.Fit
  alias ShipperDirectory.Directory
  alias ShipperDirectory.Workers.FollowUpDigestWorker

  defp prospect(attrs \\ %{}) do
    Directory.create_company!(Map.merge(%{name: "Barrel-It", status: :prospect}, attrs))
  end

  defp log(company, attrs),
    do: Directory.log_outreach(Map.merge(%{company_id: company.id}, attrs))

  test "first touch moves prospect to contacted" do
    c = prospect()
    assert {:ok, _} = log(c, %{channel: :call, outcome: :no_answer})
    assert Directory.get_company!(c.id).status == :contacted
  end

  test "outcomes set status" do
    c = prospect()
    {:ok, _} = log(c, %{channel: :call, outcome: :not_interested})
    assert Directory.get_company!(c.id).status == :declined

    c = prospect(%{name: "B"})
    {:ok, _} = log(c, %{channel: :in_person, outcome: :customer})
    assert Directory.get_company!(c.id).status == :customer
  end

  test "suppression list: nothing can be logged after do-not-contact" do
    c = prospect()
    {:ok, _} = log(c, %{channel: :call, outcome: :do_not_contact})
    assert Directory.get_company!(c.id).status == :do_not_contact

    assert {:error, error} = log(c, %{channel: :email, outcome: :other})
    assert Exception.message(error) =~ "do-not-contact"
    refute Enum.any?(Directory.prospects!(), &(&1.id == c.id))
  end

  test "WhatsApp/SMS need an opt-in first (TCPA)" do
    c = prospect()
    assert {:error, error} = log(c, %{channel: :whatsapp, outcome: :other})
    assert Exception.message(error) =~ "opt-in"

    # The opt-in itself can be recorded, e.g. they messaged us.
    {:ok, _} =
      log(c, %{channel: :call, outcome: :opted_in_messaging, notes: "Said yes on the phone"})

    assert %{messaging_consent_note: "Said yes on the phone"} = c = Directory.get_company!(c.id)
    assert c.messaging_consent_at

    assert {:ok, _} = log(c, %{channel: :whatsapp, outcome: :interested})
  end

  test "aggregates track the latest touch and follow-up" do
    c = prospect()
    later = DateTime.add(DateTime.utc_now(), 2, :day)
    {:ok, _} = log(c, %{channel: :call, outcome: :left_message, next_action_at: later})

    c = Directory.get_company!(c.id, load: [:last_outcome, :next_action_at, :outreach_count])
    assert %{last_outcome: :left_message, outreach_count: 1} = c
    assert DateTime.compare(c.next_action_at, DateTime.truncate(later, :second)) == :eq
  end

  test "fit score explains itself" do
    c =
      prospect(%{
        phone: "718-555-0100",
        fmc_license_no: "1",
        city: "Brooklyn",
        state: "NY",
        presence_status: :dead_site
      })

    assert {7, reasons} = Fit.score(c)
    assert "+2 FMC licensed (established)" in reasons
  end

  describe "follow-up digest" do
    setup do
      Application.put_env(:shipper_directory, :admin_email, "me@example.com")
      on_exit(fn -> Application.delete_env(:shipper_directory, :admin_email) end)
    end

    test "emails due follow-ups" do
      c = prospect(%{phone: "718-555-0100"})

      {:ok, _} =
        log(c, %{channel: :call, outcome: :no_answer, next_action_at: DateTime.utc_now()})

      prospect(%{name: "Not due"})

      assert :ok = FollowUpDigestWorker.perform(%Oban.Job{})

      assert_email_sent(fn email ->
        assert email.subject == "1 follow-ups due"
        assert email.text_body =~ "Barrel-It"
        refute email.text_body =~ "Not due"
        assert email.text_body =~ "last: No answer"
      end)
    end

    test "sends nothing when nothing is due" do
      prospect()
      assert :ok = FollowUpDigestWorker.perform(%Oban.Job{})
      assert_no_email_sent()
    end
  end
end
