defmodule ShipperDirectory.Workers.FollowUpDigestWorker do
  @moduledoc """
  Daily email to ADMIN_EMAIL listing prospects whose follow-up is due
  today or overdue. Skipped when ADMIN_EMAIL isn't set or nothing is due.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  import Swoosh.Email

  alias ShipperDirectory.Claims.Emails
  alias ShipperDirectory.{Directory, Mailer}
  alias ShipperDirectory.Directory.Types.OutreachOutcome

  @impl Oban.Worker
  def perform(_job) do
    end_of_day = DateTime.new!(Date.utc_today(), ~T[23:59:59], "Etc/UTC")

    with to when is_binary(to) <- Application.get_env(:shipper_directory, :admin_email),
         [_ | _] = due <- Directory.follow_ups_due!(end_of_day) do
      to |> digest(due) |> Mailer.deliver!()
    end

    :ok
  end

  def digest(to, due) do
    lines =
      Enum.map_join(due, "\n", fn c ->
        "- #{c.name} (#{c.phone || "no phone"}), due #{Calendar.strftime(c.next_action_at, "%b %d")}, last: #{if c.last_outcome, do: OutreachOutcome.description(c.last_outcome), else: "none"}"
      end)

    new()
    |> from(Emails.from())
    |> to(to)
    |> subject("#{length(due)} follow-ups due")
    |> text_body("Follow-ups due today or overdue:\n\n#{lines}\n")
  end
end
