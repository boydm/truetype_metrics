#
#  Created by Boyd Multerer on 12/03/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule Mix.Tasks.TruetypeMetricsTest do
  use ExUnit.Case
  doctest Mix.Tasks.TruetypeMetrics

  alias Mix.Tasks.TruetypeMetrics, as: Gen

  import IEx

  @dst        "test/dst"
  @src        "test/src"
  @roboto     "test/fonts/Roboto/Roboto-Regular.ttf"
  @bitter     "test/fonts/Bitter/Bitter-Regular.ttf"

  setup do
    File.mkdir(@dst)
    File.mkdir(@src)
    on_exit(fn ->
      with {:ok, ls} <- File.ls(@dst) do
        Enum.each(ls, fn(f) -> Path.join(@dst, f) |> File.rm() end)        
        File.rmdir(@dst)
      end
      with {:ok, ls} <- File.ls(@src) do
        Enum.each(ls, fn(f) -> Path.join(@src, f) |> File.rm() end)        
        File.rmdir(@src)
      end
    end)
    :ok
  end

  defp assert_dst( file ) do
    path = Path.join(@dst, file)
    assert File.exists?(path)
    refute File.dir?(path)
    File.read!(path)
    |> FontMetrics.from_binary!()
  end

  test "gen works for roboto in place" do
    cwd = File.cwd!()
    File.cp( @roboto, @dst <> "/Roboto-Regular.ttf" )
    File.cd(@dst)
    Gen.run([])
    File.cd(cwd)
    assert_dst("Roboto-Regular.ttf.metrics")
  end

  test "gen works for robot src path and dst" do
    Gen.run([@roboto, @dst])
    assert_dst("Roboto-Regular.ttf.metrics")
  end

  test "gen works for roboto src dir and dst" do
    Gen.run(["test/fonts/Roboto", @dst])
    assert_dst("Roboto-Regular.ttf.metrics")
  end

  test "gen works for bitter src path and dst" do
    Gen.run([@bitter, @dst])
    assert_dst("Bitter-Regular.ttf.metrics")
  end

  test "gen works for bitter src dir and dst" do
    Gen.run(["test/fonts/Bitter", @dst])
    assert_dst("Bitter-Regular.ttf.metrics")
  end

  test "gen recurses" do
    Gen.run(["test/fonts", @dst, "-r"])
    assert_dst("Bitter-Regular.ttf.metrics")
    assert_dst("Roboto-Regular.ttf.metrics")
  end

end