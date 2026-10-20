defmodule ShipperDirectoryWeb.AuthOverrides do
  @moduledoc """
  UI overrides for the AshAuthentication sign-in pages, layered over
  `AshAuthentication.Phoenix.Overrides.DaisyUI` so they pick up the brand theme.

  The SendItHome logo comes from `ShipperDirectoryWeb.Layouts.auth/1` rather
  than the Ash banner, because override values are fixed at compile time and
  the logo variant is chosen at runtime.

  Reference: https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html
  """
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.{Components, MagicSignInLive, SignInLive, SignOutLive}

  # The auth layout handles page centering and the card, so the pages render bare.
  for live <- [SignInLive, MagicSignInLive, SignOutLive] do
    override live do
      set :root_class, nil
    end
  end

  override Components.SignIn do
    set :show_banner, false
    set :root_class, "flex flex-col"
    set :strategy_class, "w-full"
  end

  override Components.MagicLink.SignIn do
    set :show_banner, false
    set :root_class, "flex flex-col"
    set :strategy_class, "w-full"
  end

  override Components.MagicLink do
    set :root_class, nil
    set :label_class, "mb-6 text-2xl font-bold tracking-tight text-base-content"
  end

  override Components.MagicLink.Input do
    set :submit_class, "btn btn-primary btn-block mt-6"
    set :remember_me_class, "mt-4 flex items-center gap-2"
    set :checkbox_class, "checkbox checkbox-primary checkbox-sm"
    set :checkbox_label_class, "text-sm text-base-content/80"
  end

  override Components.SignOut do
    set :root_class, "flex flex-col"
    set :h2_class, "mb-2 text-2xl font-bold tracking-tight text-base-content"
  end
end
