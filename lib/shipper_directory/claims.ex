defmodule ShipperDirectory.Claims do
  @moduledoc """
  Claim flow (spec section 6): an owner proves control of a published
  listing, then edits it.

  Proof is a 6-digit code sent to either
    * an email address **at the company's website domain** (e.g.
      info@fcsshipping.com for fcsshipping.com; free webmail doesn't count), or
    * the **phone number on the listing**, by SMS or voice call.

  Once verified, the claimant's email becomes a user account that owns the
  company, and a magic sign-in link goes to that address. Clicking it also
  proves the owner controls that email.

  Limits: codes expire after 15 minutes, 5 wrong guesses lock a claim, and
  a company can have at most 3 claims started per hour.
  """

  alias ShipperDirectory.Accounts.User
  alias ShipperDirectory.Claims.{Emails, PhoneSender}
  alias ShipperDirectory.Directory
  alias ShipperDirectory.Directory.{Claim, Company}
  alias ShipperDirectory.Mailer

  @code_ttl_minutes 15
  @max_attempts 5
  @max_starts_per_hour 3

  @free_email_domains ~w(
    gmail.com googlemail.com yahoo.com ymail.com hotmail.com outlook.com live.com msn.com
    aol.com icloud.com me.com mac.com protonmail.com proton.me comcast.net verizon.net
    optonline.net att.net sbcglobal.net
  )

  def max_attempts, do: @max_attempts

  @doc "A company can be claimed when it's published and has no owner yet."
  def claimable?(%Company{status: :published, owner_id: nil}), do: true
  def claimable?(_company), do: false

  @doc "Which methods this company supports: `:email` needs a website, `:sms`/`:call` need a phone."
  def methods(%Company{} = company) do
    [
      company.website_url && :email,
      phone_e164(company) && :call,
      phone_e164(company) && :sms
    ]
    |> Enum.reject(&(&1 in [nil, false]))
  end

  @doc """
  Starts a claim and sends the code. Params (string keys):
    * `"method"`: "email", "sms", or "call"
    * `"name"`: the claimant's name
    * `"email"`: for "email", an address at the company's domain (it's also
      where they sign in). For phone methods, where they'll sign in.
  """
  def start(%Company{} = company, params) do
    with :ok <- check_claimable(company),
         {:ok, method} <- parse_method(params["method"], company),
         {:ok, name} <- required(params["name"], :name),
         {:ok, email} <- parse_email(params["email"]),
         {:ok, destination} <- destination(method, company, email),
         :ok <- check_rate_limit(company) do
      code = generate_code()

      claim =
        Directory.create_claim!(%{
          company_id: company.id,
          method: method,
          destination: destination,
          claimant_name: name,
          claimant_email: email,
          code_hash: Bcrypt.hash_pwd_salt(code),
          expires_at: DateTime.add(DateTime.utc_now(), @code_ttl_minutes, :minute)
        })

      case deliver(method, destination, code, company) do
        :ok -> {:ok, claim}
        {:error, _reason} -> {:error, :delivery_failed}
      end
    end
  end

  @doc """
  Checks the code. On success the claimant owns the company and gets a
  sign-in link by email. Returns `{:ok, company}` or `{:error, reason}`.
  """
  def verify(%Claim{} = claim, code) do
    company = Directory.get_company!(claim.company_id)

    cond do
      claim.status == :verified -> {:error, :already_verified}
      claim.status == :locked -> {:error, :locked}
      DateTime.compare(DateTime.utc_now(), claim.expires_at) == :gt -> {:error, :expired}
      not claimable?(company) -> {:error, :not_claimable}
      Bcrypt.verify_pass(String.trim(code || ""), claim.code_hash) -> complete!(claim, company)
      true -> wrong_code!(claim)
    end
  end

  defp complete!(claim, company) do
    user = register_user!(claim.claimant_email)
    Directory.mark_claim_verified!(claim, user.id)
    company = Directory.assign_owner!(company, user.id)
    request_magic_link(user.email)
    {:ok, company}
  end

  defp wrong_code!(claim) do
    attempts = claim.attempts + 1
    status = if attempts >= @max_attempts, do: :locked, else: :pending
    Directory.record_claim_attempt!(claim, %{attempts: attempts, status: status})
    if status == :locked, do: {:error, :locked}, else: {:error, :invalid_code}
  end

  defp register_user!(email) do
    User
    |> Ash.Changeset.for_create(:register_for_claim, %{email: email})
    |> Ash.create!(authorize?: false)
  end

  defp request_magic_link(email) do
    User
    |> Ash.ActionInput.for_action(:request_magic_link, %{email: email})
    |> Ash.run_action(authorize?: false)
  end

  @doc "True when the email's domain is the company's website domain (or a subdomain of it)."
  def email_matches_site?(email, website_url) when is_binary(email) and is_binary(website_url) do
    with [_local, domain] <- email |> String.downcase() |> String.split("@"),
         %URI{host: host} when is_binary(host) <- URI.parse(website_url) do
      host = host |> String.downcase() |> String.replace_prefix("www.", "")

      domain not in @free_email_domains and
        (domain == host or String.ends_with?(host, "." <> domain) or
           String.ends_with?(domain, "." <> host))
    else
      _ -> false
    end
  end

  def email_matches_site?(_email, _website_url), do: false

  def phone_e164(%Company{normalized_phone: nil}), do: nil
  def phone_e164(%Company{normalized_phone: digits}), do: "+1" <> digits

  @doc "(•••) •••-8006: for telling the claimant which number we'll call."
  def masked_phone(company) do
    case company.normalized_phone do
      nil -> nil
      digits -> "(•••) •••-" <> String.slice(digits, -4, 4)
    end
  end

  defp check_claimable(company) do
    if claimable?(company), do: :ok, else: {:error, :not_claimable}
  end

  defp parse_method(method, company) do
    method = Enum.find(methods(company), &(to_string(&1) == method))
    if method, do: {:ok, method}, else: {:error, :invalid_method}
  end

  defp required(value, field) do
    case String.trim(value || "") do
      "" -> {:error, {:required, field}}
      trimmed -> {:ok, trimmed}
    end
  end

  defp parse_email(value) do
    email = String.trim(value || "")
    if email =~ ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, do: {:ok, email}, else: {:error, :invalid_email}
  end

  defp destination(:email, company, email) do
    if email_matches_site?(email, company.website_url),
      do: {:ok, email},
      else: {:error, :email_not_at_domain}
  end

  defp destination(_phone_method, company, _email), do: {:ok, phone_e164(company)}

  defp check_rate_limit(company) do
    since = DateTime.add(DateTime.utc_now(), -1, :hour)

    if length(Directory.recent_claims_for_company!(company.id, since)) >= @max_starts_per_hour,
      do: {:error, :rate_limited},
      else: :ok
  end

  defp deliver(:email, to, code, company) do
    case to |> Emails.claim_code(code, company) |> Mailer.deliver() do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp deliver(method, to, code, _company), do: PhoneSender.deliver(method, to, code)

  defp generate_code do
    <<n::32>> = :crypto.strong_rand_bytes(4)
    n |> rem(1_000_000) |> Integer.to_string() |> String.pad_leading(6, "0")
  end

  @doc "Human-readable error for the claim UI."
  def error_message(:not_claimable),
    do: "This listing can't be claimed. It may already have an owner."

  def error_message(:invalid_method), do: "Choose how you'd like to verify."
  def error_message({:required, :name}), do: "Please enter your name."
  def error_message(:invalid_email), do: "Please enter a valid email address."

  def error_message(:email_not_at_domain),
    do:
      "Use an email address at your website's domain (not Gmail, Yahoo, etc.), or verify by phone."

  def error_message(:rate_limited),
    do: "Too many attempts for this listing. Try again in an hour."

  def error_message(:delivery_failed), do: "We couldn't send the code. Please try another method."
  def error_message(:invalid_code), do: "That code isn't right. Check it and try again."
  def error_message(:expired), do: "That code has expired. Start again to get a new one."
  def error_message(:locked), do: "Too many wrong codes. Start again to get a new one."

  def error_message(:already_verified),
    do: "This claim is already verified. Check your email to sign in."
end
