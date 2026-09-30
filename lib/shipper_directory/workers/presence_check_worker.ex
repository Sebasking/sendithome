defmodule ShipperDirectory.Workers.PresenceCheckWorker do
  @moduledoc "Runs the presence check for one company."
  use Oban.Worker, queue: :presence, max_attempts: 3, unique: [period: 300, keys: [:company_id]]

  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.Presence

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"company_id" => id}}) do
    case Directory.get_company(id) do
      {:ok, company} ->
        Presence.check(company)
        :ok

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
        {:cancel, :company_not_found}

      {:error, error} ->
        {:error, error}
    end
  end

  def enqueue(company_id), do: %{company_id: company_id} |> new() |> Oban.insert()
end
