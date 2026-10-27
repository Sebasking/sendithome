defmodule ShipperDirectoryWeb.HeroComponents do
  @moduledoc """
  The home page hero video: the SendItHome journey animation, rendered ahead
  of time from the Remotion project in `animation/` (`npm run render:web`)
  into `priv/static/videos/`.

  There's no `autoplay`: the `HeroVideo` hook in `app.js` starts playback, so
  it can hold off offscreen and when reduced motion or Save-Data is on.
  """
  use ShipperDirectoryWeb, :html

  def hero_video(assigns) do
    ~H"""
    <div class="hero-video" id="hero-video" phx-hook="HeroVideo" phx-update="ignore">
      <video
        class="hero-video__media"
        width="1920"
        height="1080"
        muted
        loop
        playsinline
        preload="metadata"
        poster={~p"/videos/journey-poster.jpg"}
        aria-describedby="hero-video-desc"
      >
        <%!-- Phones get the 720 files. `media` is only read at load. --%>
        <source media="(max-width: 767px)" src={~p"/videos/journey-720.webm"} type="video/webm" />
        <source media="(max-width: 767px)" src={~p"/videos/journey-720.mp4"} type="video/mp4" />
        <source src={~p"/videos/journey-1080.webm"} type="video/webm" />
        <source src={~p"/videos/journey-1080.mp4"} type="video/mp4" />
      </video>
      <p id="hero-video-desc" class="sr-only">
        Animation: a barrel is picked up from a home, carried by truck to a ship, shipped across the sea, and delivered to a family's house on an island.
      </p>
      <button
        type="button"
        id="hero-video-toggle"
        class="hero-video__toggle"
        aria-label="Play animation"
        data-role="toggle"
      >
        <.icon name="hero-pause-solid" class="hero-video__pause size-5" />
        <.icon name="hero-play-solid" class="hero-video__play size-5" />
      </button>
    </div>
    """
  end
end
