# credo:disable-for-this-file Credo.Check.Warning.IoInspect
defmodule Mix.Tasks.TruetypeMetrics do
  use Mix.Task

  @shortdoc "Generate metrics for a TrueType font"

  @moduledoc """
  Generate a metrics file for a TrueType font.

  The truetype_metrics package is for use with the font_metrics package.
  It parses TrueType files and creates %FontMetrics{} structs that can be used
  in Scenic to work with fonts. It is not, however dependent on Scenic, you can
  use this elsewhere.

  You can call the module APIs if you want, but truetype_metrics is typically
  used as a command line tool.

  ## Installation

  You could take a dependency on truetype_metrics in code if you want, but it is
  usually used as an installed archive.

  ```bash
  mix archive.install hex truetype_metrics
  ```

  ## Generate a metrics file for one font

  ```bash
  mix truetype_metrics Roboto-Regular.ttf

  >> create Roboto-Regular.ttf.metrics
  ```

  ## Generate a metrics for all fonts in a directory

  ```bash
  mix truetype_metrics priv/static/fonts

  >> created Roboto-Regular.ttf.metrics
  >> created RobotoMono-Regular.ttf.metrics
  >> created RobotoSlab-Regular.ttf.metrics
  ```

  ## Options

  The -d option will automatically append the hash of the font file to the name
  of the font file itself.

  ```bash
  mix truetype_metrics fonts -d

  >> created Roboto-Regular.ttf.metrics
  >> renamed Roboto-Regular.ttf to Roboto-Regular.ttf.eehRQEZX2sIQaz0irSVtR4JKmldlRY7bcskQKkWBbZU
  ```

  The -r option will recurse the given folder and generate metrics for all found fonts.

  """
  # import IEx

  @switches [
    recurse: :boolean,
    decorate_font: :boolean
  ]

  @aliases [
    r: :recurse,
    d: :decorate_font
  ]

  @doc false
  def run(argv) do
    {opts,dirs} = OptionParser.parse!(argv, aliases: @aliases, strict: @switches)
    path = (Enum.at(dirs, 0) || File.cwd!())
    |> Path.expand()

    with {:ok, path} <- validate_path(path) do
      put_msg("")
      put_msg("Generating metrics for #{path}")
      put_msg("")

      case File.dir?(path) do
        true -> gen_dir( path, opts )
        false -> gen_file( path, opts )
      end

      put_msg("")
    end
  end

  #--------------------------------------------------------
  defp gen_dir(path, opts) do
    File.ls!(path)
    |> Enum.each(fn sub_path ->
      p = Path.join(path, sub_path)
      case File.dir?(p) do
        true ->
          if opts[:recurse] do
            gen_dir(p, opts)
          end
        false ->
          gen_file( p, opts )
      end
    end)
  end

  #--------------------------------------------------------
  defp gen_file(src, opts) do
    path_out = src <> ".metrics"

    with {:ok, fm} <- TruetypeMetrics.load( src ),
    {:ok, bin} <- FontMetrics.to_binary( fm ),
    :ok <- File.write( path_out, bin ) do
      # convenience hash of the metrics file
      sha = :crypto.hash(:sha, bin)
      |> Base.url_encode64(padding: false)
      put_msg "* created #{path_out}, sha: #{sha}"

      # deocorate the font if requested
      if opts[:decorate_font] do
        if File.rename(src, src <> ".#{fm.source.signature}") == :ok do
          put_msg "* renamed #{src} to #{src <> ".#{fm.source.signature}"}"
        else
          put_msg "* failed to decorate #{src}"                
        end
      end

      put_msg ""
    else
      err ->
        put_msg(
          IO.ANSI.red() <>
          "#{src}: #{inspect(err)}" <>
          IO.ANSI.default_color()
        )
    end
  end

  #--------------------------------------------------------
  defp validate_path(path) do
    case File.exists?(path) do
      true ->
        {:ok, path}

      false ->
        put_msg(
          IO.ANSI.red() <>
          "Invalid location: \"#{path}\"" <>
          IO.ANSI.default_color()
        )
        :error
    end
  end

  #--------------------------------------------------------
  defp put_msg( msg ) do
    unless Mix.env() == :test do
      IO.puts( msg )
    end
  end

end
