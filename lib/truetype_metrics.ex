defmodule TruetypeMetrics do
  @moduledoc """
  Documentation for TruetypeMetrics.
  """

  import IEx

  @version_one          <<0, 1, 0, 0>>
  @magic_number         0x5F0F3CF5

  @invalid_font         { :error, :invalid_font }
  @bad_checksum         { :error, :bad_checksum }

  @font_epoch {{1904, 1, 1}, {0, 0, 0}}
    |> :calendar.datetime_to_gregorian_seconds()
    
  @unix_epoch {{1970, 1, 1}, {0, 0, 0}}
    |> :calendar.datetime_to_gregorian_seconds()

  @font_to_unix_seconds @font_epoch - @unix_epoch


  # def go() do: load( "../test/fonts/Bitter/Bitter-Regular.ttf")
  def go() do
    load( "test/fonts/Roboto/Roboto-Regular.ttf")
  end

  #--------------------------------------------------------
  # inspect a ttf font. Is limited. Returns a map of font info
  def load( font_path ) when is_bitstring(font_path) do
    case File.read( font_path ) do
      {:ok, raw_font} -> parse( raw_font )
      err -> err
    end
  end

  #--------------------------------------------------------
  # inspect a ttf font. Is limited. Returns a map of font info
  def load!( font_path ) when is_bitstring(font_path) do
    File.read!( font_path ) |> parse!()
  end

  #--------------------------------------------------------
  # start by parsing the intial font directory table
  def parse( <<
    @version_one :: binary,
    table_count :: unsigned-integer-size(16)-big,
    _search_range :: unsigned-integer-size(16)-big,
    _entry_selector :: unsigned-integer-size(16)-big,
    _range_shift :: unsigned-integer-size(16)-big,
    data :: binary
  >> = font_data ) do

    # start building up the font info
    interim = %{
      table_count: table_count,
      table_locations: %{}
    }

    # parse out all the pieces
    with {:ok, interim} <- parse_tables( interim, data, table_count ) do
    # {:ok, interim} <- parse_head( interim ) do
    # {:ok, info} <- parse_maxp( info )
    # {:ok, info} <- parse_kern( info )
    # {:ok, info} <- parse_cmap( info ) do
pry()
      # {:ok, %TruetypeMetrics{
      #   glyph_count: info.glyph_count,
      #   ranges: info.ranges,
      #   char_space: info.char_space,
      #   head: info.head,
      #   kern: info[:kern]
      # }}
      :ok
    else
      err -> err
    end
  end
  def parse( _ ), do: @invalid_font

  def parse!( data ) do
    {:ok, metrics} = parse(data)
    metrics
  end

  #============================================================================
  # internal utilities

  #--------------------------------------------------------
  # The first data to parse is the table locations. This is right after the main
  # file header. Recurse through the data
  defp parse_tables( interim, current_table, count )
  defp parse_tables( interim, _, 0 ), do: {:ok, interim}
  defp parse_tables( _, "", _ ), do: {:error, :invalid_table_map}
  defp parse_tables(
    %{table_locations: table_locations} = interim,
    <<
      tag :: binary-size(4),
      checksum :: unsigned-integer-size(32)-big,
      offset :: unsigned-integer-size(32)-big,
      table_size :: unsigned-integer-size(32)-big,
      next_table :: binary
    >>,
    count
  ) do

    # build the header for the current table
    th = %{
      checksum: checksum,
      offset: offset,
      size: table_size
    }

    # add the specific table header
    interim = put_in( interim, [:table_locations, tag], th)

    # recurse to get all the entries
    parse_tables( interim, next_table, count - 1 )
  end
  defp parse_tables( _, _, _ ), do: {:error, :invalid_table_map}


  #============================================================================
  # head table

 #  #--------------------------------------------------------
 #  defp parse_head( info, file_data ) do
 #    with  { :ok, head_data } <- get_table_data( info, file_data, "head" ),
 #    {:ok, head} <- do_parse_head( head_data ) do
 #      Map.put(info, :head, head)
 #    else
 #      err ->
 #        err
 #    end
 #  end

 #  #--------------------------------------------------------
 #  defp do_parse_head( <<
 #    @version_one :: binary,
 #    font_revision :: binary-size(4),
 #    checksum_adjustment :: unsigned-integer-size(32)-big,
 #    @magic_number :: unsigned-integer-size(32)-big,
 #    flags :: binary-size(2),
 #    units_per_em :: unsigned-integer-size(16)-big,
 #    created :: signed-integer-size(64)-big,
 #    modified :: signed-integer-size(64)-big,
 #    x_min :: signed-integer-size(16)-big,
 #    y_min :: signed-integer-size(16)-big,
 #    x_max :: signed-integer-size(16)-big,
 #    y_max :: signed-integer-size(16)-big,
 #    style :: unsigned-integer-size(16)-big,
 #    lowest_px :: unsigned-integer-size(16)-big,
 #    direction :: signed-integer-size(16)-big,
 #    index_to_loc_format :: integer-size(16)-big,
 #    glyph_data_format :: integer-size(16)-big,
 #  >> ) do
 #    {:ok, %{
 #      version: @version_one,
 #      font_revision: font_revision,
 #      checksum_adjustment: checksum_adjustment,
 #      flags: flags,
 #      units_per_em: units_per_em,
 #      created: DateTime.from_unix!(created + @font_to_unix_seconds),
 #      modified: DateTime.from_unix!(modified + @font_to_unix_seconds),
 #      x_min: x_min,
 #      y_min: y_min,
 #      x_max: x_max,
 #      y_max: y_max,
 #      style: style,
 #      lowest_px: lowest_px,
 #      direction: direction,
 #      index_to_loc_format: index_to_loc_format,
 #      glyph_data_format: glyph_data_format
 #    }}
 #  end

 #  # something required didn't match. Possibly the magic number...
 #  defp do_parse_head( _ ) do
 #    raise "Invalid Font - failed parsing head table"
 # #   @invalid_font
 #  end







  #============================================================================
  # utilities

  #--------------------------------------------------------
  # Calculate a table checksum as defined by the truetype standard. This would
  # be MUCH faster as native code, but part of the point is to do this in pure
  # BEAM code for safety. This whole package should not live in a performance
  # critical path.

  @doc false
  def checksum( bin ) when is_binary(bin) do
    # pad with zeros to a multiple of 4
    bin = case rem(byte_size(bin), 4) do
      0 -> bin
      1 -> bin <> <<0, 0, 0>>
      2 -> bin <> <<0, 0>>
      3 -> bin <> <<0>>
    end
    do_checksum( bin )
  end
  defp do_checksum( bin, checksum \\ 0 )
  defp do_checksum( "", checksum ) do
    # simulate 32-bit overflowed arithmetic
    <<clamped::unsigned-size(32)>>=<<checksum::unsigned-size(32)>>
    {:ok, clamped}
  end
  defp do_checksum( << long :: unsigned-size(32)-big, bin :: binary >>, checksum ) do
    do_checksum( bin, checksum + long )
  end
  defp do_checksum( _, _ ), do: {:error, :checksum}


#   #--------------------------------------------------------
#   defp get_table_data( %{table_loc: table_loc}, file_data, "head" ) do
#     %{
#       offset: offset,
#       size: table_size,
# #      checksum: checksum
#     } = Map.get(table_loc, "head")

#     <<
#       _ :: binary-size(offset),
#       table_data :: binary-size(table_size),
#       _ :: binary
#     >> = font_data

#     {:ok, table_data}
#   end

#   #--------------------------------------------------------
#   defp get_table_data( %{table_loc: table_loc, data: font_data}, table_id ) do
#     case Map.get(table_loc, table_id) do
#       nil ->
#         nil
#       loc ->
#         do_get_table_data( font_data, loc )
#     end
#   end

#   #----------------------------------------------
#   defp do_get_table_data( font_data, %{offset: offset, size: table_size, checksum: checksum} ) do
#     <<
#       _ :: binary-size(offset),
#       table_data :: binary-size(table_size),
#       _ :: binary
#     >> = font_data

#     # test the checksum for validity
#     case Native.checksum( table_data ) do
#       ^checksum ->
#         { :ok, table_data }

#       _ ->
#         @bad_checksum
#     end
#   end
end





























