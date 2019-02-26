#
#  Created by Boyd Multerer on 24/02/19.
#  Copyright © 2019 Kry10 Industries. All rights reserved.
#

defmodule TruetypeMetrics do
  @moduledoc """
  Documentation for TruetypeMetrics.
  """

  # import IEx

  @version            "0.1.0"


  @version_one          <<0, 1, 0, 0>>
  @magic_number_bin     <<0x5F, 0x0F, 0x3C, 0xF5>>

  @invalid_font         { :error, :invalid_font }
  @bad_checksum         { :error, :bad_checksum }

  @font_epoch {{1904, 1, 1}, {0, 0, 0}}
    |> :calendar.datetime_to_gregorian_seconds()
    
  @unix_epoch {{1970, 1, 1}, {0, 0, 0}}
    |> :calendar.datetime_to_gregorian_seconds()

  @font_to_unix_seconds @font_epoch - @unix_epoch

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
  >> = font_data ) do

    # parse out all the pieces
    with {:ok, tables} <- parse_tables( table_data, table_count ),
    {:ok, head} <- parse_head( font_data, tables ),
    :ok <- check_master_checksum( font_data, head.checksum_adjustment ),
    {:ok, glyph_ids} <- parse_cmap_glyphs_ids(font_data, tables),
    {:ok, hhea, metrics} <- parse_metrics( font_data, tables, glyph_ids ),
    {:ok, kerning} <- parse_kern( font_data, tables, glyph_ids ) do
      
      # calculate a better sha hash of the font
      signature = :crypto.hash( @signature_type, font_data )
      |> Base.url_encode64( padding: false )

      # build the final FontMetrics struct
      {:ok, %FontMetrics{
        version: @version,
        source: %FontMetrics.Source{
          signature_type: @signature_type,
          signature: signature,
          created_at: head.created,
          modified_at: head.modified,          
          font_type: "TrueType"
        },
        # style: head.style,
        direction: head.direction,
        smallest_ppem: head.smallest_ppem,
        units_per_em: head.units_per_em,
        max_box: {head.x_min, head.y_min, head.x_max, head.y_max},
        kerning: kerning,
        ascent: hhea.ascent,
        descent: hhea.descent,
        # line_gap: hhea.line_gap,
        metrics: metrics
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

  defp parse_tables( table_data, count, tables \\ %{} )
  defp parse_tables( _, 0, tables ), do: {:ok, tables}
  defp parse_tables( "", _, _ ), do: {:error, :invalid_table_map}
  defp parse_tables(
    <<
      tag :: binary-size(4),
      checksum :: unsigned-integer-size(32)-big,
      offset :: unsigned-integer-size(32)-big,
      table_size :: unsigned-integer-size(32)-big,
      table_data :: binary
    >>,
    count,
    tables
  ) do
    # build the header for the current table
    th = %{
      checksum: checksum,
      offset: offset,
      size: table_size
    }

    # recurse to get all the entries
    parse_tables( table_data, count - 1, Map.put(tables, tag, th) )
  end
  defp parse_tables( _, _, _ ), do: {:error, :invalid_table_map}


  #============================================================================
  # head table

  #--------------------------------------------------------
  defp parse_head( font_data, tables ) do
    case get_table_data( font_data, tables, "head" ) do
      { :ok, head_data } -> do_parse_head( head_data )
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
    loca_format :: integer-size(16)-big,
    glyph_data_format :: integer-size(16)-big,
  >> ) do
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
      style: style,
      smallest_ppem: lowest_ppem,
      direction: direction,
      loca_format: case loca_format do
        0 -> :short
        1 -> :long
      end,
      glyph_data_format: glyph_data_format
    }}
  end

  # something required didn't match.
  defp do_parse_head( _ ), do: {:error, :invalid_table, "head"}


  #============================================================================
  # metrics tables

    # {:ok, default, advanced} <- parse_metrics( raw_data, tables ),

  #--------------------------------------------------------
  # just gets the advancement data
  defp parse_metrics( font_data, tables, glyph_ids ) do
    with {:ok, data} <- get_table_data( font_data, tables, "hhea" ),
    {:ok, hhea} <- parse_hhea( data ),
    {:ok, data } <- get_table_data( font_data, tables, "hmtx" ),
    {:ok, hmtx} <- parse_hmtx( data, hhea.num_h_metrics - 1 ) do
      # combine it all together..

      # first, get the default character advance
      {default_advance, _lsb} = hmtx[0]

      # The id points to a glyph. We want to point to codepoints
      metrics = Enum.reduce(glyph_ids, %{}, fn({id,codepoints}, out) ->
        adv = case hmtx[id] do
          nil -> default_advance
          {adv, _} -> adv
        end
        Enum.reduce(codepoints, out, &Map.put(&2, &1, adv) )
      end)

      {:ok, hhea, metrics}

    else
      err -> err
    end
  end

  # #--------------------------------------------------------
  # # this version attempts to get the bounding box for each glyph
  # defp parse_metrics( font_data, tables, glyph_ids, loca_format ) do
  #   with {:ok, data} <- get_table_data( font_data, tables, "hhea" ),
  #   {:ok, hhea} <- parse_hhea( data ),
  #   {:ok, data } <- get_table_data( font_data, tables, "hmtx" ),
  #   {:ok, hmtx} <- parse_hmtx( data, hhea.num_h_metrics - 1 ),
  #   {:ok, data } <- get_table_data( font_data, tables, "loca" ),
  #   {:ok, loca} <- parse_loca( data, loca_format ),
  #   {:ok, data } <- get_table_data( font_data, tables, "glyf" ),      
  #   {:ok, glyf_boxes} <- parse_glyf_boxes( data, loca ) do
  #     # combine it all together..

  #     # first, get the default character advance
  #     {default_advance, _lsb} = hmtx[0]

  #     # loop through all the entries in the loca table. Use that to lookup
  #     # the data in the other tables and build the final metrics map
  #     metrics = Enum.reduce(loca, %{}, fn({id,glyph_offset}, out) ->
  #       # The id points to a glyph. We want to point to codepoints.
  #       case glyph_ids[id] do
  #         nil -> out
  #         codepoints ->
  #           metric = case hmtx[id] do
  #             nil -> {default_advance, glyf_boxes[id]} #Map.put( out, id, {default_advance, glyf_boxes[id]} )
  #             {adv,_lsb} -> {adv, glyf_boxes[id]} #Map.put( out, id, {adv, glyf_boxes[id]} )
  #           end
  #           Enum.reduce(codepoints, out, &Map.put(&2, &1, metric) )
  #       end
        
  #     end)

  #     {:ok, hhea, metrics}

  #   else
  #     err -> err
  #   end
  # end

  #--------------------------------------------------------
  defp parse_hhea( <<
    @version_one,
    ascent :: signed-integer-size(16)-big,
    descent :: signed-integer-size(16)-big,
    line_gap :: signed-integer-size(16)-big,

    advance_width_max :: unsigned-integer-size(16)-big,

    min_left_side_bearing :: signed-integer-size(16)-big,
    min_right_side_bearing :: signed-integer-size(16)-big,
    x_max_extent :: signed-integer-size(16)-big,

    caret_slope_rise :: signed-integer-size(16)-big,
    caret_slope_run :: signed-integer-size(16)-big,
    caret_offset :: signed-integer-size(16)-big,

    _:: size(64),   # reserved space

    0 :: signed-integer-size(16)-big,
    num_h_metrics :: unsigned-integer-size(16)-big
  >>  ) do
    {:ok, %{
      version: @version_one,
      ascent: ascent,
      descent: descent,
      line_gap: line_gap,
      advance_width_max: advance_width_max,
      min_left_side_bearing: min_left_side_bearing,
      min_right_side_bearing: min_right_side_bearing,
      x_max_extent: x_max_extent,
      caret_slope_rise: caret_slope_rise,
      caret_slope_run: caret_slope_run,
      caret_offset: caret_offset,
      num_h_metrics: num_h_metrics
    }}
  end

  # something required didn't match.
  defp parse_hhea( _ ), do: {:error, :invalid_table, "hhea"}

  #--------------------------------------------------------
  defp parse_hmtx( metrics, last_metric, out \\ %{}, n \\ 0 )

  defp parse_hmtx(
    <<
      advance_width :: signed-integer-size(16)-big,
      lsb :: signed-integer-size(16)-big
    >>,
    last_metric, out, n
  ) when n == last_metric do
    out = Map.put(out, :default, {advance_width, lsb})
    {:ok, out}
  end

  defp parse_hmtx(
    <<
      advance_width :: signed-integer-size(16)-big,
      lsb :: signed-integer-size(16)-big,
      metrics :: binary
    >>,
    last_metric, out, n 
  ) do
    out = Map.put(out, n, {advance_width, lsb})
    parse_hmtx( metrics, last_metric, out, n + 1 )
  end


  # #--------------------------------------------------------
  # defp parse_loca( loca_data, loca_format, n \\ 0, loca \\ %{} )

  # defp parse_loca( "", _, _, loca ), do: {:ok, loca}

  # defp parse_loca( 
  #   << offset :: unsigned-size(16)-big, loca_data :: binary >>, :short, n, loca
  # ) do
  #   parse_loca( loca_data, :short, n + 1, Map.put(loca, n, offset) )
  # end

  # defp parse_loca(
  #   << offset :: unsigned-size(32)-big, loca_data :: binary >>, :long, n, loca
  # ) do
  #   parse_loca( loca_data, :long, n + 1, Map.put(loca, n, offset) )
  # end

  # defp parse_loca( _, _, _, _ ), do: {:error, :loca}

  # #--------------------------------------------------------
  # # retrieve the bounding box for each glyph
  # defp parse_glyf_boxes( glyf_data, loca ) do
  #   {:ok, Enum.reduce(loca, %{}, fn({id,offset}, out) ->
  #     Map.put(out, id, do_get_glyf_box(glyf_data, offset) )
  #   end)}
  # end

  # defp do_get_glyf_box( glyf_data, offset ) do
  #   <<
  #     _ :: binary-size(offset),
  #     _ :: size(16),              # number of contours. dont' care...
  #     x_min :: signed-size(16)-big,
  #     y_min :: signed-size(16)-big,
  #     x_max :: signed-size(16)-big,
  #     y_max :: signed-size(16)-big,
  #     _ :: binary
  #   >> = glyf_data
  #   {x_min, y_min, x_max, y_max}
  # end


  #============================================================================
  # maxp table
  # only care about the number of glyphs

  # #--------------------------------------------------------
  # defp parse_maxp( info, font_data ) do
  #   with  { :ok, data } <- get_table_data( info, font_data, "maxp" ),
  #         {:ok, glyph_count} <- do_parse_maxp( data ) do
  #     {:ok, Map.put(info, :glyph_count, glyph_count)}
  #   else
  #     err ->
  #       err
  #   end
  # end

  # #--------------------------------------------------------
  # defp do_parse_maxp( <<
  #   @version_one :: binary,
  #   glyph_count :: unsigned-integer-size(16)-big,
  #   # skip the rest of the table
  #   _ :: binary
  # >> ) do
  #   {:ok, glyph_count}
  # end








  #============================================================================
  # cmap table - new version. Return both codepoint -> ind and ind -> codepoint

  #--------------------------------------------------------
  defp parse_cmap_glyphs_ids( font_data, tables ) do
    case get_table_data( font_data, tables, "cmap" ) do
      { :ok, data } -> do_parse_cmap_glyphs_ids( data )
      err -> err
    end
  end

  #--------------------------------------------------------
  defp do_parse_cmap_glyphs_ids(
    <<
      0 :: unsigned-integer-size(16)-big,
      num_tables :: unsigned-integer-size(16)-big,
      data :: binary
    >> = cmap_data
  ) do
    # parse out the encoding sub-tables
    {encoding_types, _data} = do_parse_cmap_encoding_tables( data, num_tables )

    # part 2. build the char map
    # find a sub-table type we understand ( some form of unicode )
    case do_parse_cmap_get_unicode( encoding_types ) do
      {:ok, offset} ->
        << _ :: binary-size(offset), cmap :: binary >> = cmap_data
        do_parse_unicode_cmap_glyphs( cmap )
      _ ->
        {:error, :cmap}
    end
  end

  #--------------------------------------------------------
  # table format 0 - single byte. very uncommon now
  # defp do_parse_unicode_cmap_glyphs(
  #   <<
  #     0 :: unsigned-integer-size(16)-big,
  #     size :: unsigned-integer-size(16)-big,
  #     len :: unsigned-integer-size(16)-big,   # length of sub-table
  #     language :: unsigned-integer-size(16)-big,
  #     sub_table :: binary-size(size),
  #     _ :: binary
  #   >>
  # ) do
  #   pry()
  #   do_parse_unicode_cmap_0( sub_table )
  # end

  # type 4 - disconnected ranges. ugh. Pretty common tho
  defp do_parse_unicode_cmap_glyphs(<<
    4 :: unsigned-integer-size(16)-big,
    _size :: unsigned-integer-size(16)-big,
    _language :: unsigned-integer-size(16)-big,
    seg_count_x2 :: unsigned-integer-size(16)-big,
    _search_range :: unsigned-integer-size(16)-big,
    _entry_selector :: unsigned-integer-size(16)-big,
    _range_shift :: unsigned-integer-size(16)-big,
    end_codes :: binary-size(seg_count_x2),
    0  :: unsigned-integer-size(16)-big,              # reserve pad
    start_codes :: binary-size(seg_count_x2),
    id_deltas :: binary-size(seg_count_x2),
    id_range_offsets :: binary-size(seg_count_x2),
    sub_table :: binary
  >>) do
    ranges = type_4_ranges( start_codes, end_codes, id_deltas, id_range_offsets, seg_count_x2 )

    glyph_ids = Enum.reduce(ranges, %{}, fn
      {f,l,delta,0,_}, acc ->
        # "relatively" easy case. index is the codepoint - the delta
        Enum.reduce(f..l, acc, fn(codepoint, ids) ->
          glyph_id = Integer.mod( codepoint + delta, 65536 )
          Map.put(ids, glyph_id, [codepoint | Map.get(ids, glyph_id, [])])
        end)

      {f,l,_,offset,compensator}, acc ->
        # glyph is obtained by looking it up in the sub_table
        # unfortunately, the offset is from *the position in the offsets table*
        # which may allow for a tricky optimization in C, but totally sucks here.
        # to compensate, subtract the pre-calculated compensator
        Enum.reduce(f..l, acc, fn(codepoint, ids) ->
          skip = ((codepoint - f) * 2) + (offset + compensator)
          glyph_id = lookup_cmap_type_4(sub_table, skip)
          Map.put(ids, glyph_id, [codepoint | Map.get(ids, glyph_id, [])])
        end)
    end)

    {:ok, glyph_ids}
  end

  defp lookup_cmap_type_4( sub_table, skip ) do
    << _ :: binary-size(skip), id :: unsigned-size(16)-big, _ :: binary >> = sub_table
    id
  end


  # type 6 - densly mapped relatively easy
  # defp parse_unicode_cmap(
  # <<
  #   6 :: unsigned-integer-size(16)-big,
  #   size :: unsigned-integer-size(16)-big,
  #   language :: unsigned-integer-size(16)-big,
  #   start_code :: unsigned-integer-size(16)-big,
  #   entry_count :: unsigned-integer-size(16)-big,
  #   sub_table :: binary-size(size),
  #   _ :: binary
  # >> ) do
  #   pry()
  # end



  # defp do_parse_unicode_cmap_0( subtable, n \\ 0, out \\ %{} )
  # defp do_parse_unicode_cmap_0( _, 256, out ), do: out
  # defp do_parse_unicode_cmap_0( << i, bin :: binary >>, n, out ) do
  #   do_parse_unicode_cmap_0( bin, n + 1, Map.put( out, n, i ) )
  # end

  defp type_4_ranges( starts, ends, deltas, offsets, remaining_x2, out \\ [] )
  defp type_4_ranges( "", "", "", "", _, out ), do: Enum.reverse(out)
  defp type_4_ranges(
    << first :: unsigned-size(16)-big, starts :: binary >>,
    << last :: unsigned-size(16)-big, ends :: binary >>,
    << delta :: signed-size(16)-big, deltas :: binary >>,
    << offset :: unsigned-size(16)-big, offsets :: binary >>,
    remaining_x2,
    out
  ) do
    out = [{first, last, delta, offset, -remaining_x2} | out]
    type_4_ranges( starts, ends, deltas, offsets, remaining_x2 - 2, out )
  end



#   #----------------------------------------------
#   defp unicode_ranges_to_string( ranges ) do
#     Enum.reduce(ranges, [], fn({range_start, range_end}, acc) ->
#       Enum.reduce(range_start .. range_end, acc, fn(ch, acc) ->
#         cond do
# #          ch < 32 -> acc                        # control
# #          ch >= 0x7F && ch <= 0x9F -> acc       # control other
#           ch >= 65535 -> acc                    # too high
#           true ->
#             chs = << ch :: utf8 >>
#             [chs | acc]
#         end
#       end)
#     end)
#     |> Enum.reverse
#     |> to_string()
#   end

#   #----------------------------------------------
#   defp parse_cmap4_codes(data, count, codes \\ [])
#   defp parse_cmap4_codes(data, 0, codes), do: {Enum.reverse(codes), data}
#   defp parse_cmap4_codes(
#     << code :: unsigned-integer-size(16)-big, data :: binary >>, count, codes
#   ) do
#     parse_cmap4_codes(data, count - 1, [code | codes])
#   end









  #============================================================================
  # cmap table
  # the point of parsing cmap is to get the supported characters

  # #--------------------------------------------------------
  # defp parse_cmap( info, font_data ) do
  #   case get_table_data( info, font_data, "cmap" ) do
  #     { :ok, data } -> do_parse_cmap( info, data )
  #     err -> err
  #   end
  # end

  # #--------------------------------------------------------
  # # platform 0 is unicode only - easiest
  # defp do_parse_cmap( info, <<
  #   0 :: unsigned-integer-size(16)-big,
  #   num_tables :: unsigned-integer-size(16)-big,
  #   data :: binary
  # >> = cmap_data ) do
  #   # parse out the encoding sub-tables
  #   {encoding_types, _data} = do_parse_cmap_encoding_tables( data, num_tables )
  #   info = Map.put(info, :cmap, encoding_types)

  #   # part 2. build the char map
  #   # find a sub-table type we understand ( some form of unicode )
  #   case do_parse_cmap_get_unicode( encoding_types ) do
  #     {:ok, offset} ->
  #       <<
  #         _ :: binary-size(offset),
  #         cmap :: binary
  #       >> = cmap_data

  #       # calculate the text ranges
  #       ranges = unicode_cmap_to_ranges( cmap )
  #       info = Map.put(info, :ranges, ranges)

  #       # calculate the final range string
  #       char_space = unicode_ranges_to_string( ranges )
  #       {:ok, Map.put(info, :char_space, char_space)}
  #     _ ->
  #       # just return it as-is
  #       {:ok, info}
  #   end

  # end
  # defp do_parse_cmap( _, _ ) do
  #   # raise "Invalid Font - failed parsing cmap table. must have a format 0 table"
  #   {:error, :invalid_cmap}
  # end

  #----------------------------------------------
  defp do_parse_cmap_get_unicode( %{unicode: %{offset: offset}} ), do: {:ok, offset}
  defp do_parse_cmap_get_unicode( %{microsoft: %{encoding_id: 1, offset: offset}} ) do
    {:ok, offset}
  end
  defp do_parse_cmap_get_unicode( %{microsoft: %{encoding_id: 10, offset: offset}} ) do
    {:ok, offset}
  end
  defp do_parse_cmap_get_unicode( _ ), do: :error
    

  #----------------------------------------------
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



  # #----------------------------------------------
  # # table format 0 - single byte. very uncommon now
  # defp unicode_cmap_to_ranges(<<
  #   0 :: unsigned-integer-size(16)-big,
  #   _ :: binary
  # >> ) do
  #   [{32, 255}]
  # end

  # # type 4 - disconnected ranges. ugh. Pretty common tho
  # defp unicode_cmap_to_ranges(<<
  #   4 :: unsigned-integer-size(16)-big,
  #   _size :: unsigned-integer-size(16)-big,
  #   _language :: unsigned-integer-size(16)-big,
  #   seg_count_x2 :: unsigned-integer-size(16)-big,
  #   _search_range :: unsigned-integer-size(16)-big,
  #   _entry_selector :: unsigned-integer-size(16)-big,
  #   _range_shift :: unsigned-integer-size(16)-big,
  #   data :: binary
  # >> ) do
  #   seg_count = trunc( seg_count_x2 / 2 )

  #   # get the end codes
  #   {end_codes, data} = parse_cmap4_codes(data, seg_count)

  #   # skip the reserved pad
  #   << 0 :: unsigned-integer-size(16)-big, data :: binary >> = data

  #   # get the start coces
  #   {start_codes, _data} = parse_cmap4_codes(data, seg_count)

  #   # zip the start and end codes together for a range list
  #   Enum.zip(start_codes, end_codes)
  # end

  # # type 6 - densly mapped relatively easy
  # defp unicode_cmap_to_ranges(<<
  #   6 :: unsigned-integer-size(16)-big,
  #   _size :: unsigned-integer-size(16)-big,
  #   _language :: unsigned-integer-size(16)-big,
  #   start_code :: unsigned-integer-size(16)-big,
  #   num_codes :: unsigned-integer-size(16)-big,
  #   _ :: binary
  # >> ) do
  #   [{start_code, start_code + num_codes}]
  # end


#   #----------------------------------------------
#   defp unicode_ranges_to_string( ranges ) do
#     Enum.reduce(ranges, [], fn({range_start, range_end}, acc) ->
#       Enum.reduce(range_start .. range_end, acc, fn(ch, acc) ->
#         cond do
# #          ch < 32 -> acc                        # control
# #          ch >= 0x7F && ch <= 0x9F -> acc       # control other
#           ch >= 65535 -> acc                    # too high
#           true ->
#             chs = << ch :: utf8 >>
#             [chs | acc]
#         end
#       end)
#     end)
#     |> Enum.reverse
#     |> to_string()
#   end

  # #----------------------------------------------
  # defp parse_cmap4_codes(data, count, codes \\ [])
  # defp parse_cmap4_codes(data, 0, codes), do: {Enum.reverse(codes), data}
  # defp parse_cmap4_codes(
  #   << code :: unsigned-integer-size(16)-big, data :: binary >>, count, codes
  # ) do
  #   parse_cmap4_codes(data, count - 1, [code | codes])
  # end

  #============================================================================
  # kerning table

  #--------------------------------------------------------
  defp parse_kern( font_data, tables, glyph_ids ) do
    case get_table_data( font_data, tables, "kern" ) do
      { :ok, data } -> do_parse_kern( data, glyph_ids )
      _ -> {:ok, %{}}
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
  >>, glyph_ids ) do
    do_parse_kern_0_entry( data, glyph_ids )
  end
  defp do_parse_kern_0_entry( kern_data, glyph_ids, pairs \\ %{} )
  defp do_parse_kern_0_entry( <<>>, _, pairs ), do: {:ok, pairs}
  defp do_parse_kern_0_entry( <<
    left :: unsigned-integer-size(16)-big,
    right :: unsigned-integer-size(16)-big,
    value :: signed-integer-size(16)-big,
    kern_data :: binary
  >>, glyph_ids, pairs ) do

    # the given pair is to glyph_id. which might point to more than one
    # codepoint. We want codepoint pairs, so need to expand this into
    # codepoint space, then add each to the pairs map.
    with {:ok, left_cps} <- Map.fetch( glyph_ids, left ),
    {:ok, right_cps} <- Map.fetch( glyph_ids, right ) do
      pairs = Enum.reduce(left_cps, [], fn(left_cp, acc) ->
        Enum.reduce(right_cps, acc, fn(right_cp, acc) ->
          [ {left_cp, right_cp} | acc ]
        end)
      end)
      |> Enum.reduce( pairs, &Map.put(&2, &1, value) )
      # pairs = Map.put( pairs, {left, right}, value)
      do_parse_kern_0_entry( kern_data, glyph_ids, pairs )
    else
      _ -> do_parse_kern_0_entry( kern_data, glyph_ids, pairs )
    end
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
  def get_table_data( font_data, tables, "head" ) when is_binary(font_data) do
    case Map.get(tables, "head") do
      nil -> {:error, :missing_table, "head"}
      %{offset: offset, size: table_size} ->
        <<
          _ :: binary-size(offset),
          table_data :: binary-size(table_size),
          _ :: binary
        >> = font_data
        {:ok, table_data}
    end
  end

  def get_table_data( font_data, tables, table_id ) when is_binary(font_data) do
    case Map.get(tables, table_id) do
      nil -> {:error, :missing_table, table_id}
      loc -> do_get_table_data( font_data, loc )
    end
  end

  def do_get_table_data(
    font_data, %{offset: offset, size: table_size, checksum: checksum}
  ) when is_binary(font_data) do
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