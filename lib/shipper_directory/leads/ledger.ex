defmodule ShipperDirectory.Leads.Ledger do
  @moduledoc """
  Monthly pay-per-lead totals per company, for invoicing. Credited
  (accepted-dispute) and free deliveries are excluded.
  """

  alias ShipperDirectory.Directory

  @doc "Rows of %{company, count, total_cents} for the calendar month containing `date`."
  def for_month(%Date{} = date) do
    from = date |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    to = date |> Date.end_of_month() |> Date.add(1) |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    Directory.billable_lead_deliveries!(from, to)
    |> Enum.group_by(& &1.company_id)
    |> Enum.map(fn {_id, [first | _] = deliveries} ->
      %{
        company: first.company,
        count: length(deliveries),
        total_cents: Enum.sum_by(deliveries, & &1.price_cents)
      }
    end)
    |> Enum.sort_by(& &1.company.name)
  end

  def parse_month(nil), do: Date.utc_today()

  def parse_month(value) do
    case Date.from_iso8601(value <> "-01") do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end
end
