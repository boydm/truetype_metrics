defmodule TruetypeMetricsTest do
  use ExUnit.Case
  doctest TruetypeMetrics

  #============================================================================
  # checksum

  test "checksum works - no padding" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadf") == {:ok, 4058887661}
  end

  test "checksum works, pad 3" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadfg") == {:ok, 1491973613}
  end

  test "checksum works, pad 2" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadfgh") == {:ok, 1498789357}
  end

  test "checksum works, pad 1" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.checksum("ioaerpiuha3q23rhjlaiueyaiq34hfkjanglhadfghl") == {:ok, 1498817005}
  end
  
  test "checksum deals with an empty binary" do
    # make sure it tests all the lengths needing padding
    assert TruetypeMetrics.checksum("") == {:ok, 0}
  end
  
end
