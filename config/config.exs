use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# third-party users, it should be done in your "mix.exs" file.

if File.exists?("./config/#{Mix.env()}.exs") do
  import_config("#{Mix.env()}.exs")
end
