#
#  Created by Boyd Multerer on 12/03/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule Mix.Tasks.TruetypeMetricsTest do
  use ExUnit.Case
  doctest Mix.Tasks.TruetypeMetrics

  alias Mix.Tasks.TruetypeMetrics, as: Gen

  # import IEx

  @loc        "test/loc"
  @roboto     "test/fonts/Roboto/Roboto-Regular.ttf"
  @bitter     "test/fonts/Bitter/Bitter-Regular.ttf"

  @roboto_hash ".eehRQEZX2sIQaz0irSVtR4JKmldlRY7bcskQKkWBbZU"

  setup do
    File.mkdir(@loc)
    on_exit(fn ->
      with {:ok, ls} <- File.ls(@loc) do
        Enum.each(ls, fn(f) -> Path.join(@loc, f) |> File.rm() end)        
        File.rmdir(@loc)
      end
    end)
    :ok
  end

  defp assert_metrics( path ) do
    assert File.exists?(path)
    refute File.dir?(path)
    File.read!(path)
    |> FontMetrics.from_binary!()
  end

  defp prep( source ) do
    file = Path.basename(source)
    dst = Path.join(@loc, file)
    File.cp( source, dst )
    dst
  end

  test "gen works for files in local directory" do
    roboto = prep( @roboto )
    bitter = prep( @bitter )

    cwd = File.cwd!()
    File.cd(@loc)
    Gen.run([])
    File.cd(cwd)

    assert_metrics roboto <> ".metrics"
    assert_metrics bitter <> ".metrics"
  end

  test "gen works for specified font" do
    roboto = prep( @roboto )
    bitter = prep( @bitter )

    Gen.run([roboto])

    assert_metrics roboto <> ".metrics"
    refute File.exists?(bitter  <> ".metrics")
  end

  test "gen works for fonts in specified directory" do
    roboto = prep( @roboto )
    bitter = prep( @bitter )

    Gen.run([@loc])

    assert_metrics roboto <> ".metrics"
    assert_metrics bitter <> ".metrics"
  end

  test "gen does not decorate the font if no -d flag is set" do
    roboto = prep( @roboto )
    Gen.run([@loc])
    assert File.exists?(roboto)
  end

  test "gen decorates the font if -d flag is set" do
    roboto = prep( @roboto )
    Gen.run([@loc, "-d"])
    refute File.exists?(roboto)
    assert File.exists?(roboto <> @roboto_hash)
  end

  # test "gen recurses" do
  #   Gen.run(["test/fonts", @dst, "-r"])
  #   assert_dst("Bitter-Regular.ttf.metrics")
  #   assert_dst("Roboto-Regular.ttf.metrics")
  # end

end











