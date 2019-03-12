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
  import IEx

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
    IO.inspect(argv, label: "argv")
    {opts,dirs} = OptionParser.parse!(argv, aliases: @aliases, strict: @switches)
    source = (Enum.at(dirs, 0) || File.cwd!())
    |> Path.expand()
    destination = (Enum.at(dirs, 1) || File.cwd!())
    |> Path.expand()

    with {:ok, src} <- validate_src(source),
    {:ok, dst} <- validate_dst(destination) do
    put_msg("")
    put_msg("Generating metrics for #{src}")
    put_msg("")

      case File.dir?(src) do
        true -> gen_dir( src, dst, opts )
        false -> gen_file( src, dst, opts )
      end

      put_msg("")
    end
  end

  #--------------------------------------------------------
  defp gen_dir(src, dst, opts) do
    File.ls!(src)
    |> Enum.each(fn sub_path ->
      p = Path.join(src, sub_path)
      case File.dir?(p) do
        true ->
          if opts[:recurse] do
            gen_dir(p, dst, opts)
          end
        false ->
          gen_file( p, dst, opts )
      end
    end)
  end

  #--------------------------------------------------------
  defp gen_file(src, dst, _opts) do
    file = Path.basename(src)
    path_out = Path.join(dst, file <> ".metrics" )

    with {:ok, fm} <- TruetypeMetrics.load( src ),
    {:ok, bin} <- FontMetrics.to_binary( fm ),
    :ok <- File.write( path_out, bin ) do
    # :ok <- File.rename(path, path <> ".#{fm.source.signature}") do
      sha = :crypto.hash(:sha, bin)
      |> Base.url_encode64(padding: false)
      put_msg "* created #{path_out}, sha: #{sha}"
      put_msg "* renamed #{src} to #{src <> ".#{fm.source.signature}"}"
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
  defp validate_src(path) do
    case File.exists?(path) do
      true ->
        {:ok, path}

      false ->
        put_msg(
          IO.ANSI.red() <>
          "Invalid Source: \"#{path}\"" <>
          IO.ANSI.default_color()
        )
        :error
    end
  end

  #--------------------------------------------------------
  defp validate_dst(path) do
    case File.dir?(path) do
      true ->
        {:ok, path}

      false ->
        put_msg(
          IO.ANSI.red() <>
          "Invalid Destination Directory: \"#{path}\"" <>
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
