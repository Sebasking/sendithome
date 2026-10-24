defmodule ShipperDirectoryWeb.ContactController do
  @moduledoc """
  `/go/:slug/:channel`: a tracked Call, WhatsApp or Website tap from the QR
  flow. Logs a ContactClickEvent, then redirects to the `tel:` link,
  `wa.me` chat or website. The flow passes `sponsored`, `to`, `src` and
  `utm_content` along as query params.
  """
  use ShipperDirectoryWeb, :controller

  alias ShipperDirectory.Analytics.{ContactClickEvent, EventLog}
  alias ShipperDirectory.{Directory, Finder}
  alias ShipperDirectoryWeb.{Bots, FlowParams, NotFoundError}

  @channels %{"call" => :call, "whatsapp" => :whatsapp, "website" => :website}

  def show(conn, %{"slug" => slug, "channel" => channel} = params) do
    with {:ok, channel} <- Map.fetch(@channels, channel),
         {:ok, company} <- Directory.get_published_company(slug),
         target when is_binary(target) <- Finder.contact_target(company, channel) do
      unless Bots.bot?(conn) do
        EventLog.record(ContactClickEvent, %{
          company_id: company.id,
          channel: channel,
          sponsored: params["sponsored"] == "1",
          destination_code: FlowParams.clean(params["to"]),
          source_code: FlowParams.clean(params["src"]),
          utm_content: FlowParams.clean(params["utm_content"])
        })
      end

      redirect(conn, external: target)
    else
      _ -> raise NotFoundError
    end
  end
end
