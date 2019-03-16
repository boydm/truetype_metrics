# credo:disable-for-this-file Credo.Check.Warning.IoInspect
defmodule Mix.Tasks.TruetypeMetrics do
  use Mix.Task

  @shortdoc "Generate metrics for a TrueType font"

  @moduledoc """
  Generate a metrics file for a TrueType font.

  example:

      mix truetype_metrics Roboto-Regular.ttf

      >> * creating Roboto-Regular.ttf.metrics

  You can also point it at a directory to have it generate metrics for all the fonts within

      mix truetype_metrics fonts
      
      >> created Roboto-Regular.ttf.metrics
      >> created RobotoMono-Regular.ttf.metrics
      >> created RobotoSlab-Regular.ttf.metrics
  """
  # import IEx

  @switches [
    recurse: :boolean,
    decorate_font: :boolean,
    force: :boolean
  ]

  @aliases [
    r: :recurse,
    d: :decorate_font,
    f: :force
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
  # defp validate_path(path) do
  #   case File.dir?(path) do
  #     true ->
  #       {:ok, path}

  #     false ->
  #       put_msg(
  #         IO.ANSI.red() <>
  #         "Invalid Destination Directory: \"#{path}\"" <>
  #         IO.ANSI.default_color()
  #       )
  #       :error
  #   end
  # end

  #--------------------------------------------------------
  defp put_msg( msg ) do
    unless Mix.env() == :test do
      IO.puts( msg )
    end
  end

end
