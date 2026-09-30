defmodule ShipperDirectory.Workers.GoogleLookupWorker do
  @moduledoc "Looks one company up on Google Places. Runs on the rate-limited :google queue."
  use Oban.Worker,
    queue: :google,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:company_id], states: :incomplete]

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Discovery.GooglePlaces

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"company_id" => id}}) do
    with {:ok, company} <- Directory.get_company(id),
         {:ok, _company} <- GooglePlaces.enrich(company) do
      :ok
    else
      {:error, :missing_api_key} -> {:cancel, "GOOGLE_PLACES_API_KEY is not set"}
      {:error, %Ash.Error.Invalid{}} -> {:cancel, :company_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Queues a lookup for every confirmed company without a website that hasn't been looked up."
  def enqueue_pending do
    Directory.companies_needing_google_lookup!()
    |> Enum.map(&new(%{company_id: &1.id}))
    |> Oban.insert_all()
  end
end
