defmodule ShipperDirectory.Analytics.FlowAnswerEvent do
  @moduledoc """
  One answer in the QR flow. `destination` answers are a destination code,
  `other`, or `all` (browse all); `timing` answers are `christmas`, `any`
  or `skip`.
  """
  use Ash.Resource,
    otp_app: :shipper_directory,
    domain: ShipperDirectory.Analytics,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "flow_answer_events"
    repo ShipperDirectory.Repo

    custom_indexes do
      index [:inserted_at]
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [:source_code, :step, :answer, :utm_content]
    end

    destroy :expire do
      description "Retention job only."
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :source_code, :string, public?: true

    attribute :step, :atom,
      allow_nil?: false,
      constraints: [one_of: [:destination, :timing]],
      public?: true

    attribute :answer, :string, allow_nil?: false, public?: true
    attribute :utm_content, :string, public?: true
    create_timestamp :inserted_at
  end
end
