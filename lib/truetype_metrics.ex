defmodule TruetypeMetrics do
  @moduledoc """
  Documentation for TruetypeMetrics.
  """

  import IEx

  @version_one          <<0, 1, 0, 0>>
  @magic_number         0x5F0F3CF5
  @magic_number_bin     <<0x5F, 0x0F, 0x3C, 0xF5>>

  @invalid_font         { :error, :invalid_font }
  @bad_checksum         { :error, :bad_checksum }

  @font_epoch {{1904, 1, 1}, {0, 0, 0}}
    |> :calendar.datetime_to_gregorian_seconds()
    
  @unix_epoch {{1970, 1, 1}, {0, 0, 0}}
    |> :calendar.datetime_to_gregorian_seconds()

  @font_to_unix_seconds @font_epoch - @unix_epoch

  @ppem_to_point        0.75

  @signature_type       FontMetrics.expected_hash()

  # def go(), do: load( "test/fonts/Bitter/Bitter-Regular.ttf")
  def go(), do: load( "test/fonts/Roboto/Roboto-Regular.ttf")

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
  # start by parsing the initial font directory table
  def parse( <<
    @version_one,
    table_count :: unsigned-integer-size(16)-big,
    _search_range :: unsigned-integer-size(16)-big,
    _entry_selector :: unsigned-integer-size(16)-big,
    _range_shift :: unsigned-integer-size(16)-big,
    table_data :: binary
  >> = raw_data ) do

    master_checksum = checksum( raw_data )

    # start building up the font info
    interim = %{
      table_count: table_count,
      table_locations: %{}
    }

    # parse out all the pieces
    with {:ok, interim} <- parse_tables( interim, table_data, table_count ),
    {:ok, interim} <- parse_head( interim, raw_data ),
    :ok <- check_master_checksum( raw_data, interim.head.checksum_adjustment ),
    {:ok, interim} <- parse_maxp( interim, raw_data ),
    {:ok, interim} <- parse_kern( interim, raw_data ),
    {:ok, interim} <- parse_cmap( interim, raw_data ) do
      signature = :crypto.hash( @signature_type, raw_data )
      |> Base.url_encode64( padding: false )
      {:ok, %FontMetrics{
        source: %FontMetrics.Source{
          signature_type: @signature_type,
          signature: signature,
          created_at: interim.head.created,
          modified_at: interim.head.modified,          
          font_type: "TrueType"
        },
        direction: interim.head.direction,
        smallest_ppem: interim.head.smallest_ppem,
        glyph_count: interim.glyph_count,
        bounding_box: {
            interim.head.x_min,
            interim.head.y_min,
            interim.head.x_max - interim.head.x_min,
            interim.head.y_max - interim.head.y_min
          },
        units_per_em: interim.head.units_per_em,
        ranges: FontMetrics.Ranges.simplify( interim.ranges ),
        kerning: interim[:kern],
        style: interim.head.style
      }}
    else
      bad_checksum when is_integer(bad_checksum) -> @invalid_font
      err -> err
    end
  end
  def parse( _d ), do: @invalid_font

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

  #--------------------------------------------------------
  defp parse_head( info, font_data ) do
    with  { :ok, head_data, check } <- get_table_data( info, font_data, "head" ),
    {:ok, head} <- do_parse_head( head_data, check ) do
      {:ok, Map.put(info, :head, head)}
    else
      err -> err
    end
  end

  #--------------------------------------------------------
  defp do_parse_head( <<
    @version_one,
    font_revision :: binary-size(4),
    checksum_adjustment :: unsigned-integer-size(32)-big,
    @magic_number_bin,
    flags :: binary-size(2),
    units_per_em :: unsigned-integer-size(16)-big,
    created :: signed-integer-size(64)-big,
    modified :: signed-integer-size(64)-big,
    x_min :: signed-integer-size(16)-big,
    y_min :: signed-integer-size(16)-big,
    x_max :: signed-integer-size(16)-big,
    y_max :: signed-integer-size(16)-big,
    style :: unsigned-integer-size(16)-big,
    lowest_ppem :: unsigned-integer-size(16)-big,
    direction :: signed-integer-size(16)-big,
    index_to_loc_format :: integer-size(16)-big,
    glyph_data_format :: integer-size(16)-big,
  >> = table_data, check ) do
    {:ok, %{
      version: @version_one,
      font_revision: font_revision,
      checksum_adjustment: checksum_adjustment,
      flags: flags,
      units_per_em: units_per_em,
      created: DateTime.from_unix!(created + @font_to_unix_seconds),
      modified: DateTime.from_unix!(modified + @font_to_unix_seconds),
      x_min: x_min,
      y_min: y_min,
      x_max: x_max,
      y_max: y_max,
      style: case style do
        0 -> :bold
        1 -> :italic
        2 -> :underline
        3 -> :outline
        4 -> :shadow
        5 -> :condensed
        6 -> :extended
        _ -> :unknown
      end,
      smallest_ppem: lowest_ppem,
      direction: direction,
      index_to_loc_format: index_to_loc_format,
      glyph_data_format: glyph_data_format
    }}
  end




  # something required didn't match.
  defp do_parse_head( _ ), do: {:error, :invalid_table, "head"}


  #============================================================================
  # maxp table
  # only care about the number of glyphs

  #--------------------------------------------------------
  defp parse_maxp( info, font_data ) do
    with  { :ok, data } <- get_table_data( info, font_data, "maxp" ),
          {:ok, glyph_count} <- do_parse_maxp( data ) do
      {:ok, Map.put(info, :glyph_count, glyph_count)}
    else
      err ->
        err
    end
  end

  #--------------------------------------------------------
  defp do_parse_maxp( <<
    @version_one :: binary,
    glyph_count :: unsigned-integer-size(16)-big,
    # skip the rest of the table
    _ :: binary
  >> ) do
    {:ok, glyph_count}
  end


  #============================================================================
  # cmap table
  # the point of parsing cmap is to get the supported characters

  #--------------------------------------------------------
  defp parse_cmap( info, font_data ) do
    case get_table_data( info, font_data, "cmap" ) do
      { :ok, data } -> do_parse_cmap( info, data )
      err -> err
    end
  end

  #--------------------------------------------------------
  # platform 0 is unicode only - easiest
  defp do_parse_cmap( info, <<
    0 :: unsigned-integer-size(16)-big,
    num_tables :: unsigned-integer-size(16)-big,
    data :: binary
  >> = cmap_data ) do
    # parse out the encoding sub-tables
    {encoding_types, _data} = do_parse_cmap_encoding_tables( data, num_tables )
    info = Map.put(info, :cmap, encoding_types)

    # part 2. build the char map
    # find a sub-table type we understand ( some form of unicode )
    case do_parse_cmap_get_unicode( encoding_types ) do
      {:ok, offset} ->
        <<
          _ :: binary-size(offset),
          cmap :: binary
        >> = cmap_data

        # calculate the text ranges
        ranges = unicode_cmap_to_ranges( cmap )
        info = Map.put(info, :ranges, ranges)

        # calculate the final range string
        char_space = unicode_ranges_to_string( ranges )
        {:ok, Map.put(info, :char_space, char_space)}
      _ ->
        # just return it as-is
        {:ok, info}
    end

  end
  defp do_parse_cmap( _, _ ) do
    # raise "Invalid Font - failed parsing cmap table. must have a format 0 table"
    {:error, :invalid_cmap}
  end

  #----------------------------------------------
  defp do_parse_cmap_get_unicode( %{unicode: %{offset: offset}} ), do: {:ok, offset}
  defp do_parse_cmap_get_unicode( %{microsoft: %{encoding_id: 1, offset: offset}} ) do
    {:ok, offset}
  end
  defp do_parse_cmap_get_unicode( %{microsoft: %{encoding_id: 10, offset: offset}} ) do
    {:ok, offset}
  end
  defp do_parse_cmap_get_unicode( _ ), do: :error
    
  defp do_parse_cmap_encoding_tables( data, count, encoding_types \\ %{} )
  defp do_parse_cmap_encoding_tables( data, 0, encoding_types ), do: {encoding_types, data}
  defp do_parse_cmap_encoding_tables( <<
    0 :: unsigned-integer-size(16)-big,
    encoding_id :: unsigned-integer-size(16)-big,
    offset :: unsigned-integer-size(32)-big,
    data :: binary
  >>, count, encoding_types ) do
    do_parse_cmap_encoding_tables( data, count - 1,
      Map.put(encoding_types, :unicode, %{encoding_id: encoding_id, offset: offset})
    )
  end
  defp do_parse_cmap_encoding_tables( <<
    1 :: unsigned-integer-size(16)-big,
    encoding_id :: unsigned-integer-size(16)-big,
    offset :: unsigned-integer-size(32)-big,
    data :: binary
  >>, count, encoding_types ) do
    do_parse_cmap_encoding_tables( data, count - 1,
      Map.put(encoding_types, :macintosh, %{encoding_id: encoding_id, offset: offset})
    )
  end
  defp do_parse_cmap_encoding_tables( <<
    3 :: unsigned-integer-size(16)-big,
    encoding_id :: unsigned-integer-size(16)-big,
    offset :: unsigned-integer-size(32)-big,
    data :: binary
  >>, count, encoding_types ) do
    do_parse_cmap_encoding_tables( data, count - 1,
      Map.put(encoding_types, :microsoft, %{encoding_id: encoding_id, offset: offset})
    )
  end

  #----------------------------------------------
  # table format 0 - single byte. very uncommon now
  defp unicode_cmap_to_ranges(<<
    0 :: unsigned-integer-size(16)-big,
    _ :: binary
  >> ) do
    [{32, 255}]
  end

  # type 4 - disconnected ranges. ugh. Pretty common tho
  defp unicode_cmap_to_ranges(<<
    4 :: unsigned-integer-size(16)-big,
    _size :: unsigned-integer-size(16)-big,
    _language :: unsigned-integer-size(16)-big,
    seg_count_x2 :: unsigned-integer-size(16)-big,
    _search_range :: unsigned-integer-size(16)-big,
    _entry_selector :: unsigned-integer-size(16)-big,
    _range_shift :: unsigned-integer-size(16)-big,
    data :: binary
  >> ) do
    seg_count = trunc( seg_count_x2 / 2 )

    # get the end codes
    {end_codes, data} = parse_cmap4_codes(data, seg_count)

    # skip the reserved pad
    << 0 :: unsigned-integer-size(16)-big, data :: binary >> = data

    # get the start coces
    {start_codes, _data} = parse_cmap4_codes(data, seg_count)

    # zip the start and end codes together for a range list
    Enum.zip(start_codes, end_codes)
  end

  # type 6 - densly mapped relatively easy
  defp unicode_cmap_to_ranges(<<
    6 :: unsigned-integer-size(16)-big,
    _size :: unsigned-integer-size(16)-big,
    _language :: unsigned-integer-size(16)-big,
    start_code :: unsigned-integer-size(16)-big,
    num_codes :: unsigned-integer-size(16)-big,
    _ :: binary
  >> ) do
    [{start_code, start_code + num_codes}]
  end


  #----------------------------------------------
  defp unicode_ranges_to_string( ranges ) do
    Enum.reduce(ranges, [], fn({range_start, range_end}, acc) ->
      Enum.reduce(range_start .. range_end, acc, fn(ch, acc) ->
        cond do
#          ch < 32 -> acc                        # control
#          ch >= 0x7F && ch <= 0x9F -> acc       # control other
          ch >= 65535 -> acc                    # too high
          true ->
            chs = << ch :: utf8 >>
            [chs | acc]
        end
      end)
    end)
    |> Enum.reverse
    |> to_string()
  end

  #----------------------------------------------
  defp parse_cmap4_codes(data, count, codes \\ [])
  defp parse_cmap4_codes(data, 0, codes), do: {Enum.reverse(codes), data}
  defp parse_cmap4_codes(
    << code :: unsigned-integer-size(16)-big, data :: binary >>, count, codes
  ) do
    parse_cmap4_codes(data, count - 1, [code | codes])
  end

  #============================================================================
  # kerning table

  #--------------------------------------------------------
  defp parse_kern( info, font_data ) do
    with  { :ok, data } <- get_table_data( info, font_data, "kern" ),
          {:ok, kern} <- do_parse_kern( data ) do
      {:ok, Map.put(info, :kern, kern)}
    else
      _ ->
        # skip kerning data
        {:ok, info}
    end
  end

  #--------------------------------------------------------
  # kerning table format 0
  defp do_parse_kern( <<
    0 :: unsigned-integer-size(16)-big,
    _num_tables :: unsigned-integer-size(16)-big,
    _size :: unsigned-integer-size(32)-big,
    _coverage :: unsigned-integer-size(16)-big,
    _pair_count :: unsigned-integer-size(16)-big,
    _search_range :: unsigned-integer-size(16)-big,
    _entry_selector :: unsigned-integer-size(16)-big,
    _range_shift :: unsigned-integer-size(16)-big,
    data :: binary
  >> ) do
    do_parse_kern_0_entry( data )
  end
  def do_parse_kern_0_entry( kern_data, pairs \\ %{} )
  def do_parse_kern_0_entry( <<>>, pairs ), do: {:ok, pairs}
  def do_parse_kern_0_entry( <<
    left :: unsigned-integer-size(16)-big,
    right :: unsigned-integer-size(16)-big,
    value :: signed-integer-size(16)-big,
    kern_data :: binary
  >>, pairs ) do
    # type 0 has only x information, so set y to 0
    pairs = Map.put( pairs, {left, right}, {value, 0})
    do_parse_kern_0_entry( kern_data, pairs )
  end


  #============================================================================
  # utilities

  defp collapse_ranges( ranges ) when is_list(ranges) do

  end


  #============================================================================
  # utilities

  #--------------------------------------------------------
  # magic number is per the truetype spec.
  # Not a private functions so it can be tested directly.
  @doc false
  def check_master_checksum( bin, adjustment ) do
    case (0xB1B0AFBA - checksum(bin, adjustment)) do
      ^adjustment -> :ok
      _ -> {:error, :invalid_file}
    end
  end

  #--------------------------------------------------------
  # Calculate a table checksum as defined by the truetype standard. This would
  # be much faster as native code, but part of the point is to do this in pure
  # BEAM code for safety. This whole module should not live in a performance
  # critical path.
  #
  # Not a private function so it can be tested directly.
  #
  @doc false
  def checksum( bin, adjustment \\ 0 ) when is_binary(bin) do
    bin = case rem(byte_size(bin), 4) do
      0 -> bin
      1 -> bin <> <<0, 0, 0>>
      2 -> bin <> <<0, 0>>
      3 -> bin <> <<0>>
    end
    checksum = do_checksum( bin ) - adjustment
    <<clamped::unsigned-size(32)>>=<<checksum::unsigned-size(32)>>
    clamped
  end
  defp do_checksum( bin, checksum \\ 0 )
  defp do_checksum( "", checksum ), do: checksum
  defp do_checksum( << long :: unsigned-size(32)-big, bin :: binary >>, checksum ) do
    do_checksum( bin, checksum + long )
  end
  defp do_checksum( _, _ ), do: {:error, :checksum}

  #--------------------------------------------------------
  def get_table_data( %{table_locations: table_locations}, font_data, "head" ) do
    case Map.get(table_locations, "head") do
      nil -> {:error, :missing_table, "head"}
      %{offset: offset, size: table_size, checksum: check} ->
        <<
          _ :: binary-size(offset),
          table_data :: binary-size(table_size),
          _ :: binary
        >> = font_data
        {:ok, table_data, check}
    end
  end

  def get_table_data( %{table_locations: table_locations}, font_data, table_id ) do
    case Map.get(table_locations, table_id) do
      nil -> {:error, :missing_table, table_id}
      loc -> do_get_table_data( font_data, loc )
    end
  end

  def do_get_table_data(
    font_data, %{offset: offset, size: table_size, checksum: checksum}
  ) do
    <<
      _ :: binary-size(offset),
      table_data :: binary-size(table_size),
      _ :: binary
    >> = font_data

    # test the checksum for validity
    case checksum( table_data ) do
      ^checksum -> { :ok, table_data }
      _ -> @bad_checksum
    end
  end
end