#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule TruetypeMetricsTest do
  use ExUnit.Case
  doctest TruetypeMetrics

  @roboto "test/fonts/Roboto/Roboto-Regular.ttf"
  @bitter "test/fonts/Bitter/Bitter-Regular.ttf"
  @fira_code "test/fonts/FiraCode/FiraCode-Regular.ttf"

  @hash_type FontMetrics.expected_hash()

  # ============================================================================
  # checksum

  test "checksum works - no padding" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.test_checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadf") ==
             4_058_887_661
  end

  test "checksum works, pad 3" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.test_checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadfg") ==
             1_491_973_613
  end

  test "checksum works, pad 2" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.test_checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadfgh") ==
             1_498_789_357
  end

  test "checksum works, pad 1" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.test_checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadfghl") ==
             1_498_817_005
  end

  test "checksum deals with an empty binary" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.test_checksum("") == 0
  end

  # ============================================================================
  # roboto

  test "loads the Roboto-Regular file" do
    {:ok, %FontMetrics{} = metrics} = TruetypeMetrics.load(@roboto)
    assert metrics.max_box == {-1509, -555, 2352, 2163}
    assert metrics.units_per_em == 2048
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning == %{}

    assert metrics.source.signature_type == @hash_type

    signature = :crypto.hash(@hash_type, File.read!(@roboto))

    assert metrics.source.signature == signature
    assert metrics.source.font_type == :true_type
  end

  test "parses the Roboto-Regular file" do
    font_data = File.read!(@roboto)
    {:ok, %FontMetrics{} = metrics} = TruetypeMetrics.parse(font_data, "Roboto-Regular.ttf")
    assert metrics.source.signature_type == @hash_type

    signature = :crypto.hash(@hash_type, font_data)

    assert metrics.source.signature == signature
  end

  test "load! loads directly" do
    %FontMetrics{} = TruetypeMetrics.load!(@roboto)
  end

  test "parse! parses directly" do
    font_data = File.read!(@roboto)
    %FontMetrics{} = TruetypeMetrics.parse!(font_data, "Roboto-Regular.ttf")
  end

  # ============================================================================
  # bitter - has a kerning table...

  test "loads the Bitter-Regular file" do
    {:ok, %FontMetrics{} = metrics} = TruetypeMetrics.load(@bitter)
    assert metrics.max_box == {-60, -265, 1125, 935}
    assert metrics.units_per_em == 1000
    assert metrics.smallest_ppem == 9
    assert metrics.direction == 2
    assert metrics.kerning[{66, 65}] == -30

    assert metrics.source.signature_type == @hash_type

    signature = :crypto.hash(@hash_type, File.read!(@bitter))

    assert metrics.source.signature == signature
    assert metrics.source.font_type == :true_type
  end

  test "parses the Bitter-Regular file" do
    font_data = File.read!(@bitter)
    {:ok, %FontMetrics{} = metrics} = TruetypeMetrics.parse(font_data, "Bitter-Regular.ttf")
    assert metrics.source.signature_type == @hash_type

    signature = :crypto.hash(@hash_type, font_data)

    assert metrics.source.signature == signature
  end

  # ============================================================================
  # firacode
  # the firacode font has a type 12 cmap table in it.

  test "loads the FiraCode-Regular.ttf file" do
    {:ok, %FontMetrics{} = metrics} = TruetypeMetrics.load(@fira_code)
    assert metrics.max_box == {-3555, -1000, 2384, 2400}
    assert metrics.units_per_em == 1950
    assert metrics.smallest_ppem == 6
    assert metrics.direction == 2
    assert metrics.kerning == %{}

    assert metrics.source.signature_type == @hash_type

    signature = :crypto.hash(@hash_type, File.read!(@fira_code))

    assert metrics.source.signature == signature
    assert metrics.source.font_type == :true_type
  end

  test "parses the FiraCode-fira_code file" do
    font_data = File.read!(@roboto)
    {:ok, %FontMetrics{} = metrics} = TruetypeMetrics.parse(font_data, "FiraCode-Regular.ttf")
    assert metrics.source.signature_type == @hash_type

    signature = :crypto.hash(@hash_type, font_data)

    assert metrics.source.signature == signature
  end

  # ============================================================================
  # various failures

  test "Checks overall internal file hash" do
    font_data = File.read!(@bitter) <> "extra data"

    assert TruetypeMetrics.parse(font_data, "Bitter-Regular.ttf") ==
             {:error, :checksum}
  end

  test "uses version from FontMetrics" do
    {:ok, %FontMetrics{} = metrics} = TruetypeMetrics.load(@roboto)
    assert metrics.version == FontMetrics.version()
  end

  # ============================================================================
  # font awesome
  # add font_awesome yourself. When you add the file, the test will run
  @font_awesome "test/fonts/font_awesome/Font-Awesome-6-Free-Regular-400.ttf"
  test "loads the Font-Awesome-6-Free-Regular-400.ttf file" do
    with {:ok, %FontMetrics{} = metrics} <- TruetypeMetrics.load(@font_awesome) do
      assert metrics.max_box == {-6, -69, 645, 453}
      assert metrics.units_per_em == 512
      assert metrics.smallest_ppem == 8
      assert metrics.direction == 2
      assert metrics.kerning == %{}

      assert metrics.source.signature_type == @hash_type

      signature = :crypto.hash(@hash_type, File.read!(@font_awesome))

      assert metrics.source.signature == signature
      assert metrics.source.font_type == :true_type
    end
  end
end
