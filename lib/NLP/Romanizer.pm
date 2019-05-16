################################################################
#                                                              #
# Romanizer                                                    #
#                                                              #
################################################################

package NLP::Romanizer;

use NLP::Chinese;
use NLP::UTF8;
use NLP::utilities;
use JSON;
$utf8 = NLP::UTF8;
$util = NLP::utilities;
$chinesePM = NLP::Chinese;

my $verbosePM = 0;

sub new {
   local($caller) = @_;

   my $object = {};
   my $class = ref( $caller ) || $caller;
   bless($object, $class);
   return $object;
}

sub load_unicode_data {
   local($this, *ht, $filename) = @_;
   # ../../data/UnicodeData.txt

   $n = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
	 if (($unicode_value, $char_name, $general_category, $canon_comb_classes, $bidir_category, $char_decomp_mapping, $decimal_digit_value, $digit_value, $numeric_value, $mirrored, $unicode_1_0_name, $comment_field, $uc_mapping, $lc_mapping, $title_case_mapping) = split(";", $_)) {
            $utf8_code = $utf8->unicode_hex_string2string($unicode_value);
	    $ht{UTF_TO_CHAR_NAME}->{$utf8_code} = $char_name;
	    $ht{UTF_NAME_TO_CODE}->{$char_name} = $utf8_code;
	    $ht{UTF_TO_CAT}->{$utf8_code} = $general_category;
	    $ht{UTF_TO_NUMERIC}->{$utf8_code} = $numeric_value unless $numeric_value eq "";
	    $n++;
	 }
      }
      close(IN);
      # print STDERR "Loaded $n entries from $filename\n";
   } else {
      print STDERR "Can't open $filename\n";
   }
}

sub load_unicode_overwrite_romanization {
   local($this, *ht, $filename) = @_;
   # ../../data/UnicodeDataOverwrite.txt

   $n = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
	 next if /^#/;
         $unicode_value = $util->slot_value_in_double_colon_del_list($_, "u");
         $romanization = $util->slot_value_in_double_colon_del_list($_, "r");
         $numeric = $util->slot_value_in_double_colon_del_list($_, "num");
         $picture = $util->slot_value_in_double_colon_del_list($_, "pic");
	 $syllable_info = $util->slot_value_in_double_colon_del_list($_, "syllable-info");
	 $tone_mark = $util->slot_value_in_double_colon_del_list($_, "tone-mark");
	 $char_name = $util->slot_value_in_double_colon_del_list($_, "name");
	 $entry_processed_p = 0;
         $utf8_code = $utf8->unicode_hex_string2string($unicode_value);
	 if ($unicode_value) {
	    $ht{UTF_TO_CHAR_ROMANIZATION}->{$utf8_code} = $romanization if $romanization;
	    $ht{UTF_TO_NUMERIC}->{$utf8_code} = $numeric if defined($numeric) && ($numeric ne "");
	    $ht{UTF_TO_PICTURE_DESCR}->{$utf8_code} = $picture if $picture;
	    $ht{UTF_TO_SYLLABLE_INFO}->{$utf8_code} = $syllable_info if $syllable_info;
	    $ht{UTF_TO_TONE_MARK}->{$utf8_code} = $tone_mark if $tone_mark;
	    $ht{UTF_TO_CHAR_NAME}->{$utf8_code} = $char_name if $char_name;
	    $entry_processed_p = 1 if $romanization || $numeric || $picture || $syllable_info || $tone_mark;
	 }
	 $n++ if $entry_processed_p;
      }
      close(IN);
   } else {
      print STDERR "Can't open $filename\n";
   }
}

sub load_script_data {
   local($this, *ht, $filename) = @_;
   # ../../data/Scripts.txt

   $n = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
         next unless $script_name = $util->slot_value_in_double_colon_del_list($_, "script-name");
         $abugida_default_vowel_s = $util->slot_value_in_double_colon_del_list($_, "abugida-default-vowel");
         $alt_script_name_s = $util->slot_value_in_double_colon_del_list($_, "alt-script-name");
         $language_s = $util->slot_value_in_double_colon_del_list($_, "language");
         $direction = $util->slot_value_in_double_colon_del_list($_, "direction"); # right-to-left
         $font_family_s = $util->slot_value_in_double_colon_del_list($_, "font-family");
         $ht{SCRIPT_P}->{$script_name} = 1;
	 $ht{SCRIPT_NORM}->{(uc $script_name)} = $script_name;
         $ht{DIRECTION}->{$script_name} = $direction if $direction;
	 foreach $language (split(/,\s*/, $language_s)) {
	    $ht{SCRIPT_LANGUAGE}->{$script_name}->{$language} = 1;
	    $ht{LANGUAGE_SCRIPT}->{$language}->{$script_name} = 1;
	 }
	 foreach $alt_script_name (split(/,\s*/, $alt_script_name_s)) {
	    $ht{SCRIPT_NORM}->{$alt_script_name} = $script_name;
	    $ht{SCRIPT_NORM}->{(uc $alt_script_name)} = $script_name;
	 }
	 foreach $abugida_default_vowel (split(/,\s*/, $abugida_default_vowel_s)) {
	    $ht{SCRIPT_ABUDIGA_DEFAULT_VOWEL}->{$script_name}->{$abugida_default_vowel} = 1 if $abugida_default_vowel;
	 }
	 foreach $font_family (split(/,\s*/, $font_family_s)) {
	    $ht{SCRIPT_FONT}->{$script_name}->{$font_family} = 1 if $font_family;
	 }
	 $n++;
      }
      close(IN);
      # print STDERR "Loaded $n entries from $filename\n";
   } else {
      print STDERR "Can't open $filename\n";
   }
}

sub unicode_hangul_romanization {
   local($this, $s, $pass_through_p) = @_;

   $pass_through_p = 0 unless defined($pass_through_p);
   @leads = split(/\s+/, "g gg n d dd r m b bb s ss - j jj c k t p h");
   # @vowels = split(/\s+/, "a ae ya yai e ei ye yei o oa oai oi yo u ue uei ui yu w wi i");
   @vowels = split(/\s+/, "a ae ya yae eo e yeo ye o wa wai oe yo u weo we wi yu eu yi i");
   @tails = split(/\s+/, "- g gg gs n nj nh d l lg lm lb ls lt lp lh m b bs s ss ng j c k t p h");
   $result = "";
   @chars = $utf8->split_into_utf8_characters($s, "return only chars");
   foreach $char (@chars) {
      $unicode = $utf8->utf8_to_unicode($char);
      if (($unicode >= 0xAC00) && ($unicode <= 0xD7A3)) {
	 $code = $unicode - 0xAC00;
	 $lead_index = int($code / (28*21));
	 $vowel_index = int($code/28) % 21;
	 $tail_index = $code % 28;
	 $rom = $leads[$lead_index] . $vowels[$vowel_index] . $tails[$tail_index];
	 $rom =~ s/-//g;
	 $result .= $rom;
      } elsif ($pass_through_p) {
	 $result .= $char;
      }
   }
   return $result;
}

sub listify_comma_sep_string {
   local($this, $s) = @_;

   @result_list = ();
   return @result_list unless $s =~ /\S/;
   $s = $util->trim2($s);
   my $elem;

   while (($elem, $rest) = ($s =~ /^("(?:\\"|[^"])*"|'(?:\\'|[^'])*'|[^"', ]+),\s*(.*)$/)) {
      push(@result_list, $util->dequote_string($elem));
      $s = $rest;
   }
   push(@result_list, $util->dequote_string($s)) if $s =~ /\S/;

   return @result_list;
}

sub load_romanization_table {
   local($this, *ht, $filename) = @_;
   # ../../data/romanization-table.txt

   $n = 0;
   $line_number = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
         $line_number++;
	 next if /^#/;
         $utf8_source_string = $util->slot_value_in_double_colon_del_list($_, "s");
         $utf8_target_string = $util->slot_value_in_double_colon_del_list($_, "t");
         $utf8_alt_target_string_s = $util->slot_value_in_double_colon_del_list($_, "t-alt");
         $use_alt_in_pointed_p = ($_ =~ /::use-alt-in-pointed\b/);
         $use_only_at_start_of_word_p = ($_ =~ /::use-only-at-start-of-word\b/);
         $use_only_at_end_of_word_p = ($_ =~ /::use-only-at-end-of-word\b/);
	 $utf8_source_string =~ s/\s*$//;
	 $utf8_target_string =~ s/\s*$//;
	 $utf8_alt_target_string_s =~ s/\s*$//;
	 $utf8_target_string =~ s/^"(.*)"$/$1/;
	 $utf8_target_string =~ s/^'(.*)'$/$1/;
	 @utf8_alt_targets = $this->listify_comma_sep_string($utf8_alt_target_string_s);
         $numeric = $util->slot_value_in_double_colon_del_list($_, "num");
	 $numeric =~ s/\s*$//;
         $annotation = $util->slot_value_in_double_colon_del_list($_, "annotation");
	 $annotation =~ s/\s*$//;
         $lang_code = $util->slot_value_in_double_colon_del_list($_, "lcode");
         $prob = $util->slot_value_in_double_colon_del_list($_, "p") || 1;
	 unless (($utf8_target_string eq "") && ($numeric =~ /\d/)) {
	    if ($lang_code) {
               $ht{UTF_CHAR_MAPPING_LANG_SPEC}->{$lang_code}->{$utf8_source_string}->{$utf8_target_string} = $prob;
	    } else {
               $ht{UTF_CHAR_MAPPING}->{$utf8_source_string}->{$utf8_target_string} = $prob;
	    }
	 }
	 if ($use_only_at_start_of_word_p) {
	    if ($lang_code) {
	       $ht{USE_ONLY_AT_START_OF_WORD_LANG_SPEC}->{$lang_code}->{$utf8_source_string}->{$utf8_target_string} = 1;
	    } else {
	       $ht{USE_ONLY_AT_START_OF_WORD}->{$utf8_source_string}->{$utf8_target_string} = 1;
	    }
	 }
	 if ($use_only_at_end_of_word_p) {
	    if ($lang_code) {
	       $ht{USE_ONLY_AT_END_OF_WORD_LANG_SPEC}->{$lang_code}->{$utf8_source_string}->{$utf8_target_string} = 1;
	    } else {
	       $ht{USE_ONLY_AT_END_OF_WORD}->{$utf8_source_string}->{$utf8_target_string} = 1;
	    }
	 }
	 foreach $utf8_alt_target (@utf8_alt_targets) {
	    if ($lang_code) {
               $ht{UTF_CHAR_ALT_MAPPING_LANG_SPEC}->{$lang_code}->{$utf8_source_string}->{$utf8_alt_target} = $prob;
	       $ht{USE_ALT_IN_POINTED_LANG_SPEC}->{$lang_code}->{$utf8_source_string}->{$utf8_alt_target} = 1 if $use_alt_in_pointed_p;
	    } else {
               $ht{UTF_CHAR_ALT_MAPPING}->{$utf8_source_string}->{$utf8_alt_target} = $prob;
	       $ht{USE_ALT_IN_POINTED}->{$utf8_source_string}->{$utf8_alt_target} = 1 if $use_alt_in_pointed_p;
	    }
	    if ($use_only_at_start_of_word_p) {
	       if ($lang_code) {
	          $ht{USE_ALT_ONLY_AT_START_OF_WORD_LANG_SPEC}->{$lang_code}->{$utf8_source_string}->{$utf8_alt_target} = 1;
	       } else {
	          $ht{USE_ALT_ONLY_AT_START_OF_WORD}->{$utf8_source_string}->{$utf8_alt_target} = 1;
	       }
	    }
	    if ($use_only_at_end_of_word_p) {
	       if ($lang_code) {
	          $ht{USE_ALT_ONLY_AT_END_OF_WORD_LANG_SPEC}->{$lang_code}->{$utf8_source_string}->{$utf8_alt_target} = 1;
	       } else {
	          $ht{USE_ALT_ONLY_AT_END_OF_WORD}->{$utf8_source_string}->{$utf8_alt_target} = 1;
	       }
	    }
	 }
	 if ($numeric =~ /\d/) {
	    $ht{UTF_TO_NUMERIC}->{$utf8_source_string} = $numeric;
	 }
	 if ($annotation =~ /\S/) {
	    $ht{UTF_ANNOTATION}->{$utf8_source_string} = $annotation;
	 }
         $n++;
      }
      close(IN);
      # print STDERR "Loaded $n entries from $filename\n";
   } else {
      print STDERR "Can't open $filename\n";
   }
}

sub char_name_to_script {
   local($this, $char_name, *ht) = @_;

   return $cached_result if $cached_result = $ht{CHAR_NAME_TO_SCRIPT}->{$char_name};
   $char_name =~ s/\s+(CONSONANT|LETTER|LIGATURE|SIGN|SYLLABLE|SYLLABICS|VOWEL)\b.*$//;
   my $script_name;
   while ($char_name) {
      last if $script_name = $ht{SCRIPT_NORM}->{(uc $char_name)};
      $char_name =~ s/\s*\S+\s*$//;
   }
   $script_name = "" unless defined($script_name);
   $ht{CHAR_NAME_TO_SCRIPT}->{$char_name} = $script_name;
   return $script_name;
}

sub letter_plus_char_p {
   local($this, $char_name) = @_;

   return $cached_result if $cached_result = $ht{CHAR_NAME_LETTER_PLUS}->{$char_name};
   my $letter_plus_p = ($char_name =~ /\b(?:LETTER|VOWEL SIGN|AU LENGTH MARK|CONSONANT SIGN|SIGN VIRAMA|SIGN PAMAAEH|SIGN COENG|SIGN AL-LAKUNA|SIGN ASAT|SIGN ANUSVARA|SIGN ANUSVARAYA|SIGN BINDI|TIPPI|SIGN NIKAHIT|SIGN CANDRABINDU|SIGN VISARGA|SIGN REAHMUK|SIGN NUKTA|SIGN DOT BELOW|HEBREW POINT)\b/) ? 1 : 0;
   $ht{CHAR_NAME_LETTER_PLUS}->{$char_name} = $letter_plus_p;
   return $letter_plus_p;
}

sub subjoined_char_p {
   local($this, $char_name) = @_;

   return $cached_result if $cached_result = $ht{CHAR_NAME_SUBJOINED}->{$char_name};
   my $subjoined_p = (($char_name =~ /\b(?:SUBJOINED LETTER|VOWEL SIGN|AU LENGTH MARK|EMPHASIS MARK|CONSONANT SIGN|SIGN VIRAMA|SIGN PAMAAEH|SIGN COENG|SIGN ASAT|SIGN ANUSVARA|SIGN ANUSVARAYA|SIGN BINDI|TIPPI|SIGN NIKAHIT|SIGN CANDRABINDU|SIGN VISARGA|SIGN REAHMUK|SIGN DOT BELOW|HEBREW (POINT|PUNCTUATION GERESH)|ARABIC (?:DAMMA|DAMMATAN|FATHA|FATHATAN|HAMZA|KASRA|KASRATAN|MADDAH|SHADDA|SUKUN))\b/)) ? 1 : 0;
   $ht{CHAR_NAME_SUBJOINED}->{$char_name} = $subjoined_p;
   return $subjoined_p;
}

sub new_node_id {
   local($this, *chart_ht) = @_;

   my $n_nodes = $chart_ht{N_NODES};
   $n_nodes++;
   $chart_ht{N_NODES} = $n_nodes;
   return $n_nodes;
}

sub add_node {
   local($this, $s, $start, $end, *chart_ht, $type, $comment) = @_;

   my $node_id = $this->new_node_id(*chart_ht);
   # print STDERR "add_node($node_id, $start-$end): $s [$comment]\n" if $comment =~ /number/;
   # print STDERR "add_node($node_id, $start-$end): $s [$comment]\n" if ($start >= 0) && ($start < 50);
   $chart_ht{NODE_START}->{$node_id} = $start;
   $chart_ht{NODE_END}->{$node_id} = $end;
   $chart_ht{NODES_STARTING_AT}->{$start}->{$node_id} = 1;
   $chart_ht{NODES_ENDING_AT}->{$end}->{$node_id} = 1;
   $chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}->{$node_id} = 1;
   $chart_ht{NODE_TYPE}->{$node_id} = $type;
   $chart_ht{NODE_COMMENT}->{$node_id} = $comment;
   $chart_ht{NODE_ROMAN}->{$node_id} = $s;
   return $node_id;
}

sub get_node_for_span {
   local($this, $start, $end, *chart_ht) = @_;

   return "" unless defined($chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end});
   my @node_ids = sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}};

   return (@node_ids) ? $node_ids[0] : "";
}

sub get_node_for_span_and_type {
   local($this, $start, $end, *chart_ht, $type) = @_;

   return "" unless defined($chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end});
   my @node_ids = sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}};

   foreach $node_id (@node_ids) {
      return $node_id if $chart_ht{NODE_TYPE}->{$node_id} eq $type;
   }
   return "";
}

sub get_node_roman {
   local($this, $node_id, *chart_id, $default) = @_;

   $default = "" unless defined($default);
   my $roman = $chart_ht{NODE_ROMAN}->{$node_id};
   return (defined($roman)) ? $roman : $default;
}

sub set_node_id_slot_value {
   local($this, $node_id, $slot, $value, *chart_id) = @_;
 
   $chart_ht{NODE_SLOT}->{$node_id}->{$slot} = $value;
}

sub copy_slot_values {
   local($this, $old_node_id, $new_node_id, *chart_id, @slots) = @_;

   if (@slots) {
      foreach $slot (keys %{$chart_ht{NODE_SLOT}->{$old_node_id}}) {
         if (($slots[0] eq "all") || $util->member($slot, @slots)) {
	    my $value = $chart_ht{NODE_SLOT}->{$old_node_id}->{$slot};
	    $chart_ht{NODE_SLOT}->{$new_node_id}->{$slot} = $value if defined($value);
	 }
      }
   }
}

sub get_node_id_slot_value {
   local($this, $node_id, $slot, *chart_id, $default) = @_;
 
   $default = "" unless defined($default);
   my $value = $chart_ht{NODE_SLOT}->{$node_id}->{$slot};
   return (defined($value)) ? $value : $default;
}

sub get_node_for_span_with_slot_value {
   local($this, $start, $end, $slot, *chart_id, $default) = @_;

   $default = "" unless defined($default);
   return $default unless defined($chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end});
   my @node_ids = sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}};
   foreach $node_id (@node_ids) {
      my $value = $chart_ht{NODE_SLOT}->{$node_id}->{$slot};
      return $value if defined($value);
   }
   return $default;
}

sub get_node_for_span_with_slot {
   local($this, $start, $end, $slot, *chart_id, $default) = @_;

   $default = "" unless defined($default);
   return $default unless defined($chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end});
   my @node_ids = sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}};
   foreach $node_id (@node_ids) {
      my $value = $chart_ht{NODE_SLOT}->{$node_id}->{$slot};
      return $node_id if defined($value);
   }
   return $default;
}

sub register_new_complex_number_span_segment {
   local($this, $start, $mid, $end, *chart_id, $line_number) = @_;
   # e.g. 4 10 (= 40); 20 5 (= 25)
   # might become part of larger complex number span, e.g. 4 1000 3 100 20 1

   # print STDERR "register_new_complex_number_span_segment $start-$mid-$end\n" if $line_number == 43;
   if (defined($old_start = $chart_ht{COMPLEX_NUMERIC_END_START}->{$mid})) {
      undef($chart_ht{COMPLEX_NUMERIC_END_START}->{$mid});
      $chart_ht{COMPLEX_NUMERIC_START_END}->{$old_start} = $end;
      $chart_ht{COMPLEX_NUMERIC_END_START}->{$end} = $old_start;
   } else {
      $chart_ht{COMPLEX_NUMERIC_START_END}->{$start} = $end;
      $chart_ht{COMPLEX_NUMERIC_END_START}->{$end} = $start;
   }
}

sub romanize_by_token_with_caching {
   local($this, $s, $lang_code, $output_style, *ht, *pinyin_ht, $initial_char_offset, $control, $line_number) = @_;

   $control = "" unless defined($control);
   my $return_chart_p = ($control =~ /return chart/i);
   return $this->romanize($s, $lang_code, $output_style, *ht, *pinyin_ht, $initial_char_offset, $control, $line_number)
     if $return_chart_p;
   my $result = "";
   my @separators = ();
   my @tokens = ();
   $s =~ s/\n$//; # Added May 2, 2019 as bug-fix (duplicate empty lines)
   while (($sep, $token, $rest) = ($s =~ /^(\s*)(\S+)(.*)$/)) {
      push(@separators, $sep);
      push(@tokens, $token);
      $s = $rest;
   }
   push(@separators, $s);
   while (@tokens) {
      my $sep = shift @separators;
      my $token = shift @tokens;
      $result .= $sep;
      if ($token =~ /^[\x00-\x7F]*$/) { # all ASCII
         $result .= $token;
      } else {
         my $rom_token = $ht{CACHED_ROMANIZATION}->{$lang_code}->{$token};
         unless (defined($rom_token)) {
            $rom_token = $this->romanize($token, $lang_code, $output_style, *ht, *pinyin_ht, $initial_char_offset, $control, $line_number);
	    $ht{CACHED_ROMANIZATION}->{$lang_code}->{$token} = $rom_token if defined($rom_token);
         }
         $result .= $rom_token;
      }
   }
   my $sep = shift @separators;
   $result .= $sep if defined($sep);

   return $result;
}

sub romanize {
   local($this, $s, $lang_code, $output_style, *ht, *pinyin_ht, $initial_char_offset, $control, $line_number) = @_;

   $initial_char_offset = 0 unless defined($initial_char_offset);
   $control = "" unless defined($control);
   my $return_chart_p = ($control =~ /return chart/i);
   $line_number = "" unless defined($line_number);
   my @chars = $utf8->split_into_utf8_characters($s, "return only chars");
   my $n_characters = $#chars + 1;
   %chart_ht = ();
   $chart_ht{N_CHARS} = $n_characters;
   $chart_ht{N_NODES} = 0;
   my $char = "";
   my $char_name = "";
   my $prev_script = "";
   my $current_script = "";
   my $script_start = 0;
   my $script_end = 0;
   my $prev_letter_plus_script = "";
   my $current_letter_plus_script = "";
   my $letter_plus_script_start = 0;
   my $letter_plus_script_end = 0;
   my $log ="";
   my $n_right_to_left_chars = 0;
   my $n_left_to_right_chars = 0;
   my $hebrew_word_start = ""; # used to identify Hebrew words with points
   my $hebrew_word_contains_point = 0;
   my $current_word_start = "";
   my $current_word_script = "";

   # prep
   foreach $i ((0 .. ($#chars + 1))) {
      if ($i <= $#chars) {
         $char = $chars[$i];
         $chart_ht{ORIG_CHAR}->{$i} = $char;
         $char_name = $ht{UTF_TO_CHAR_NAME}->{$char} || "";
         $chart_ht{CHAR_NAME}->{$i} = $char_name;
         $current_script = $this->char_name_to_script($char_name, *ht);
	 $current_script_direction = $ht{DIRECTION}->{$current_script} || '';
	 if ($current_script_direction eq 'right-to-left') {
	    $n_right_to_left_chars++;
	 } elsif (($char =~ /^[a-z]$/i) || ! ($char =~ /^[\x00-\x7F]$/)) {
	    $n_left_to_right_chars++;
	 }
         $chart_ht{CHAR_SCRIPT}->{$i} = $current_script;
         $chart_ht{SCRIPT_SEGMENT_START}->{$i} = ""; # default value, to be updated later
         $chart_ht{SCRIPT_SEGMENT_END}->{$i} = "";   # default value, to be updated later
         $chart_ht{LETTER_TOKEN_SEGMENT_START}->{$i} = ""; # default value, to be updated later
         $chart_ht{LETTER_TOKEN_SEGMENT_END}->{$i} = "";   # default value, to be updated later
	 $subjoined_char_p = $this->subjoined_char_p($char_name);
	 $chart_ht{CHAR_SUBJOINED}->{$i} = $subjoined_char_p;
	 $letter_plus_char_p = $this->letter_plus_char_p($char_name);
	 $chart_ht{CHAR_LETTER_PLUS}->{$i} = $letter_plus_char_p;
	 $current_letter_plus_script = ($letter_plus_char_p) ? $current_script : "";
         $numeric_value = $ht{UTF_TO_NUMERIC}->{$char};
         $numeric_value = "" unless defined($numeric_value);
         $annotation = $ht{UTF_ANNOTATION}->{$char};
         $annotation = "" unless defined($annotation);
	 $chart_ht{CHAR_NUMERIC_VALUE}->{$i} = $numeric_value;
	 $chart_ht{CHAR_ANNOTATION}->{$i} = $annotation;
         $syllable_info = $ht{UTF_TO_SYLLABLE_INFO}->{$char} || "";
	 $chart_ht{CHAR_SYLLABLE_INFO}->{$i} = $syllable_info;
         $tone_mark = $ht{UTF_TO_TONE_MARK}->{$char} || "";
	 $chart_ht{CHAR_TONE_MARK}->{$i} = $tone_mark;
      } else {
	 $char = "";
         $char_name = "";
	 $current_script = "";
	 $current_letter_plus_script = "";
      }
      if ($char_name =~ /^HEBREW (LETTER|POINT|PUNCTUATION GERESH) /) {
	 $hebrew_word_start = $i if $hebrew_word_start eq "";
	 $hebrew_word_contains_point = 1 if $char_name =~ /^HEBREW POINT /;
      } elsif ($hebrew_word_start ne "") {
	 if ($hebrew_word_contains_point) {
	    foreach $j (($hebrew_word_start .. ($i-1))) {
	       $chart_ht{CHAR_PART_OF_POINTED_HEBREW_WORD}->{$j} = 1;
	    }
	    $chart_ht{CHAR_START_OF_WORD}->{$hebrew_word_start} = 1;
	    $chart_ht{CHAR_END_OF_WORD}->{($i-1)} = 1;
	 }
	 $hebrew_word_start = "";
	 $hebrew_word_contains_point = 0;
      }
      my $part_of_word_p = $current_script
                        && ($this->letter_plus_char_p($char_name)
                         || $this->subjoined_char_p($char_name)
			 || ($char_name =~ /\b(LETTER|SYLLABLE|SYLLABICS|LIGATURE)\b/));
      if (($current_word_start ne "")
       && ((! $part_of_word_p)
        || ($current_script ne $current_word_script))) {
         # END OF WORD
	 $chart_ht{CHAR_START_OF_WORD}->{$current_word_start} = 1;
	 $chart_ht{CHAR_END_OF_WORD}->{($i-1)} = 1;
	 my $word = join("", @chars[$current_word_start .. ($i-1)]);
	 $chart_ht{WORD_START_END}->{$current_word_start}->{$i} = $word;
	 $chart_ht{WORD_END_START}->{$i}->{$current_word_start} = $word;
	 # print STDERR "Word ($current_word_start-$i): $word ($current_word_script)\n";
	 $current_word_start = "";
	 $current_word_script = "";
      }
      if ($part_of_word_p && ($current_word_start eq "")) {
         # START OF WORD
	 $current_word_start = $i;
	 $current_word_script = $current_script;
      }
      # print STDERR "$i char: $char ($current_script)\n";
      unless ($current_script eq $prev_script) {
	 if ($prev_script && ($i-1 >= $script_start)) {
	    my $script_end = $i;
            $chart_ht{SCRIPT_SEGMENT_START_TO_END}->{$script_start} = $script_end;
            $chart_ht{SCRIPT_SEGMENT_END_TO_START}->{$script_end} = $script_start;
	    foreach $i (($script_start .. $script_end)) {
               $chart_ht{SCRIPT_SEGMENT_START}->{$i} = $script_start;
               $chart_ht{SCRIPT_SEGMENT_END}->{$i} = $script_end;
	    }
	    # print STDERR "Script segment $script_start-$script_end: $prev_script\n";
	 }
	 $script_start = $i;
      }
      unless ($current_letter_plus_script eq $prev_letter_plus_script) {
	 if ($prev_letter_plus_script && ($i-1 >= $letter_plus_script_start)) {
	    my $letter_plus_script_end = $i;
            $chart_ht{LETTER_TOKEN_SEGMENT_START_TO_END}->{$letter_plus_script_start} = $letter_plus_script_end;
            $chart_ht{LETTER_TOKEN_SEGMENT_END_TO_START}->{$letter_plus_script_end} = $letter_plus_script_start;
	    foreach $i (($letter_plus_script_start .. $letter_plus_script_end)) {
               $chart_ht{LETTER_TOKEN_SEGMENT_START}->{$i} = $letter_plus_script_start;
               $chart_ht{LETTER_TOKEN_SEGMENT_END}->{$i} = $letter_plus_script_end;
	    }
	    # print STDERR "Script token segment $letter_plus_script_start-$letter_plus_script_end: $prev_letter_plus_script\n";
	 }
	 $letter_plus_script_start = $i;
      }
      $prev_script = $current_script;
      $prev_letter_plus_script = $current_letter_plus_script;
   }
   $ht{STRING_IS_DOMINANTLY_RIGHT_TO_LEFT}->{$s} = 1 if $n_right_to_left_chars > $n_left_to_right_chars;

   # main
   my $i = 0;
   while ($i <= $#chars) {
      my $char = $chart_ht{ORIG_CHAR}->{$i};
      my $current_script = $chart_ht{CHAR_SCRIPT}->{$i};
      $chart_ht{CHART_CONTAINS_SCRIPT}->{$current_script} = 1;
      my $script_segment_start = $chart_ht{SCRIPT_SEGMENT_START}->{$i};
      my $script_segment_end = $chart_ht{SCRIPT_SEGMENT_END}->{$i};
      my $char_name = $chart_ht{CHAR_NAME}->{$i};
      my $subjoined_char_p = $chart_ht{CHAR_SUBJOINED}->{$i};
      my $letter_plus_char_p = $chart_ht{CHAR_LETTER_PLUS}->{$i};
      my $numeric_value = $chart_ht{CHAR_NUMERIC_VALUE}->{$i};
      my $annotation = $chart_ht{CHAR_ANNOTATION}->{$i};
      # print STDERR "  $char_name annotation: $annotation\n" if $annotation;
      my $tone_mark = $chart_ht{CHAR_TONE_MARK}->{$i};
      my $found_char_mapping_p = 0;
      my $prev_char_name = ($i >= 1) ? $chart_ht{CHAR_NAME}->{($i-1)} : "";
      my $prev2_script = ($i >= 2) ? $chart_ht{CHAR_SCRIPT}->{($i-2)} : "";
      my $prev_script = ($i >= 1) ? $chart_ht{CHAR_SCRIPT}->{($i-1)} : "";
      my $next_script = ($i < $#chars) ? $chart_ht{CHAR_SCRIPT}->{($i+1)} : "";
      my $prev2_letter_plus_char_p = ($i >= 2) ? $chart_ht{CHAR_LETTER_PLUS}->{($i-2)} : 0;
      my $prev_letter_plus_char_p = ($i >= 1) ? $chart_ht{CHAR_LETTER_PLUS}->{($i-1)} : 0;
      my $next_letter_plus_char_p = ($i < $#chars) ? $chart_ht{CHAR_LETTER_PLUS}->{($i+1)} : 0;
      my $next_index = $i + 1;
      foreach $string_length (reverse(1 .. 6)) {
	 next if ($i + $string_length-1) > $#chars;
	 my $multi_char_substring = join("", @chars[$i..($i+$string_length-1)]);
	 my @mappings = keys %{$ht{UTF_CHAR_MAPPING_LANG_SPEC}->{$lang_code}->{$multi_char_substring}};
	 @mappings = keys %{$ht{UTF_CHAR_MAPPING}->{$multi_char_substring}} unless @mappings;
	 foreach $mapping (@mappings) {
	    next if $mapping =~ /\(__.*__\)/;
	    if ($ht{USE_ONLY_AT_START_OF_WORD_LANG_SPEC}->{$lang_code}->{$multi_char_substring}->{$mapping}
	     || $ht{USE_ONLY_AT_START_OF_WORD}->{$multi_char_substring}->{$mapping}) {
	       next unless $chart_ht{CHAR_START_OF_WORD}->{$i};
	    }
	    if ($ht{USE_ONLY_AT_END_OF_WORD_LANG_SPEC}->{$lang_code}->{$multi_char_substring}->{$mapping}
	     || $ht{USE_ONLY_AT_END_OF_WORD}->{$multi_char_substring}->{$mapping}) {
	       next unless $chart_ht{CHAR_END_OF_WORD}->{($i+$string_length-1)};
	    }
	    $node_id = $this->add_node($mapping, $i, $i+$string_length, *chart_ht, "", "multi-char-mapping");
	    $next_index = $i + $string_length;
	    $found_char_mapping_p = 1;
	    if ($annotation) {
	       @annotation_elems = split(/,\s*/, $annotation);
	       foreach $annotation_elem (@annotation_elems) {
	          if (($a_slot, $a_value) = ($annotation_elem =~ /^(\S+?):(\S+)\s*$/)) {
	             $this->set_node_id_slot_value($node_id, $a_slot, $a_value, *chart_ht);
		  } else {
	             $this->set_node_id_slot_value($node_id, $annotation_elem, 1, *chart_ht);
		  }
	       }
	    }
	 }
	 my @alt_mappings = keys %{$ht{UTF_CHAR_ALT_MAPPING_LANG_SPEC}->{$lang_code}->{$multi_char_substring}};
	 @alt_mappings = keys %{$ht{UTF_CHAR_ALT_MAPPING}->{$multi_char_substring}} unless @alt_mappings;
	 foreach $alt_mapping (@alt_mappings) {
	    if ($chart_ht{CHAR_PART_OF_POINTED_HEBREW_WORD}->{$i}) {
	       next unless
	          $ht{USE_ALT_IN_POINTED_LANG_SPEC}->{$lang_code}->{$multi_char_substring}->{$alt_mapping}
	       || $ht{USE_ALT_IN_POINTED}->{$multi_char_substring}->{$alt_mapping};
	    }
	    if ($ht{USE_ALT_ONLY_AT_START_OF_WORD_LANG_SPEC}->{$lang_code}->{$multi_char_substring}->{$alt_mapping}
	     || $ht{USE_ALT_ONLY_AT_START_OF_WORD}->{$multi_char_substring}->{$alt_mapping}) {
	       next unless $chart_ht{CHAR_START_OF_WORD}->{$i};
	    }
	    if ($ht{USE_ALT_ONLY_AT_END_OF_WORD_LANG_SPEC}->{$lang_code}->{$multi_char_substring}->{$alt_mapping}
	     || $ht{USE_ALT_ONLY_AT_END_OF_WORD}->{$multi_char_substring}->{$alt_mapping}) {
	       next unless $chart_ht{CHAR_END_OF_WORD}->{($i+$string_length-1)};
	    }
	    $node_id = $this->add_node($alt_mapping, $i, $i+$string_length, *chart_ht, "alt", "multi-char-mapping");
	    if ($annotation) {
	       @annotation_elems = split(/,\s*/, $annotation);
	       foreach $annotation_elem (@annotation_elems) {
	          if (($a_slot, $a_value) = ($annotation_elem =~ /^(\S+?):(\S+)\s*$/)) {
	             $this->set_node_id_slot_value($node_id, $a_slot, $a_value, *chart_ht);
	          } else {
	             $this->set_node_id_slot_value($node_id, $annotation_elem, 1, *chart_ht);
	          }
	       }
	    }
	 }
      }
      unless ($found_char_mapping_p) {
	 my $prev_node_id = $this->get_node_for_span($i-4, $i, *chart_ht)
			 || $this->get_node_for_span($i-3, $i, *chart_ht)
			 || $this->get_node_for_span($i-2, $i, *chart_ht)
			 || $this->get_node_for_span($i-1, $i, *chart_ht);
	 my $prev_char_roman = ($prev_node_id) ? $this->get_node_roman($prev_node_id, *chart_id) : "";
	 my $prev_node_start = ($prev_node_id) ? $chart_ht{NODE_START}->{$prev_node_id} : "";

	 # Number
         if (($numeric_value =~ /\d/)
	       && (! ($char_name =~ /SUPERSCRIPT/))) {
	    my $prev_numeric_value = $this->get_node_for_span_with_slot_value($i-1, $i, "numeric-value", *chart_id);
	    my $sep = "";
	    $sep = " " if ($char_name =~ /^vulgar fraction /i) && ($prev_numeric_value =~ /\d/);
	    $node_id = $this->add_node("$sep$numeric_value", $i, $i+1, *chart_ht, "", "number");
	    $this->set_node_id_slot_value($node_id, "numeric-value", $numeric_value, *chart_ht);
	    if ((($prev_numeric_value =~ /\d/) && ($numeric_value =~ /\d\d/))
	     || (($prev_numeric_value =~ /\d\d/) && ($numeric_value =~ /\d/))) {
	       # pull in any other parts of single digits
	       my $j = 1;
	       # pull in any single digits adjoining on left
	       if ($prev_numeric_value =~ /^\d$/) {
		  while (1) {
	             if (($i-$j-1 >= 0)
		      && defined($digit_value = $this->get_node_for_span_with_slot_value($i-$j-1, $i-$j, "numeric-value", *chart_id))
		      && ($digit_value =~ /^\d$/)) {
		        $j++;
		     } elsif (($i-$j-2 >= 0)
                           && ($chart_ht{ORIG_CHAR}->{($i-$j-1)} =~ /^[.,]$/)
		           && defined($digit_value = $this->get_node_for_span_with_slot_value($i-$j-2, $i-$j-1, "numeric-value", *chart_id))
		           && ($digit_value =~ /^\d$/)) {
		        $j += 2;
		     } else {
		        last;
		     }
		  }
	       }
	       # pull in any single digits adjoining on right
	       my $k = 0;
	       if ($numeric_value =~ /^\d$/) {
	          while (1) {
	             if (defined($next_numeric_value = $chart_ht{CHAR_NUMERIC_VALUE}->{($i+$k+1)})
		      && ($next_numeric_value =~ /^\d$/)) {
		        $k++;
		     } else {
		        last;
		     }
		  }
	       }
	       $this->register_new_complex_number_span_segment($i-$j, $i, $i+$k+1, *chart_ht, $line_number);
	    }
	    if ($chinesePM->string_contains_utf8_cjk_unified_ideograph_p($char)
	     && ($tonal_translit = $chinesePM->tonal_pinyin($char, *pinyin_ht, ""))) {
	       $de_accented_translit = $util->de_accent_string($tonal_translit);
	       if ($numeric_value =~ /^(10000|1000000000000|10000000000000000)$/) {
                  $chart_ht{NODE_TYPE}->{$node_id} = "alt"; # keep, but demote
	          $alt_node_id = $this->add_node($de_accented_translit, $i, $i+1, *chart_ht, "", "CJK");
	       } else {
	          $alt_node_id = $this->add_node($de_accented_translit, $i, $i+1, *chart_ht, "alt", "CJK");
	       }
            }

	 # ASCII
	 } elsif ($char =~ /^[\x00-\x7F]$/) {
	    $this->add_node($char, $i, $i+1, *chart_ht, "", "ASCII"); # ASCII character, incl. control characters

         # Emoji, dingbats, pictographs
         } elsif ($char =~ /^(\xE2[\x98-\x9E]|\xF0\x9F[\x8C-\xA7])/) {
            $this->add_node($char, $i, $i+1, *chart_ht, "", "pictograph");

         # Hangul (Korean)
         } elsif (($char =~ /^[\xEA-\xED]/)
	       && ($romanized_char = $this->unicode_hangul_romanization($char))) {
	    $this->add_node($romanized_char, $i, $i+1, *chart_ht, "", "Hangul");

         # CJK (Chinese, Japanese, Korean)
	 } elsif ($chinesePM->string_contains_utf8_cjk_unified_ideograph_p($char)
	       && ($tonal_translit = $chinesePM->tonal_pinyin($char, *pinyin_ht, ""))) {
	    $de_accented_translit = $util->de_accent_string($tonal_translit);
	    $this->add_node($de_accented_translit, $i, $i+1, *chart_ht, "", "CJK");

	 # Virama (cancel preceding vowel in Abudiga scripts)
	 } elsif ($char_name =~ /\bSIGN (?:VIRAMA|AL-LAKUNA|ASAT|COENG|PAMAAEH)\b/) {
	    # VIRAMA: cancel preceding default vowel (in Abudiga scripts)
	    if (($prev_script eq $current_script)
	     && (($prev_char_roman_consonant, $prev_char_roman_vowel) = ($prev_char_roman =~ /^(.*[bcdfghjklmnpqrstvwxyz])([aeiou]+)$/i))
	     && ($ht{SCRIPT_ABUDIGA_DEFAULT_VOWEL}->{$current_script}->{(lc $prev_char_roman_vowel)})) {
	       $this->add_node($prev_char_roman_consonant, $prev_node_start, $i+1, *chart_ht, "", "virama");
	    } else {
	       $this->add_node("", $i, $i+1, *chart_ht, "", "unexpected-virama");
	    }

	 # Nukta (special (typically foreign) variant)
	 } elsif ($char_name =~ /\bSIGN (?:NUKTA)\b/) {
	    # NUKTA (dot): indicates special (typically foreign) variant; normally covered by multi-mappings
	    if ($prev_script eq $current_script) {
	       my $node_id = $this->add_node($prev_char_roman, $prev_node_start, $i+1, *chart_ht, "", "nukta");
               $this->copy_slot_values($prev_node_id, $node_id, *chart_id, "all");
	       $this->set_node_id_slot_value($node_id, "nukta", 1, *chart_ht);
	    } else {
	       $this->add_node("", $i, $i+1, *chart_ht, "", "unexpected-nukta");
	    }

	 # Zero-width character, incl. zero width space/non-joiner/joiner, left-to-right/right-to-left mark
	 } elsif ($char =~ /^\xE2\x80[\x8B-\x8F\xAA-\xAE]$/) {
	    if ($prev_node_id) {
	       my $node_id = $this->add_node($prev_char_roman, $prev_node_start, $i+1, *chart_ht, "", "zero-width-char");
               $this->copy_slot_values($prev_node_id, $node_id, *chart_id, "all");
	    } else {
	       $this->add_node("", $i, $i+1, *chart_ht, "", "zero-width-char");
	    }
	 } elsif (($char =~ /^\xEF\xBB\xBF$/) && $prev_node_id) { # OK to leave byte-order-mark at beginning of line
	    my $node_id = $this->add_node($prev_char_roman, $prev_node_start, $i+1, *chart_ht, "", "zero-width-char");
            $this->copy_slot_values($prev_node_id, $node_id, *chart_id, "all");

	 # Tone mark
	 } elsif ($tone_mark) {
	    if ($prev_script eq $current_script) {
	       my $node_id = $this->add_node($prev_char_roman, $prev_node_start, $i+1, *chart_ht, "", "tone-mark");
               $this->copy_slot_values($prev_node_id, $node_id, *chart_id, "all");
	       $this->set_node_id_slot_value($node_id, "tone-mark", $tone_mark, *chart_ht);
	    } else {
	       $this->add_node("", $i, $i+1, *chart_ht, "", "unexpected-tone-mark");
	    }

	 # Diacritic
	 } elsif (($char_name =~ /\b(ACCENT|TONE|COMBINING DIAERESIS|COMBINING DIAERESIS BELOW|COMBINING MACRON|COMBINING VERTICAL LINE ABOVE|COMBINING DOT ABOVE RIGHT|COMBINING TILDE|COMBINING CYRILLIC|MUUSIKATOAN|TRIISAP)\b/) && ($ht{UTF_TO_CAT}->{$char} =~ /^Mn/)) {
	    if ($prev_script eq $current_script) {
	       my $node_id = $this->add_node($prev_char_roman, $prev_node_start, $i+1, *chart_ht, "", "diacritic");
               $this->copy_slot_values($prev_node_id, $node_id, *chart_id, "all");
	       $diacritic = lc $char_name;
	       $diacritic =~ s/^.*(?:COMBINING CYRILLIC|COMBINING|SIGN)\s+//i;
	       $diacritic =~ s/^.*(ACCENT|TONE)/$1/i;
	       $diacritic =~ s/^\s*//;
	       $this->set_node_id_slot_value($node_id, "diacritic", $diacritic, *chart_ht);
	       # print STDERR "diacritic: $diacritic\n";
	    } else {
	       $this->add_node("", $i, $i+1, *chart_ht, "", "unexpected-diacritic");
	    }

	 # Romanize to find out more
	 } elsif ($char_name) {
	    if (defined($romanized_char = $this->romanize_char_at_position($i, $lang_code, $output_style, *ht, *chart_ht))) {
	       # print STDERR "ROM l.$line_number/$i: $romanized_char\n" if $line_number =~ /^[12]$/;
	       print STDOUT "ROM l.$line_number/$i: $romanized_char\n" if $verbosePM;

	       # Empty string mapping
	       if ($romanized_char eq "\"\"") {
	          $this->add_node("", $i, $i+1, *chart_ht, "", "empty-string-mapping");
               # consider adding something for implausible romanizations of length 6+

	       # Syllabic suffix in Abudiga languages, e.g. -m, -ng
               } elsif (($romanized_char =~ /^\+(H|M|N|NG)$/i)
		     && ($prev_script eq $current_script)
		     && ($ht{SCRIPT_ABUDIGA_DEFAULT_VOWEL}->{$current_script}->{"a"})) {
		  my $core_suffix = $romanized_char;
		  $core_suffix =~ s/^\+//;
		  if ($prev_char_roman =~ /[aeiou]$/i) {
	             $this->add_node($core_suffix, $i, $i+1, *chart_ht, "", "syllable-end-consonant");
		  } else {
	             $this->add_node(join("", $prev_char_roman, "a", $core_suffix), $prev_node_start, $i+1, *chart_ht, "", "syllable-end-consonant-with-added-a");
	             $this->add_node(join("", "a", $core_suffix), $i, $i+1, *chart_ht, "backup", "syllable-end-consonant");
		  }

	       # Japanese special cases
	       } elsif ($char_name =~ /(?:HIRAGANA|KATAKANA) LETTER SMALL Y/) {
		  if (($prev_script eq $current_script)
		   && (($prev_char_roman_consonant) = ($prev_char_roman =~ /^(.*[bcdfghjklmnpqrstvwxyz])i$/i))) {
                     unless ($this->get_node_for_span_and_type($prev_node_start, $i+1, *chart_ht, "")) {
	                $this->add_node("$prev_char_roman_consonant$romanized_char", $prev_node_start, $i+1, *chart_ht, "", "japanese-contraction");
		     }
		  } else {
	             $this->add_node($romanized_char, $i, $i+1, *chart_ht, "", "unexpected-japanese-contraction-character");
		  }
	       } elsif (($prev_script =~ /^(HIRAGANA|KATAKANA)$/i)
		     && ($char_name eq "KATAKANA-HIRAGANA PROLONGED SOUND MARK") # Choonpu
		     && (($prev_char_roman_vowel) = ($prev_char_roman =~ /([aeiou])$/i))) {
	          $this->add_node("$prev_char_roman$prev_char_roman_vowel", $prev_node_start, $i+1, *chart_ht, "", "japanese-vowel-lengthening");
	       } elsif (($current_script =~ /^(Hiragana|Katakana)$/i)
	             && ($char_name =~ /^(HIRAGANA|KATAKANA) LETTER SMALL TU$/i) # Sokuon/Sukun
		     && ($next_script eq $current_script)
	             && ($romanized_next_char = $this->romanize_char_at_position_incl_multi($i+1, $lang_code, $output_style, *ht, *chart_ht))
		     && (($doubled_consonant) = ($romanized_next_char =~ /^(ch|[bcdfghjklmnpqrstwz])/i))) {
		  # Note: $romanized_next_char could be part of a multi-character mapping
		  # print STDERR "current_script: $current_script char_name: $char_name next_script: $next_script romanized_next_char: $romanized_next_char doubled_consonant: $doubled_consonant\n";
		  $doubled_consonant = "t" if $doubled_consonant eq "ch";
	          $this->add_node($doubled_consonant, $i, $i+1, *chart_ht, "", "japanese-consonant-doubling");
 
               # Greek small letter mu to micro-sign (instead of to "m") as used in abbreviations for microgram/micrometer/microliter/microsecond/micromolar/microfarad etc.
               } elsif (($char_name eq "GREEK SMALL LETTER MU")
	             && (! ($prev_script =~ /^GREEK$/))
		     && ($i < $#chars)
		     && ($chart_ht{ORIG_CHAR}->{($i+1)} =~ /^[cfgjlmstv]$/i)) {
	          $this->add_node("\xC2\xB5", $i, $i+1, *chart_ht, "", "greek-mu-to-micro-sign");

	       # Gurmukhi addak (doubles following consonant)
               } elsif (($current_script eq "Gurmukhi")
		     && ($char_name eq "GURMUKHI ADDAK")) {
                  if (($next_script eq $current_script)
		   && ($romanized_next_char = $this->romanize_char_at_position_incl_multi($i+1, $lang_code, $output_style, *ht, *chart_ht))
	           && (($doubled_consonant) = ($romanized_next_char =~ /^([bcdfghjklmnpqrstvwxz])/i))) {
	             $this->add_node($doubled_consonant, $i, $i+1, *chart_ht, "", "gurmukhi-consonant-doubling");
		  } else {
	             $this->add_node("'", $i, $i+1, *chart_ht, "", "gurmukhi-unexpected-addak");
		  }

	       # Subjoined character
               } elsif ($subjoined_char_p
		     && ($prev_script eq $current_script)
	             && (($prev_char_roman_consonant, $prev_char_roman_vowel) = ($prev_char_roman =~ /^(.*[bcdfghjklmnpqrstvwxyz])([aeiou]+)$/i))
	             && ($ht{SCRIPT_ABUDIGA_DEFAULT_VOWEL}->{$current_script}->{(lc $prev_char_roman_vowel)})) {
		  my $new_roman = "$prev_char_roman_consonant$romanized_char";
	          $this->add_node($new_roman, $prev_node_start, $i+1, *chart_ht, "", "subjoined-character");
	          # print STDERR "  Subjoin l.$line_number/$i: $new_roman\n" if $line_number =~ /^[12]$/;

	       # Thai special case: written-pre-consonant-spoken-post-consonant
	       } elsif (($char_name =~ /THAI CHARACTER/)
		     && ($prev_script eq $current_script)
		     && ($chart_ht{CHAR_SYLLABLE_INFO}->{($i-1)} =~ /written-pre-consonant-spoken-post-consonant/i)
		     && ($prev_char_roman =~ /^[aeiou]+$/i)
		     && ($romanized_char =~ /^[bcdfghjklmnpqrstvwxyz]/)) {
	          $this->add_node("$romanized_char$prev_char_roman", $prev_node_start, $i+1, *chart_ht, "", "thai-vowel-consonant-swap");

	       # Thai special case: THAI CHARACTER O ANG (U+0E2D "\xE0\xB8\xAD")
	       } elsif ($char_name eq "THAI CHARACTER O ANG") {
		  if ($prev_script ne $current_script) {
	             $this->add_node("", $i, $i+1, *chart_ht, "", "thai-initial-o-ang-drop");
		  } elsif ($next_script ne $current_script) {
	             $this->add_node("", $i, $i+1, *chart_ht, "", "thai-final-o-ang-drop");
		  } else {
	             my $romanized_next_char = $this->romanize_char_at_position($i+1, $lang_code, $output_style, *ht, *chart_ht);
		     my $romanized_prev2_char = $this->romanize_char_at_position($i-2, $lang_code, $output_style, *ht, *chart_ht);
		     if (($prev_char_roman =~ /^[bcdfghjklmnpqrstvwxz]+$/i)
		      && ($romanized_next_char =~ /^[bcdfghjklmnpqrstvwxz]+$/i)) {
	                $this->add_node("o", $i, $i+1, *chart_ht, "", "thai-middle-o-ang"); # keep between consonants
		     } elsif (($prev2_script eq $current_script)
			   && 0
		           && ($prev_char_name =~ /^THAI CHARACTER MAI [A-Z]+$/) # Thai tone
			   && ($romanized_prev2_char =~ /^[bcdfghjklmnpqrstvwxz]+$/i)
			   && ($romanized_next_char =~ /^[bcdfghjklmnpqrstvwxz]+$/i)) {
	                $this->add_node("o", $i, $i+1, *chart_ht, "", "thai-middle-o-ang"); # keep between consonant+tone-mark and consonant
		     } else {
	                $this->add_node("", $i, $i+1, *chart_ht, "", "thai-middle-o-ang-drop"); # drop next to vowel
		     }
		  }

	       # Romanization with space
	       } elsif ($romanized_char =~ /\s/) {
	          $this->add_node($char, $i, $i+1, *chart_ht, "", "space");

	       # Tibetan special cases
	       } elsif ($current_script eq "Tibetan") {

                  if ($subjoined_char_p
		   && ($prev_script eq $current_script)
		   && $prev_letter_plus_char_p
	           && ($prev_char_roman =~ /^[bcdfghjklmnpqrstvwxyz]+$/i)) {
	             $this->add_node("$prev_char_roman$romanized_char", $prev_node_start, $i+1, *chart_ht, "", "subjoined-tibetan-character");
		  } elsif ($romanized_char =~ /^-A$/i) {
	             my $romanized_next_char = $this->romanize_char_at_position($i+1, $lang_code, $output_style, *ht, *chart_ht);
		     if (! $prev_letter_plus_char_p) {
	                $this->add_node("'", $i, $i+1, *chart_ht, "", "tibetan-frontal-dash-a");
		     } elsif (($prev_script eq $current_script)
		           && ($next_script eq $current_script)
			   && ($prev_char_roman =~ /[bcdfghjklmnpqrstvwxyz]$/)
			   && ($romanized_next_char =~ /^[aeiou]/)) {
			$this->add_node("a'", $i, $i+1, *chart_ht, "", "tibetan-medial-dash-a");
		     } elsif (($prev_script eq $current_script)
		           && ($next_script eq $current_script)
			   && ($prev_char_roman =~ /[aeiou]$/)
			   && ($romanized_next_char =~ /[aeiou]/)) {
			$this->add_node("'", $i, $i+1, *chart_ht, "", "tibetan-reduced-medial-dash-a");
		     } elsif (($prev_script eq $current_script)
		           && (! ($prev_char_roman =~ /[aeiou]/))
			   && (! $next_letter_plus_char_p)) {
			$this->add_node("a", $i, $i+1, *chart_ht, "", "tibetan-final-dash-a");
		     } else {
			$this->add_node("a", $i, $i+1, *chart_ht, "", "unexpected-tibetan-dash-a");
		     }
		  } elsif (($romanized_char =~ /^[AEIOU]/i)
			&& ($prev_script eq $current_script)
		        && ($prev_char_roman =~ /^A$/i)
			&& (! $prev2_letter_plus_char_p)) {
	             $this->add_node($romanized_char, $prev_node_start, $i+1, *chart_ht, "", "tibetan-dropped-word-initial-a");
		  } else {
	             $this->add_node($romanized_char, $i, $i+1, *chart_ht, "", "standard-unicode-based-romanization");
		  }

               # Khmer (for MUUSIKATOAN etc. see under "Diacritic" above)
	       } elsif (($current_script eq "Khmer")
	             && (($char_roman_consonant, $char_roman_vowel) = ($romanized_char =~ /^(.*[bcdfghjklmnpqrstvwxyz])([ao]+)-$/i))) {
	           my $romanized_next_char = $this->romanize_char_at_position($i+1, $lang_code, $output_style, *ht, *chart_ht);
		   if (($next_script eq $current_script)
		    && ($romanized_next_char =~ /^[aeiouy]/i)) {
                      $this->add_node($char_roman_consonant, $i, $i+1, *chart_ht, "", "khmer-vowel-drop");
		   } else {
                      $this->add_node("$char_roman_consonant$char_roman_vowel", $i, $i+1, *chart_ht, "", "khmer-standard-unicode-based-romanization");
		   }

	       # Abudiga add default vowel
	       } elsif ((@abudiga_default_vowels = sort keys %{$ht{SCRIPT_ABUDIGA_DEFAULT_VOWEL}->{$current_script}})
		     && ($abudiga_default_vowel = $abudiga_default_vowels[0])
	             && ($romanized_char =~ /^[bcdfghjklmnpqrstvwxyz]+$/i)) {
		  my $new_roman = join("", $romanized_char, $abudiga_default_vowel);
	          $this->add_node($new_roman, $i, $i+1, *chart_ht, "", "standard-unicode-based-romanization-plus-abudiga-default-vowel");
	          # print STDERR "  Abudiga add default vowel l.$line_number/$i: $new_roman\n" if $line_number =~ /^[12]$/;

	       # Standard romanization
	       } else {
	          $node_id = $this->add_node($romanized_char, $i, $i+1, *chart_ht, "", "standard-unicode-based-romanization");
	       }
	    } else {
	       $this->add_node($char, $i, $i+1, *chart_ht, "", "unexpected-original");
	    }
	 } elsif (defined($romanized_char = $this->romanize_char_at_position($i, $lang_code, $output_style, *ht, *chart_ht))
	       && ((length($romanized_char) <= 2)
	        || ($ht{UTF_TO_CHAR_ROMANIZATION}->{$char}))) { # or from unicode_overwrite_romanization table
	    $romanized_char =~ s/^""$//;
	    $this->add_node($romanized_char, $i, $i+1, *chart_ht, "", "romanized-without-character-name");
	 } else {
	    $this->add_node($char, $i, $i+1, *chart_ht, "", "unexpected-original-without-character-name");
	 }
      }
      $i = $next_index;
   }

   $this->schwa_deletion(0, $n_characters, *chart_ht, $lang_code);
   $this->default_vowelize_tibetan(0, $n_characters, *chart_ht, $lang_code, $line_number) if $chart_ht{CHART_CONTAINS_SCRIPT}->{"Tibetan"};
   $this->assemble_numbers_in_chart(*chart_ht, $line_number);

   $result = $this->best_romanized_string(0, $n_characters, *chart_ht) unless $return_chart_p;

   if ($verbosePM) {
      my $logfile = "/nfs/isd/ulf/cgi-mt/amr-tmp/uroman-log.txt";
      $util->append_to_file($logfile, $log) if $log && (-r $logfile);
   }

   return *chart_ht if $return_chart_p;
   return $result;
}

sub string_to_json_string {
   local($this, $s) = @_;

   utf8::decode($s);
   my $j = JSON->new->utf8->encode([$s]);
   $j =~ s/^\[(.*)\]$/$1/;
   return $j;
}

sub chart_to_json_romanization_elements {
   local($this, $chart_start, $chart_end, *chart_ht, $line_number) = @_;

   my $result = "";
   my $start = $chart_start;
   my $end;
   while ($start < $chart_end) {
      $end = $this->find_end_of_rom_segment($start, $chart_end, *chart_ht);
      my @best_romanizations;
      if (($end && ($start < $end))
       && (@best_romanizations = $this->best_romanizations($start, $end, *chart_ht))) {
         $orig_segment = $this->orig_string_at_span($start, $end, *chart_ht);
         $next_start = $end;
      } else {
         $orig_segment = $chart_ht{ORIG_CHAR}->{$start};
         @best_romanizations = ($orig);
	 $next_start = $start + 1;
      }
      $exclusive_end = $end - 1;
      # $guarded_orig = $util->string_guard($orig_segment);
      $guarded_orig = $this->string_to_json_string($orig_segment);
      $result .= "  { \"line\": $line_number, \"start\": $start, \"end\": $exclusive_end, \"orig\": $guarded_orig, \"roms\": [";
      foreach $i ((0 .. $#best_romanizations)) {
         my $rom = $best_romanizations[$i];
	 # my $guarded_rom = $util->string_guard($rom);
	 my $guarded_rom = $this->string_to_json_string($rom);
	 $result .= " { \"rom\": $guarded_rom";
	 # $result .= ", \"alt\": true" if $i >= 1;
	 $result .= " }";
	 $result .= "," if $i < $#best_romanizations;
      }
      $result .= " ] },\n";
      $start = $next_start;
   }
   return $result;
}

sub default_vowelize_tibetan {
   local($this, $chart_start, $chart_end, *chart_ht, $lang_code, $line_number) = @_;

   # my $verbose = ($line_number == 103);
   # print STDERR "\nStart default_vowelize_tibetan l.$line_number $chart_start-$chart_end\n" if $verbose;
   my $token_start = $chart_start;
   my $next_token_start = $chart_start;
   while (($token_start = $next_token_start) < $chart_end) {
      $next_token_start = $token_start + 1;

      next unless $chart_ht{CHAR_LETTER_PLUS}->{$token_start};
      my $current_script = $chart_ht{CHAR_SCRIPT}->{$token_start};
         next unless ($current_script eq "Tibetan");
      my $token_end = $chart_ht{LETTER_TOKEN_SEGMENT_START_TO_END}->{$token_start};
	 next unless $token_end;
	 next unless $token_end > $token_start;
      $next_token_start = $token_end;

      my $start = $token_start;
      my $end;
      my @node_ids = ();
      while ($start < $token_end) {
         $end = $this->find_end_of_rom_segment($start, $chart_end, *chart_ht);
	 last unless $end && ($end > $start);
         my @alt_node_ids = sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}};
         last unless @alt_node_ids;
         push(@node_ids, $alt_node_ids[0]);
	 $start = $end;
      }
      my $contains_vowel_p = 0;
      my @romanizations = ();
      foreach $node_id (@node_ids) {
         my $roman = $chart_ht{NODE_ROMAN}->{$node_id};
	 $roman = "" unless defined($roman);
	 push(@romanizations, $roman);
	 $contains_vowel_p = 1 if $roman =~ /[aeiou]/i;
      }
      # print STDERR "   old: $token_start-$token_end @romanizations\n" if $verbose;
      unless ($contains_vowel_p) {
	 my $default_vowel_target_index;
	 if ($#node_ids <= 1) {
	    $default_vowel_target_index = 0;
	 } elsif ($romanizations[$#romanizations] eq "s") {
	    if ($romanizations[($#romanizations-1)] eq "y") {
	       $default_vowel_target_index = $#romanizations-1;
	    } else {
	       $default_vowel_target_index = $#romanizations-2;
	    }
	 } else {
	    $default_vowel_target_index = $#romanizations-1;
	 }
	 $romanizations[$default_vowel_target_index] .= "a";
	 my $old_node_id = $node_ids[$default_vowel_target_index];
         my $old_start = $chart_ht{NODE_START}->{$old_node_id};
         my $old_end = $chart_ht{NODE_END}->{$old_node_id};
	 my $old_roman = $chart_ht{NODE_ROMAN}->{$old_node_id};
	 my $new_roman = $old_roman . "a";
	 my $new_node_id = $this->add_node($new_roman, $old_start, $old_end, *chart_ht, "", "tibetan-default-vowel");
         $this->copy_slot_values($old_node_id, $new_node_id, *chart_id, "all");
         $chart_ht{NODE_TYPE}->{$old_node_id} = "backup"; # keep, but demote
      }
      if (($romanizations[0] eq "'")
       && ($#romanizations >= 1)
       && ($romanizations[1] =~ /^[o]$/)) {
	 my $old_node_id = $node_ids[0];
         my $old_start = $chart_ht{NODE_START}->{$old_node_id};
         my $old_end = $chart_ht{NODE_END}->{$old_node_id};
	 my $new_node_id = $this->add_node("", $old_start, $old_end, *chart_ht, "", "tibetan-delete-apostrophe");
	 $this->copy_slot_values($old_node_id, $new_node_id, *chart_id, "all");
	 $chart_ht{NODE_TYPE}->{$old_node_id} = "alt"; # keep, but demote
      }
      if (($#node_ids >= 1)
       && ($romanizations[$#romanizations] =~ /^[bcdfghjklmnpqrstvwxz]+y$/)) {
	 my $old_node_id = $node_ids[$#romanizations];
         my $old_start = $chart_ht{NODE_START}->{$old_node_id};
         my $old_end = $chart_ht{NODE_END}->{$old_node_id};
	 my $old_roman = $chart_ht{NODE_ROMAN}->{$old_node_id};
	 my $new_roman = $old_roman . "a";
	 my $new_node_id = $this->add_node($new_roman, $old_start, $old_end, *chart_ht, "", "tibetan-syllable-final-vowel");
	 $this->copy_slot_values($old_node_id, $new_node_id, *chart_id, "all");
	 $chart_ht{NODE_TYPE}->{$old_node_id} = "alt"; # keep, but demote
      }
      foreach $old_node_id (@node_ids) {
         my $old_roman = $chart_ht{NODE_ROMAN}->{$old_node_id};
	 next unless $old_roman =~ /-a/;
	 my $old_start = $chart_ht{NODE_START}->{$old_node_id};
	 my $old_end = $chart_ht{NODE_END}->{$old_node_id};
	 my $new_roman = $old_roman;
	 $new_roman =~ s/-a/a/;
	 my $new_node_id = $this->add_node($new_roman, $old_start, $old_end, *chart_ht, "", "tibetan-syllable-delete-dash");
	 $this->copy_slot_values($old_node_id, $new_node_id, *chart_id, "all");
	 $chart_ht{NODE_TYPE}->{$old_node_id} = "alt"; # keep, but demote
      }
   }
}

sub schwa_deletion {
   local($this, $chart_start, $chart_end, *chart_ht, $lang_code) = @_;
   # delete word-final simple "a" in Devanagari (e.g. nepaala -> nepaal)
   # see Wikipedia article "Schwa deletion in Indo-Aryan languages"

   if ($chart_ht{CHART_CONTAINS_SCRIPT}->{"Devanagari"}) {
      my $script_start = $chart_start;
      my $next_script_start = $chart_start;
      while (($script_start = $next_script_start) < $chart_end) {
         $next_script_start = $script_start + 1;

         my $current_script = $chart_ht{CHAR_SCRIPT}->{$script_start};
	    next unless ($current_script eq "Devanagari");
	 my $script_end = $chart_ht{SCRIPT_SEGMENT_START_TO_END}->{$script_start};
	    next unless $script_end;
	    next unless $script_end - $script_start >= 2;
	 $next_script_start = $script_end;
	 my $end_node_id = $this->get_node_for_span($script_end-1, $script_end, *chart_ht);
	    next unless $end_node_id;
         my $end_roman = $chart_ht{NODE_ROMAN}->{$end_node_id};
	 next unless ($end_consonant) = ($end_roman =~ /^([bcdfghjklmnpqrstvwxz]+)a$/i);
	 my $prev_node_id = $this->get_node_for_span($script_end-4, $script_end-1, *chart_ht)
	                 || $this->get_node_for_span($script_end-3, $script_end-1, *chart_ht)
	                 || $this->get_node_for_span($script_end-2, $script_end-1, *chart_ht);
	    next unless $prev_node_id;
         my $prev_roman = $chart_ht{NODE_ROMAN}->{$prev_node_id};
	 next unless $prev_roman =~ /[aeiou]/i;
	 # TO DO: check further back for vowel (e.g. if $prev_roman eq "r" due to vowel cancelation)
	 
         $chart_ht{NODE_TYPE}->{$end_node_id} = "alt"; # keep, but demote
	 # print STDERR "* Schwa deletion " . ($script_end-1) . "-$script_end $end_roman->$end_consonant\n";
	 $this->add_node($end_consonant, $script_end-1, $script_end, *chart_ht, "", "devanagari-with-deleted-final-schwa");
      }
   }
}

sub best_romanized_string {
   local($this, $chart_start, $chart_end, *chart_ht) = @_;

   my $result = "";
   my $start = $chart_start;
   my $end;
   while ($start < $chart_end) {
      $end = $this->find_end_of_rom_segment($start, $chart_end, *chart_ht);
      if ($end && ($start < $end)) {
         my @best_romanizations = $this->best_romanizations($start, $end, *chart_ht);
	 my $best_romanization = (@best_romanizations) ? $best_romanizations[0] : undef;
	 if (defined($best_romanization)) {
            $result .= $best_romanization;
	    $start = $end;
	 } else {
            $result .= $chart_ht{ORIG_CHAR}->{$start};
	    $start++;
	 }
      } else {
         $result .= $chart_ht{ORIG_CHAR}->{$start};
	 $start++;
      }
   }
   return $result;
}

sub orig_string_at_span {
   local($this, $start, $end, *chart_ht) = @_;

   my $result = "";
   foreach $i (($start .. ($end-1))) {
      $result .= $chart_ht{ORIG_CHAR}->{$i};
   }
   return $result;
}

sub find_end_of_rom_segment {
   local($this, $start, $chart_end, *chart_ht) = @_;

   my @ends = sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}};
   my $end_index = $#ends;
   while (($end_index >= 0) && ($ends[$end_index] > $chart_end)) {
      $end_index--;
   }
   if (($end_index >= 0)
    && defined($end = $ends[$end_index])
    && ($start < $end)) {
      return $end;
   } else {
      return "";
   }
}

sub best_romanizations {
   local($this, $start, $end, *chart_ht) = @_;

   @regular_romanizations = ();
   @alt_romanizations = ();
   @backup_romanizations = ();

   foreach $node_id (sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}}) {
      my $type = $chart_ht{NODE_TYPE}->{$node_id};
      my $roman = $chart_ht{NODE_ROMAN}->{$node_id};
      if (! defined($roman)) {
         # ignore
      } elsif (($type eq "backup") && ! defined($backup_romanization)) {
         push(@backup_romanizations, $roman) unless $util->member($roman, @backup_romanizations);
      } elsif (($type eq "alt") && ! defined($alt_romanization)) {
         push(@alt_romanizations, $roman) unless $util->member($roman, @alt_romanizations);
      } else {
         push(@regular_romanizations, $roman) unless $util->member($roman, @regular_romanizations);
      }
   }
   @regular_alt_romanizations = sort @regular_romanizations;
   foreach $alt_romanization (sort @alt_romanizations) {
      push(@regular_alt_romanizations, $alt_romanization) unless $util->member($alt_romanization, @regular_alt_romanizations);
   }
   return @regular_alt_romanizations if @regular_alt_romanizations;
   return sort @backup_romanizations;
}

sub join_alt_romanizations_for_viz {
   local($this, @list) = @_;

   my @viz_romanizations = ();

   foreach $alt_rom (@list) {
      if ($alt_rom eq "") {
         push(@viz_romanizations, "-");
      } else {
         push(@viz_romanizations, $alt_rom);
      }
   }
   return join(", ", @viz_romanizations);
}

sub markup_orig_rom_strings {
   local($this, $chart_start, $chart_end, *ht, *chart_ht, *pinyin_ht, $last_group_id_index) = @_;

   my $marked_up_rom = "";
   my $marked_up_orig = "";
   my $start = $chart_start;
   my $end;
   while ($start < $chart_end) {
      my $segment_start = $start;
      my $segment_end = $start+1;
      my $end = $this->find_end_of_rom_segment($start, $chart_end, *chart_ht);
      my $rom_segment = "";
      my $orig_segment = "";
      my $rom_title = "";
      my $orig_title = "";
      my $contains_alt_romanizations = 0;
      if ($end) {
	 $segment_end = $end;
         my @best_romanizations = $this->best_romanizations($start, $end, *chart_ht);
	 my $best_romanization = (@best_romanizations) ? $best_romanizations[0] : undef;
	 if (defined($best_romanization)) {
            $rom_segment .= $best_romanization;
            $orig_segment .= $this->orig_string_at_span($start, $end, *chart_ht);
	    $segment_end = $end;
	    if ($#best_romanizations >= 1) {
	       $rom_title .= $util->guard_html("Alternative romanizations: " . $this->join_alt_romanizations_for_viz(@best_romanizations) . "\n");
	       $contains_alt_romanizations = 1;
	    }
	 } else {
	    my $segment = $this->orig_string_at_span($start, $start+1, *chart_ht);
            $rom_segment .= $segment;
            $orig_segment .= $segment;
	    $segment_end = $start+1;
	 }
	 $start = $segment_end;
      } else {
         $rom_segment .= $chart_ht{ORIG_CHAR}->{$start};
         $orig_segment .= $this->orig_string_at_span($start, $start+1, *chart_ht);
	 $segment_end = $start+1;
	 $start = $segment_end;
      }
      my $next_char = $chart_ht{ORIG_CHAR}->{$segment_end};
      my $next_char_is_combining_p = $this->char_is_combining_char($next_char, *ht);
      while ($next_char_is_combining_p
          && ($segment_end < $chart_end)
	  && ($end = $this->find_end_of_rom_segment($segment_end, $chart_end, *chart_ht))
	  && ($end > $segment_end)
	  && (@best_romanizations = $this->best_romanizations($segment_end, $end, *chart_ht))
	  && defined($best_romanization = $best_romanizations[0])) {
         $orig_segment .= $this->orig_string_at_span($segment_end, $end, *chart_ht);
	 $rom_segment .= $best_romanization;
	 if ($#best_romanizations >= 1) {
	    $rom_title .= $util->guard_html("Alternative romanizations: " . $this->join_alt_romanizations_for_viz(@best_romanizations) . "\n");
	    $contains_alt_romanizations = 1;
	 }
	 $segment_end = $end;
	 $start = $segment_end;
	 $next_char = $chart_ht{ORIG_CHAR}->{$segment_end};
	 $next_char_is_combining_p = $this->char_is_combining_char($next_char, *ht);
      }
      foreach $i (($segment_start .. ($segment_end-1))) {
	 $orig_title .= "+&#x200E; &#x200E;" unless $orig_title eq "";
         my $char = $chart_ht{ORIG_CHAR}->{$i};
	 my $numeric = $ht{UTF_TO_NUMERIC}->{$char};
	 $numeric = "" unless defined($numeric);
	 my $pic_descr = $ht{UTF_TO_PICTURE_DESCR}->{$char};
	 $pic_descr = "" unless defined($pic_descr);
	 if (($char =~ /^[\xE3-\xE9][\x80-\xBF]{2,2}$/) && $chinesePM->string_contains_utf8_cjk_unified_ideograph_p($char)) {
	    my $unicode = $utf8->utf8_to_unicode($char);
	    $orig_title .= "CJK Unified Ideograph U+" . (uc sprintf("%04x", $unicode)) . "\n";
	    $orig_title .= "Chinese: $tonal_translit\n" if $tonal_translit = $chinesePM->tonal_pinyin($char, *pinyin_ht, "");
	    $orig_title .= "Number: $numeric\n" if $numeric =~ /\d/;
	 } elsif ($char_name = $ht{UTF_TO_CHAR_NAME}->{$char}) {
	    $orig_title .= "$char_name\n";
	    $orig_title .= "Number: $numeric\n" if $numeric =~ /\d/;
	    $orig_title .= "Picture: $pic_descr\n" if $pic_descr =~ /\S/;
	 } else {
	    my $unicode = $utf8->utf8_to_unicode($char);
	    if (($unicode >= 0xAC00) && ($unicode <= 0xD7A3)) {
	       $orig_title .= "Hangul syllable U+" . (uc sprintf("%04x", $unicode)) . "\n";
	    } else {
	       $orig_title .= "Unicode character U+" . (uc sprintf("%04x", $unicode)) . "\n";
	    }
	 }
      }
      (@non_ascii_roms) = ($rom_segment =~ /([\xC0-\xFF][\x80-\xBF]*)/g);
      foreach $char (@non_ascii_roms) {
	 my $char_name = $ht{UTF_TO_CHAR_NAME}->{$char};
         my $unicode = $utf8->utf8_to_unicode($char);
	 my $unicode_s = "U+" . (uc sprintf("%04x", $unicode));
	 if ($char_name) {
	    $rom_title .= "$char_name\n";
	 } else {
	    $rom_title .= "$unicode_s\n";
	 }
      }
      $last_group_id_index++;
      $rom_title =~ s/\s*$//;
      $rom_title =~ s/\n/&#xA;/g;
      $orig_title =~ s/\s*$//;
      $orig_title =~ s/\n/&#xA;&#x200E;/g;
      $orig_title = "&#x202D;" . $orig_title . "&#x202C;";
      my $rom_title_clause  = ($rom_title  eq "") ? "" : " title=\"$rom_title\"";
      my $orig_title_clause = ($orig_title eq "") ? "" : " title=\"$orig_title\"";
      my $alt_rom_clause = ($contains_alt_romanizations) ? "border-bottom:1px dotted;" : "";
      $marked_up_rom .= "<span id=\"span-$last_group_id_index-1\" onmouseover=\"highlight_elems('span-$last_group_id_index','1');\" onmouseout=\"highlight_elems('span-$last_group_id_index','0');\" style=\"color:#00BB00;$alt_rom_clause\"$rom_title_clause>" . $util->guard_html($rom_segment) . "<\/span>";
      $marked_up_orig .= "<span id=\"span-$last_group_id_index-2\" onmouseover=\"highlight_elems('span-$last_group_id_index','1');\" onmouseout=\"highlight_elems('span-$last_group_id_index','0');\"$orig_title_clause>" . $util->guard_html($orig_segment) . "<\/span>";
      if (($last_char = $chart_ht{ORIG_CHAR}->{($segment_end-1)})
       && ($last_char_name = $ht{UTF_TO_CHAR_NAME}->{$last_char})
       && ($last_char_name =~ /^(FULLWIDTH COLON|FULLWIDTH COMMA|FULLWIDTH RIGHT PARENTHESIS|IDEOGRAPHIC COMMA|IDEOGRAPHIC FULL STOP|RIGHT CORNER BRACKET|TIBETAN MARK .*)$/)) {
         $marked_up_orig .= "<wbr>";
         $marked_up_rom .= "<wbr>";
      }
   }
   return ($marked_up_rom, $marked_up_orig, $last_group_id_index);
}

sub romanizations_with_alternatives {
   local($this, *ht, *chart_ht, *pinyin_ht, $chart_start, $chart_end) = @_;

   $chart_start = 0 unless defined($chart_start);
   $chart_end = $chart_ht{N_CHARS} unless defined($chart_end);
   my $result = "";
   my $start = $chart_start;
   my $end;
   # print STDOUT "romanizations_with_alternatives $chart_start-$chart_end\n";
   while ($start < $chart_end) {
      my $segment_start = $start;
      my $segment_end = $start+1;
      my $end = $this->find_end_of_rom_segment($start, $chart_end, *chart_ht);
      my $rom_segment = "";
      # print STDOUT "  $start-$end\n";
      if ($end) {
	 $segment_end = $end;
         my @best_romanizations = $this->best_romanizations($start, $end, *chart_ht);
         # print STDOUT "  $start-$end @best_romanizations\n";
	 if (@best_romanizations) {
	    if ($#best_romanizations == 0) {
	       $rom_segment .= $best_romanizations[0];
	    } else {
	       $rom_segment .= "{" . join("|", @best_romanizations) . "}";
	    }
	    $segment_end = $end;
	 } else {
	    my $segment = $this->orig_string_at_span($start, $start+1, *chart_ht);
            $rom_segment .= $segment;
	    $segment_end = $start+1;
	 }
	 $start = $segment_end;
      } else {
         $rom_segment .= $chart_ht{ORIG_CHAR}->{$start};
	 $segment_end = $start+1;
	 $start = $segment_end;
      }
      # print STDOUT "  $start-$end ** $rom_segment\n";
      $result .= $rom_segment;
   }
   return $result;
}

sub quick_romanize {
   local($this, $s, $lang_code, *ht) = @_;

   my $result = "";
   my @chars = $utf8->split_into_utf8_characters($s, "return only chars");
   while (@chars) {
      my $found_match_in_table_p = 0;
      foreach $string_length (reverse(1..4)) {
	 next if ($string_length-1) > $#chars;
	 $multi_char_substring = join("", @chars[0..($string_length-1)]);
	 my @mappings = keys %{$ht{UTF_CHAR_MAPPING_LANG_SPEC}->{$lang_code}->{$multi_char_substring}};
	 @mappings = keys %{$ht{UTF_CHAR_MAPPING}->{$multi_char_substring}} unless @mappings;
	 if (@mappings) {
	    my $mapping = $mappings[0];
	    $result .= $mapping;
            foreach $_ ((1 .. $string_length)) {
	       shift @chars;
	    }
	    $found_match_in_table_p = 1;
	    last;
	 }
      }
      unless ($found_match_in_table_p) {
	 $result .= $chars[0];
	 shift @chars;
      }
   }
   return $result;
}

sub char_is_combining_char {
   local($this, $c, *ht) = @_;

   return 0 unless $c;
   my $category = $ht{UTF_TO_CAT}->{$c};
   return 0 unless $category;
   return $category =~ /^M/;
}

sub mark_up_string_for_mouse_over {
   local($this, $s, *ht, $control, *pinyin_ht) = @_;

   $control = "" unless defined($control);
   $no_ascii_p = ($control =~ /NO-ASCII/);
   my $result = "";
   @chars = $utf8->split_into_utf8_characters($s, "return only chars");
   while (@chars) {
      $char = shift @chars;
      $numeric = $ht{UTF_TO_NUMERIC}->{$char};
      $numeric = "" unless defined($numeric);
      $pic_descr = $ht{UTF_TO_PICTURE_DESCR}->{$char};
      $pic_descr = "" unless defined($pic_descr);
      $next_char = ($#chars >= 0) ? $chars[0] : "";
      $next_char_is_combining_p = $this->char_is_combining_char($next_char, *ht);
      if ($no_ascii_p
       && ($char =~ /^[\x00-\x7F]*$/)
       && ! $next_char_is_combining_p) {
	 $result .= $util->guard_html($char);
      } elsif (($char =~ /^[\xE3-\xE9][\x80-\xBF]{2,2}$/) && $chinesePM->string_contains_utf8_cjk_unified_ideograph_p($char)) {
	 $unicode = $utf8->utf8_to_unicode($char);
	 $title = "CJK Unified Ideograph U+" . (uc sprintf("%04x", $unicode));
	 $title .= "&#xA;Chinese: $tonal_translit" if $tonal_translit = $chinesePM->tonal_pinyin($char, *pinyin_ht, "");
	 $title .= "&#xA;Number: $numeric" if $numeric =~ /\d/;
	 $result .= "<span title=\"$title\">" . $util->guard_html($char) . "<\/span>";
      } elsif ($char_name = $ht{UTF_TO_CHAR_NAME}->{$char}) {
	 $title = $char_name;
	 $title .= "&#xA;Number: $numeric" if $numeric =~ /\d/;
	 $title .= "&#xA;Picture: $pic_descr" if $pic_descr =~ /\S/;
	 $char_plus = $char;
	 while ($next_char_is_combining_p) {
	    # combining marks (Mc:non-spacing, Mc:spacing combining, Me: enclosing)
	    $next_char_name = $ht{UTF_TO_CHAR_NAME}->{$next_char};
	    $title .= "&#xA;+ $next_char_name";
	    $char = shift @chars;
	    $char_plus .= $char;
	    $next_char = ($#chars >= 0) ? $chars[0] : "";
	    $next_char_is_combining_p = $this->char_is_combining_char($next_char, *ht);
	 }
	 $result .= "<span title=\"$title\">" . $util->guard_html($char_plus) . "<\/span>";
	 $result .= "<wbr>" if $char_name =~ /^(FULLWIDTH COLON|FULLWIDTH COMMA|FULLWIDTH RIGHT PARENTHESIS|IDEOGRAPHIC COMMA|IDEOGRAPHIC FULL STOP|RIGHT CORNER BRACKET)$/;
      } elsif (($unicode = $utf8->utf8_to_unicode($char))
	    && ($unicode >= 0xAC00) && ($unicode <= 0xD7A3)) {
	 $title = "Hangul syllable U+" . (uc sprintf("%04x", $unicode));
	 $result .= "<span title=\"$title\">" . $util->guard_html($char) . "<\/span>";
      } else {
	 $result .= $util->guard_html($char);
      }
   }
   return $result;
}

sub romanize_char_at_position_incl_multi {
   local($this, $i, $lang_code, $output_style, *ht, *chart_ht) = @_;

   my $char = $chart_ht{ORIG_CHAR}->{$i};
   return "" unless defined($char);
   my @mappings = keys %{$ht{UTF_CHAR_MAPPING_LANG_SPEC}->{$lang_code}->{$char}}; 
   return $mappings[0] if @mappings;
   @mappings = keys %{$ht{UTF_CHAR_MAPPING}->{$char}};
   return $mappings[0] if @mappings;
   return $this->romanize_char_at_position($i, $lang_code, $output_style, *ht, *chart_ht);
}

sub romanize_char_at_position {
   local($this, $i, $lang_code, $output_style, *ht, *chart_ht) = @_;

   my $char = $chart_ht{ORIG_CHAR}->{$i};
   return "" unless defined($char);
   return $char if $char =~ /^[\x00-\x7F]$/; # ASCII
   my $romanization = $ht{UTF_TO_CHAR_ROMANIZATION}->{$char};
   return $romanization if $romanization;
   my $char_name = $chart_ht{CHAR_NAME}->{$i};
   $romanization = $this->romanize_charname($char_name, $lang_code, $output_style, *ht, $char);
   $ht{SUSPICIOUS_ROMANIZATION}->{$char_name}->{$romanization}
      = ($ht{SUSPICIOUS_ROMANIZATION}->{$char_name}->{$romanization} || 0) + 1
      unless (length($romanization) < 4) 
          || ($romanization =~ /\s/)
          || ($romanization =~ /^[bcdfghjklmnpqrstvwxyz]{2,3}[aeiou]-$/) # Khmer ngo-/nyo-/pho- OK
          || ($romanization =~ /^[bcdfghjklmnpqrstvwxyz]{2,2}[aeiougw][aeiou]{1,2}$/) # Canadian, Ethiopic syllable OK
	  || ($romanization =~ /^(allah|bbux|nyaa|nnya|quuv|rrep|shch|shur|syrx)$/i); # Arabic; Yi; Ethiopic syllable nyaa; Cyrillic letter shcha
   # print STDERR "romanize_char_at_position $i $char_name :: $romanization\n" if $char_name =~ /middle/i;
   return $romanization;
}

sub romanize_charname {
   local($this, $char_name, $lang_code, $output_style, *ht, $char) = @_;

   my $cached_result = $ht{ROMANIZE_CHARNAME}->{$char_name}->{$lang_code}->{$output_style};
   # print STDERR "(C) romanize_charname($char_name): $cached_result\n" if $cached_result && ($char_name =~ /middle/i);
   return $cached_result if defined($cashed_result);
   $orig_char_name = $char_name;
   $char_name =~ s/^.* LETTER\s+//;
   $char_name =~ s/^.* SYLLABLE\s+//;
   $char_name =~ s/^.* SYLLABICS\s+//;
   $char_name =~ s/^.* LIGATURE\s+//;
   $char_name =~ s/^.* VOWEL SIGN\s+//;
   $char_name =~ s/^.* CONSONANT SIGN\s+//;
   $char_name =~ s/^.* CONSONANT\s+//;
   $char_name =~ s/^.* VOWEL\s+//;
   $char_name =~ s/ WITH .*$//;
   $char_name =~ s/ WITHOUT .*$//;
   $char_name =~ s/\s+(ABOVE|AGUNG|BAR|BARREE|BELOW|CEDILLA|CEREK|DIGRAPH|DOACHASHMEE|FINAL FORM|GHUNNA|GOAL|INITIAL FORM|ISOLATED FORM|KAWI|LELET|LELET RASWADI|LONSUM|MAHAPRANA|MEDIAL FORM|MURDA|MURDA MAHAPRANA|REVERSED|ROTUNDA|SASAK|SUNG|TAM|TEDUNG|TYPE ONE|TYPE TWO|WOLOSO)\s*$//;
   foreach $_ ((1 .. 3)) {
      $char_name =~ s/^.*\b(?:ABKHASIAN|ACADEMY|AFRICAN|AIVILIK|AITON|AKHMIMIC|ALEUT|ALI GALI|ALPAPRAANA|ALTERNATE|ALTERNATIVE|AMBA|ARABIC|ARCHAIC|ASPIRATED|ATHAPASCAN|BASELINE|BLACKLETTER|BARRED|BASHKIR|BERBER|BHATTIPROLU|BIBLE-CREE|BIG|BINOCULAR|BLACKFOOT|BLENDED|BOTTOM|BROAD|BROKEN|CANDRA|CAPITAL|CARRIER|CHILLU|CLOSE|CLOSED|COPTIC|CROSSED|CRYPTOGRAMMIC|CURLY|CYRILLIC|DANTAJA|DENTAL|DIALECT-P|DIAERESIZED|DOTLESS|DOUBLE|DOUBLE-STRUCK|EASTERN PWO KAREN|EGYPTOLOGICAL|FARSI|FINAL|FLATTENED|GLOTTAL|GREAT|GREEK|HALF|HIGH|INITIAL|INSULAR|INVERTED|IOTIFIED|JONA|KANTAJA|KASHMIRI|KHAKASSIAN|KHAMTI|KHANDA|KIRGHIZ|KOMI|L-SHAPED|LATINATE|LITTLE|LONG|LOOPED|LOW|MAHAAPRAANA|MANCHU|MANDAILING|MATHEMATICAL|MEDIAL|MIDDLE-WELSH|MON|MONOCULAR|MOOSE-CREE|MULTIOCULAR|MUURDHAJA|N-CREE|NASKAPI|NDOLE|NEUTRAL|NIKOLSBURG|NORTHERN|NUBIAN|NUNAVIK|NUNAVUT|OJIBWAY|OLD|OPEN|ORKHON|OVERLONG|PERSIAN|PHARYNGEAL|PRISHTHAMATRA|R-CREE|REDUPLICATION|REVERSED|ROMANIAN|ROUND|ROUNDED|RUDIMENTA|RUMAI PALAUNG|SANYAKA|SARA|SAYISI|SCRIPT|SEBATBEIT|SEMISOFT|SGAW KAREN|SHAN|SHARP|SHWE PALAUNG|SHORT|SIBE|SIDEWAYS|SIMALUNGUN|SMALL|SOGDIAN|SOFT|SOUTH-SLAVEY|SOUTHERN|SPIDERY|STIRRUP|STRAIGHT|STRETCHED|SUBSCRIPT|SWASH|TAI LAING|TAILED|TAILLESS|TAALUJA|TH-CREE|TALL|TURNED|TODO|TOP|TROKUTASTI|TUAREG|UKRAINIAN|VISIGOTHIC|VOCALIC|VOICED|VOICELESS|VOLAPUK|WAVY|WESTERN PWO KAREN|WEST-CREE|WESTERN|WIDE|WOODS-CREE|Y-CREE|YENISEI|YIDDISH)\s+//;
   }
   $char_name =~ s/\s+(ABOVE|AGUNG|BAR|BARREE|BELOW|CEDILLA|CEREK|DIGRAPH|DOACHASHMEE|FINAL FORM|GHUNNA|GOAL|INITIAL FORM|ISOLATED FORM|KAWI|LELET|LELET RASWADI|LONSUM|MAHAPRANA|MEDIAL FORM|MURDA|MURDA MAHAPRANA|REVERSED|ROTUNDA|SASAK|SUNG|TAM|TEDUNG|TYPE ONE|TYPE TWO|WOLOSO)\s*$//;
   if ($char_name =~ /THAI CHARACTER/) {
      $char_name =~ s/^THAI CHARACTER\s+//;
      if ($char =~ /^\xE0\xB8[\x81-\xAE]/) {
	 # Thai consonants
	 $char_name =~ s/^([^AEIOU]*).*/$1/i;
      } elsif ($char_name =~ /^SARA [AEIOU]/) {
	 # Thai vowels
	 $char_name =~ s/^SARA\s+//;
      } else {
	 $char_name = $char;
      }
   }
   if ($orig_char_name =~ /(HIRAGANA LETTER|KATAKANA LETTER|SYLLABLE|LIGATURE)/) {
      $char_name = lc $char_name;
   } elsif ($char_name =~ /\b(ANUSVARA|ANUSVARAYA|NIKAHIT|SIGN BINDI|TIPPI)\b/) {
      $char_name = "+m";
   } elsif ($char_name =~ /\bSCHWA\b/) {
      $char_name = "e";
   } elsif ($char_name =~ /\s/) {
   } elsif ($orig_char_name =~ /KHMER LETTER/) {
      $char_name .= "-";
   } elsif ($orig_char_name =~ /CHEROKEE LETTER/) {
      # use whole letter as is
   } elsif ($orig_char_name =~ /KHMER INDEPENDENT VOWEL/) {
      $char_name =~ s/q//;
   } elsif ($orig_char_name =~ /LETTER/) {
      $char_name =~ s/^[AEIOU]+([^AEIOU]+)$/$1/i;
      $char_name =~ s/^([^-AEIOUY]+)[AEIOU].*/$1/i;
      $char_name =~ s/^(Y)[AEIOU].*/$1/i if $orig_char_name =~ /\b(?:BENGALI|DEVANAGARI|GURMUKHI|GUJARATI|KANNADA|MALAYALAM|MODI|MYANMAR|ORIYA|TAMIL|TELUGU|TIBETAN)\b.*\bLETTER YA\b/;
      $char_name =~ s/^(Y[AEIOU]+)[^AEIOU].*$/$1/i;
      $char_name =~ s/^([AEIOU]+)[^AEIOU]+[AEIOU].*/$1/i;
   }

   my $result = ($orig_char_name =~ /\bCAPITAL\b/) ? $char_name : (lc $char_name);
   # print STDERR "(R) romanize_charname($orig_char_name): $result\n" if $orig_char_name =~ /middle/i;
   $ht{ROMANIZE_CHARNAME}->{$char_name}->{$lang_code}->{$output_style} = $result;
   return $result;
}

sub assemble_numbers_in_chart {
   local($this, *chart_ht, $line_number) = @_;

   foreach $start (sort { $a <=> $b } keys %{$chart_ht{COMPLEX_NUMERIC_START_END}}) {
      my $end = $chart_ht{COMPLEX_NUMERIC_START_END}->{$start};
      my @numbers = ();
      foreach $i (($start .. ($end-1))) {
         my $orig_char = $chart_ht{ORIG_CHAR}->{$i};
         my $node_id = $this->get_node_for_span_with_slot($i, $i+1, "numeric-value", *chart_id);
	 if (defined($node_id)) {
	    my $number = $chart_ht{NODE_ROMAN}->{$node_id};
	    if (defined($number)) {
               push(@numbers, $number);
	    } elsif ($orig_char =~ /^[.,]$/) { # decimal point, comma separator
	       push(@numbers, $orig_char);
	    } else {
	       print STDERR "Found no romanization for node_id $node_id ($i-" . ($i+1) . ") in assemble_numbers_in_chart\n" if $verbosePM;
	    }
	 } else {
	    print STDERR "Found no node_id for span $i-" . ($i+1) . " in assemble_numbers_in_chart\n" if $verbosePM;
	 }
      }
      my $complex_number = $this->assemble_number(join("\xC2\xB7", @numbers), $line_number);
      # print STDERR "assemble_numbers_in_chart l.$line_number $start-$end $complex_number (@numbers)\n";
      $this->add_node($complex_number, $start, $end, *chart_ht, "", "complex-number");
   }
}

sub assemble_number {
   local($this, $s, $line_number) = @_;
   # e.g. 10 9 100 7 10 8 = 1978

   my $middot = "\xC2\xB7";
   my @tokens = split(/$middot/, $s); # middle dot U+00B7
   my $i = 0;
   my @orig_tokens = @tokens;

   # assemble single digit numbers, e.g. 1 7 5 -> 175
   while ($i < $#tokens) {
      if ($tokens[$i] =~ /^\d$/) {
         my $j = $i+1;
	 while (($j <= $#tokens) && ($tokens[$j] =~ /^[0-9.,]$/)) {
	    $j++;
	 }
	 $j--;
	 if ($j>$i) {
	    my $new_token = join("", @tokens[$i .. $j]);
	    $new_token =~ s/,//g;
	    splice(@tokens, $i, $j-$i+1, $new_token);
	 }
      }
      $i++;
   }

   foreach $power ((10, 100, 1000, 10000, 100000, 1000000, 100000000, 1000000000, 1000000000000)) {
      for (my $i=0; $i <= $#tokens; $i++) {
	 if ($tokens[$i] == $power) {
            if (($i > 0) && ($tokens[($i-1)] < $power)) {
	       splice(@tokens, $i-1, 2, ($tokens[($i-1)] * $tokens[$i]));
	       $i--;
               if (($i < $#tokens) && ($tokens[($i+1)] < $power)) {
	          splice(@tokens, $i, 2, ($tokens[$i] + $tokens[($i+1)]));
	          $i--;
	       }
	    }
	 } 
	 # 400 30 (e.g. Egyptian)
	 my $gen_pattern = $power;
         $gen_pattern =~ s/^1/\[1-9\]/;
         if (($tokens[$i] =~ /^$gen_pattern$/) && ($i < $#tokens) && ($tokens[($i+1)] < $power)) {
	    splice(@tokens, $i, 2, ($tokens[$i] + $tokens[($i+1)]));
	    $i--;
	 }
      }
      last if $#tokens == 0;
   }
   my $result = join($middot, @tokens);
   if ($verbosePM) {
      my $logfile = "/nfs/isd/ulf/cgi-mt/amr-tmp/uroman-number-log.txt";
      $util->append_to_file($logfile, "$s -> $result\n") if -r $logfile;
      # print STDERR "  assemble number l.$line_number @orig_tokens -> $result\n" if $line_number == 43;
   }
   return $result;
}

1;

