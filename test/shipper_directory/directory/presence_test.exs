defmodule ShipperDirectory.Directory.PresenceTest do
  use ShipperDirectory.DataCase, async: true

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Presence

  @filler String.duplicate("We ship barrels and boxes to the islands every week. ", 10)

  defp company(attrs) do
    Directory.create_company!(Map.merge(%{name: "Island Link Shipping"}, attrs))
  end

  defp stub_html(html, status \\ 200) do
    Req.Test.stub(Presence, fn conn ->
      conn |> Plug.Conn.put_resp_content_type("text/html") |> Plug.Conn.send_resp(status, html)
    end)
  end

  defp page(body), do: "<html><head><title>Home</title></head><body>#{body}</body></html>"

  test "none when there's no URL" do
    assert %{verdict: :none} = Presence.classify(company(%{}))
  end

  test "social_only when only social URLs are known" do
    assert %{verdict: :social_only} =
             Presence.classify(company(%{facebook_url: "https://facebook.com/islandlink"}))

    assert %{verdict: :social_only} =
             Presence.classify(
               company(%{name: "Other Co", website_url: "https://www.facebook.com/islandlink"})
             )
  end

  test "business.site URLs are dead without a request" do
    assert %{verdict: :dead_site} =
             Presence.classify(company(%{website_url: "https://islandlink.business.site"}))
  end

  test "listed when the page shows the company name" do
    stub_html(page("<h1>Island Link Shipping</h1><p>#{@filler}</p>"))
    c = company(%{website_url: "https://example.com"})
    assert %{verdict: :listed, matches_company: true, has_ssl: true} = Presence.classify(c)
  end

  test "listed when the page shows the company phone" do
    stub_html(page("<p>Call (718) 555-0100</p><p>#{@filler}</p>"))
    c = company(%{name: "Acme", website_url: "https://example.com", phone: "718-555-0100"})
    assert %{verdict: :listed, has_contact_info: true} = Presence.classify(c)
  end

  test "needs_review when the site doesn't match the company" do
    stub_html(page("<h1>Lauderdale Lakes Shipping Co</h1><p>#{@filler}</p>"))
    c = company(%{website_url: "https://example.com"})
    assert %{verdict: :needs_review, matches_company: false} = Presence.classify(c)
  end

  test "dead_site for parked domains, placeholders, and HTTP errors" do
    c = company(%{website_url: "https://example.com"})

    stub_html(page("<h1>islandlink.com</h1><p>This domain is for sale! #{@filler}</p>"))
    assert %{verdict: :dead_site, is_parked: true} = Presence.classify(c)

    stub_html(page("<h1>Island Link Shipping</h1><p>Coming soon</p>"))
    assert %{verdict: :dead_site, is_placeholder: true} = Presence.classify(c)

    stub_html("Not found", 404)
    assert %{verdict: :dead_site, http_status: 404} = Presence.classify(c)
  end

  test "a 'coming soon' feature on a real page isn't a placeholder" do
    stub_html(
      page(
        "<h1>Island Link Shipping</h1><p>Rate calculator: coming soon</p><p>#{String.duplicate(@filler, 4)}</p>"
      )
    )

    c = company(%{website_url: "https://example.com"})
    assert %{verdict: :listed, is_placeholder: false} = Presence.classify(c)
  end

  test "needs_review when the site blocks the checker" do
    stub_html("Forbidden", 403)

    assert %{verdict: :needs_review} =
             Presence.classify(company(%{website_url: "https://example.com"}))
  end

  test "dead_site on transport errors" do
    Req.Test.stub(Presence, &Req.Test.transport_error(&1, :nxdomain))

    assert %{verdict: :dead_site} =
             Presence.classify(company(%{website_url: "https://example.com"}))
  end

  describe "check/1" do
    test "publishes a listed company and records the check" do
      stub_html(page("<h1>Island Link Shipping</h1><p>#{@filler}</p>"))
      c = Presence.check(company(%{website_url: "https://example.com"}))

      assert %{presence_status: :listed, status: :published} = c
      assert c.last_checked_at
      assert [%{verdict: :listed}] = Ash.read!(ShipperDirectory.Directory.PresenceCheck)
    end

    test "demotes a published company whose site went dead" do
      stub_html("gone", 410)

      c =
        company(%{
          website_url: "https://example.com",
          status: :published,
          phone: "(718) 555-0100"
        })

      assert %{presence_status: :dead_site, status: :prospect} = Presence.check(c)
    end

    test "no website becomes a prospect only with a phone or email to reach" do
      assert %{presence_status: :none, status: :prospect} =
               Presence.check(company(%{email: "info@islandlink.example"}))

      assert %{presence_status: :none, status: :discovered, review_reason: reason} =
               Presence.check(company(%{name: "Unreachable Cargo"}))

      assert reason =~ "can't be worked as a lead"
    end

    test "held companies stay in review whatever the verdict" do
      stub_html(page("<h1>Island Link Shipping</h1><p>#{@filler}</p>"))

      c =
        company(%{
          website_url: "https://example.com",
          hold_for_review: true,
          presence_status: :needs_review
        })

      assert %{presence_status: :needs_review, status: :discovered, review_reason: reason} =
               Presence.check(c)

      assert reason =~ "listed"
    end

    test "leaves CRM statuses alone" do
      c = company(%{status: :do_not_contact})
      assert %{presence_status: :none, status: :do_not_contact} = Presence.check(c)
    end
  end
end
