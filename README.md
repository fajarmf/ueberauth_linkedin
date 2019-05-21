# Überauth LinkedIn

[![Build Status][travis-img]][travis] [![Hex Version][hex-img]][hex] [![License][license-img]][license]

[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg
[license]: http://opensource.org/licenses/MIT
[hex-img]: https://img.shields.io/hexpm/v/ueberauth_linkedin.svg
[hex]: https://hex.pm/packages/ueberauth_linkedin
[travis-img]: https://travis-ci.org/fajarmf/ueberauth_linkedin.svg?branch=master
[travis]: https://travis-ci.org/fajarmf/ueberauth_linkedin

> LinkedIn OAuth2 strategy for Überauth.

## Installation

1. Setup your application at [LinkedIn Developers](https://developer.linkedin.com/).

1. Add `:ueberauth_linkedin` to your list of dependencies in `mix.exs`:

   ```elixir
   def deps do
     [{:ueberauth_linkedin, "~> 0.3"}]
   end
   ```

1. Add the strategy to your applications:

   ```elixir
   def application do
     [applications: [:ueberauth_linkedin]]
   end
   ```

1. Add LinkedIn to your Überauth configuration:

   ```elixir
   config :ueberauth, Ueberauth,
     providers: [
       linkedin: {Ueberauth.Strategy.LinkedIn, []}
     ]
   ```

1. Update your provider configuration:

   ```elixir
   config :ueberauth, Ueberauth.Strategy.LinkedIn.OAuth,
     client_id: System.get_env("LINKEDIN_CLIENT_ID"),
     client_secret: System.get_env("LINKEDIN_CLIENT_SECRET")
   ```

1. Include the Überauth plug in your controller:

   ```elixir
   defmodule MyApp.AuthController do
     use MyApp.Web, :controller
     plug Ueberauth
     ...
   end
   ```

1. Create the request and callback routes if you haven't already:

   ```elixir
   scope "/auth", MyApp do
     pipe_through :browser

     get "/:provider", AuthController, :request
     get "/:provider/callback", AuthController, :callback
   end
   ```

1. You controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured url you can initial the request through:

    /auth/linkedin?state=csrf_token_here

Or with scope:

    /auth/linkedin?state=csrf_token_here&scope=r_emailaddress

By default the requested scope is "r_basicprofile r_emailaddress". Scope can be configured either explicitly as a `scope` query value on the request path or in your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    linkedin: {Ueberauth.Strategy.LinkedIn, [default_scope: "r_basicprofile r_emailaddress"]}
  ]
```

## License

Please see [LICENSE](https://github.com/fajarmf/ueberauth_linkedin/blob/master/LICENSE) for licensing details.
