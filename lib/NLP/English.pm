################################################################
#                                                              #
# English                                                      #
#                                                              #
################################################################

package NLP::English;

use File::Basename;
use File::Spec;

# tok v1.3.7 (May 16, 2019)

$chinesePM = NLP::Chinese;
$ParseEntry = NLP::ParseEntry;
$util = NLP::utilities;
$utf8 = NLP::UTF8;
$logfile = "";
# $logfile2 = (-d "/nfs/isd/ulf/smt/agile") ? "/nfs/isd/ulf/smt/agile/minilog" : "";
# $util->init_log($logfile2);

$currency_symbol_list = "\$|\xC2\xA5|\xE2\x82\xAC|\xE2\x82\xA4";
$english_resources_skeleton_dir = "";
%dummy_ht = ();

sub build_language_hashtables {
   local($caller, $primary_entity_style_filename, $data_dir) = @_;

   unless ($data_dir) {
      $default_data_dir = "/nfs/nlg/users/textmap/brahms-ml/arabic/bin/modules/NLP";
      $data_dir = $default_data_dir if -d $default_data_dir;
   }
   my $english_word_filename = "$data_dir/EnglishWordlist.txt";
   my $default_entity_style_MT_filename = "$data_dir/EntityStyleMT-zh.txt";
   my $entity_style_all_filename = "$data_dir/EntityStyleAll.txt";
   my $EnglishNonNameCapWords_filename = "$data_dir/EnglishNonNameCapWords.txt";
   $english_resources_skeleton_dir = "$data_dir/EnglishResources/skeleton";
   %english_annotation_ht = ();
   %annotation_english_ht = ();
   %english_ht = ();
   $CardinalMaxWithoutComma = 99999;
   $CardinalMaxNonLex = 9999000;

   $primary_entity_style_filename = $default_entity_style_MT_filename unless defined($primary_entity_style_filename);
   if ($primary_entity_style_filename =~ /^(ar|zh)$/) {
      $languageCode = $primary_entity_style_filename;
      $primary_entity_style_filename 
	 = File::Spec->catfile($data_dir, "EntityStyleMT-$languageCode.txt");
   }

   open(IN,$english_word_filename) || die "Can't open $english_word_filename";
   while (<IN>) {
      next unless $_ =~ /^s*[^#\s]/;   # unless blank/comment line
      $_ =~ s/\s+$//;
      $line = $_;
      @lines = ($line);
      if (($line =~ /::gpe:/)
       && (($annotation) = ($line =~ /^.*?::(.*)$/))
       && (($pre_annotation, $singular_english, $post_annotation) = ($annotation =~ /^(.*)::plural-of:([^:]+)(|::.*)\s*$/))) {
	 $derived_annotation = $singular_english . "::$pre_annotation$post_annotation";
	 # print STDERR "derived_annotation: $derived_annotation\n";
	 push(@lines, $derived_annotation);
      }
      foreach $line (@lines) {
         ($english,@slots) = split("::",$line);
         next unless defined($english);
         $english =~ s/\s+$//;
         $lc_english = $english;
         $lc_english =~ tr/[A-Z]/[a-z]/;
         $annotation = "::" . join("::",@slots) . "::";
         $english_annotation_ht{$english} = $annotation;
         $english_annotation_ht{$lc_english} = $annotation;
         $english_annotation_ht{"_ALT_"}->{$english}->{$annotation} = 1;
         $english_annotation_ht{"_ALT_"}->{$lc_english}->{$annotation} = 1;
         $synt = "";
         foreach $slot_value (@slots) {
	    ($slot,$value) = ($slot_value =~ /\s*(\w[^:]+):\s*(\S.*)$/);
	    next unless defined($value);
	    $slot =~ s/\s+$//;
	    $value =~ s/\s+$//;
	    $synt = $value if $slot eq "synt";
            if (defined($annotation_english_ht{$slot_value})) {
	       push(@{$annotation_english_ht{$slot_value}},$english);
            } else {
               my @elist = ($english);
               $annotation_english_ht{$slot_value} = \@elist;
            }
	    if ($synt && defined($slot_value) && ($slot ne "synt")) {
	       $annot = "synt:$synt" . "::$slot_value";
               if (defined($annotation_english_ht{$annot})) {
	          push(@{$annotation_english_ht{$annot}},$english);
               } else {
                  my @elist = ($english);
                  $annotation_english_ht{$annot} = \@elist;
	       }
	       $english_annotation_ht{"_EN_SYNT_"}->{$english}->{$synt}->{$slot} = $value;
            }
         }
      }
   }
   close(IN);

   if (open(IN,$EnglishNonNameCapWords_filename)) {
      while (<IN>) {
         next unless $_ =~ /^s*[^#\s]/;   # unless blank/comment line
         $_ =~ s/\s+$//;
         $english_ht{(lc $_)}->{COMMON_NON_NAME_CAP} = 1;
      }
      close(IN);
   } else {
      print STDERR "Can't open $EnglishNonNameCapWords_filename\n";
   }

   foreach $style ("primary", "all") {
      if ($style eq "primary") {
	 $entity_style_filename = $primary_entity_style_filename || $default_entity_style_MT_filename;
      } elsif ($style eq "all") {
	 $entity_style_filename = $entity_style_all_filename;
      } else {
	 next;
      }
      %ht = ();
      open(IN,$entity_style_filename) || die("Can't open $entity_style_filename (stylefile)");
      my $n_entries = 0;
      while (<IN>) {
         next unless $_ =~ /^s*[^#\s]/;   # unless blank/comment line
         $_ =~ s/\s+$//;
         ($slot,$value_string) = ($_ =~ /^([^:]+):\s*(\S.*)$/);
         next unless defined($value_string);
         if (defined($ht{$slot})) {
	    print STDERR "Warning: ignoring duplicate entry for $slot in $entity_style_filename\n";
	    next;
         }
         @values = split("::", $value_string);
         foreach $value (@values) {
	    $value =~ s/^\s+//g;
	    $value =~ s/\s+$//g;
         }
         my @values_copy = @values;
         $ht{$slot} = \@values_copy;
	 $n_entries++;
      }
      # print STDERR "Processed $n_entries entries in $entity_style_filename\n";
      close(IN);
      if ($style eq "primary") {
         %english_entity_style_ht = %ht;
      } elsif ($style eq "all") {
         %english_entity_style_all_ht = %ht;
      }
   }

   if (defined($raw = $english_entity_style_ht{CardinalMaxWithoutComma})
	&& (@styles = @{$raw}) && ($n = $styles[0]) && ($n =~ /^\d+$/) && ($n >= 999)) {
      $CardinalMaxWithoutComma = $n;
   }
   if (defined($raw = $english_entity_style_ht{CardinalMaxNonLex})
	&& (@styles = @{$raw}) && ($n = $styles[0]) && ($n =~ /^\d+$/) && ($n >= 999999)) {
      $CardinalMaxNonLex = $n;
   }

   return (*english_annotation_ht,*annotation_english_ht,*english_entity_style_ht);
}

sub read_language_variations {
   local($this, $filename, *ht) = @_;

   my $n = 0;
   my $line_number = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
	 $line_number++;
	 $us = $util->slot_value_in_double_colon_del_list($_, "us");
	 $uk = $util->slot_value_in_double_colon_del_list($_, "uk");
	 $formal = $util->slot_value_in_double_colon_del_list($_, "formal");
	 $informal = $util->slot_value_in_double_colon_del_list($_, "informal");
	 if ($us && $uk) {
	    $ht{VARIATION_UK_US}->{$uk}->{$us} = 1;
	    $n++;
	 }
	 if ($informal && $formal) {
	    $ht{VARIATION_INFORMAL_FORMAL}->{$informal}->{$formal} = 1;
	    $n++;
	 }
      }
      close(IN);
      # print STDERR "Read $n spelling variation entries from $filename\n";
   }
}

sub entity_style_listing {
   local($caller,$attr) = @_;

   if (defined($l = $english_entity_style_ht{$attr})) {
      @sl = @{$l};
      if (($#sl == 0) && ($sl[0] eq "all")) {
         if (defined($al = $english_entity_style_all_ht{$attr})) {
            return @{$al};
	 } else {
            return ();
	 }
      } else {
         return @sl;
      }
   } else {
      return ();
   }
}

sub is_abbreviation {
   local($caller,$noun) = @_;

   $result = defined($annotation_s = $english_annotation_ht{$noun})
	         && ($annotation_s =~ /::abbreviation:true::/);
#  print "is_abbreviation($noun): $result\n";
   return $result;
}

sub noun_adv_sem {
   local($caller,$noun) = @_;

   return "" unless defined($annotation_s = $english_annotation_ht{$noun});
   ($adv_sem) = ($annotation_s =~ /::adv_sem:([-_a-z]+)::/);
   return "" unless defined($adv_sem);
   return $adv_sem;
}

sub numeral_value {
   local($caller,$numeral) = @_;

   return "" unless defined($annotation_s = $english_annotation_ht{$numeral});
   ($value) = ($annotation_s =~ /::value:(\d+)::/);
   return "" unless defined($value);
   return $value;
}

sub annot_slot_value {
   local($caller,$lex, $slot) = @_;

   return "" unless defined($annotation_s = $english_annotation_ht{$lex});
   ($value) = ($annotation_s =~ /::$slot:([-_a-z]+)(?:::.*|)\s*$/i);
   return "" unless defined($value);
   return $value;
}

sub annot_slot_values {
   local($caller,$lex, $slot) = @_;

   return () unless @annotations = keys %{$english_annotation_ht{"_ALT_"}->{$lex}};
   @annot_slot_values = ();
   foreach $annotation_s (@annotations) {
      ($value) = ($annotation_s =~ /::$slot:([^:]+)(?:::.*|)\s*$/i);
      if (defined($value)) {
	 $value =~ s/\s*$//;
         push(@annot_slot_values, $value);
      }
   }
   return @annot_slot_values;
}

# quick and dirty
sub noun_number_form {
   local($caller,$noun,$number) = @_;

   $noun = "rupee" if $noun =~ /^Rs\.?$/;
   $noun = "kilometer" if $noun =~ /^km$/;
   $noun = "kilogram" if $noun =~ /^kg$/;
   $noun = "meter" if $noun =~ /^m$/;
   $noun = "second" if $noun =~ /^(s|secs?\.?)$/;
   $noun = "minute" if $noun =~ /^(mins?\.?)$/;
   $noun = "hour" if $noun =~ /^(h|hrs?\.?)$/;
   $noun = "year" if $noun =~ /^(yrs?\.?)$/;
   $noun = "degree" if $noun =~ /^(deg\.?)$/;
   $noun = "foot" if $noun =~ /^(feet|ft\.?)$/;
   $noun = "square kilometer" if $noun =~ /^sq\.? km/;
   $noun =~ s/metre$/meter/;
   $noun =~ s/litre$/liter/;
   $noun =~ s/gramme$/gram/;
   $noun =~ s/tonne$/ton/;
   return $noun if $noun =~ /\$$/;
   return $noun unless $number =~ /^[0-9.]+$/;
   return $noun if $util->member($noun,"percent");  # no change in plural
   return $noun if $noun =~ /\b(yuan|renminbi|RMB|rand|won|yen|ringgit|birr)$/;  # no change in plural
   return $noun if $number <= 1;

   return $noun if $caller->is_abbreviation($noun);

   $noun =~ s/^(hundred|thousand|million|billion|trillion)\s+//;
   return $noun if $noun =~ /^(dollar|kilometer|pound|ton|year)s$/i;

   $original_noun = $noun;
   #check for irregular plural
   $annot = "synt:noun::plural-of:$noun";
   if (defined($annotation_english_ht{$annot})) {
      @elist = @{$annotation_english_ht{$annot}};
      return $elist[0] if @elist;
   }

   $noun = $noun . "s";
   return $noun if $noun =~ /(a|e|o|u)ys$/; # days, keys, toys, guys
   $noun =~ s/ys$/ies/;     # babies
   $noun =~ s/ss$/ses/;     # buses
   $noun =~ s/xs$/xes/;     # taxes
   $noun =~ s/shs$/shes/;   # dishes
   $noun =~ s/chs$/ches/;   # churches
   $noun =~ s/mans$/men/;   # women
   # print STDERR "NNF: $original_noun($number): $noun\n";
   return $noun;
}

# quick and dirty
sub lex_candidates {
   local($caller,$surf) = @_;

   @lex_cands = ($surf);
   $lex_cand = $surf;
   $lex_cand =~ s/ies$/y/;
   push(@lex_cands,$lex_cand) unless $util->member($lex_cand, @lex_cands);
   $lex_cand = $surf;
   $lex_cand =~ s/s$//;
   push(@lex_cands,$lex_cand) unless $util->member($lex_cand, @lex_cands);
   $lex_cand = $surf;
   $lex_cand =~ s/es$//;
   push(@lex_cands,$lex_cand) unless $util->member($lex_cand, @lex_cands);
   $lex_cand = $surf;
   $lex_cand =~ s/\.$//;
   push(@lex_cands,$lex_cand) unless $util->member($lex_cand, @lex_cands);
   $lex_cand = $surf;
   $lex_cand =~ s/men$/man/;
   push(@lex_cands,$lex_cand) unless $util->member($lex_cand, @lex_cands);

   return @lex_cands;
}

# quick and dirty
sub pos_tag {
   local($caller,$surf) = @_;

   return CD if ($surf =~ /^-?[0-9,\.]+$/);
   return NN if ($surf =~ /^($currency_symbol_list\d)/);
   @lex_candidates = $caller->lex_candidates($surf);
#  print "  lex_candidates: @lex_candidates\n";
   foreach $lex_cand (@lex_candidates) {
      if (defined($annotation_s = $english_annotation_ht{$lex_cand})) {
#        print "  annotation: $annotation_s\n";
         ($synt) = ($annotation_s =~ /::synt:([^:]+)::/);
         if (defined($synt)) {
	    if ($synt eq "art") {
	       return "DT";
	    } elsif ($synt eq "adj") {
               ($grade) = ($annotation_s =~ /::grade:([^:]+)::/);
	       if (defined($grade) && ($grade eq "superlative")) {
	          return "JJS";
	       } elsif (defined($grade) && ($grade eq "comparative")) {
	          return "JJR";
	       } else {
	          return "JJ";
	       }
	    } elsif ($synt eq "noun") {
	       if ($lex_cand eq $surf) {
	          return "NN";
	       } else {
	          return "NNS";
	       }
	    } elsif ($synt eq "name") {
	       return "NNP";
	    } elsif ($synt eq "cardinal") {
	       return "CD";
	    } elsif ($synt eq "ordinal") {
	       return "JJ";
	    } elsif ($synt eq "prep") {
	       return "IN";
	    } elsif ($synt eq "conj") {
	       return "CC";
	    } elsif ($synt eq "wh_pron") {
	       return "WP";
	    } elsif ($synt eq "adv") {
	       return "RB";
	    } elsif ($synt eq "genetive_particle") {
	       return "POS";
	    } elsif ($synt eq "ordinal_particle") {
	       return "NN";
	    } elsif ($synt eq "suffix_particle") {
	       return "NN";
	    } elsif ($synt =~ /^int(erjection)?$/) {
	       return "UH";
	    } elsif (($synt =~ /^punctuation$/)
		  && $util->is_rare_punctuation_string_p($surf)) {
	       return "SYM";
	    } elsif ($synt =~ /\bverb$/) {
	       if ($surf =~ /^(is)$/) {
	          return "VBZ";
	       } else {
	          return "VB";
	       }
	    }
	 }
      }
   }
   return "";
}

sub indef_art_filter {
   local($caller,$surf) = @_;

   # check article in lexical annotation 
   # e.g. hour::synt:noun::unit:temporal::indef-article:an
   #      uniform::synt:noun::indef-article:a
   ($surf_article,$word) = ($surf =~ /^(an?) (\S+)\s*/);
   if (defined($surf_article)
    && defined($word)
    && defined($annotation = $english_annotation_ht{$word})) {
      ($ann_article) = ($annotation =~ /::indef-article:([^:]+)::/);
      if (defined($ann_article)) {
	 return ($surf_article eq $ann_article) ? $surf : "";
      }
   }
   return "" if $surf =~ /\ban [bcdfghjklmnpqrstvwxyz]/;
   return "" if $surf =~ /\ban (US)\b/;
   return "" if $surf =~ /\ba [aeio]/;
   return "" if $surf =~ /\ba (under)/;
   return $surf;
}

sub wordlist_synt {
   local($caller,$word) = @_;

   return "" unless defined($annotation = $english_annotation_ht{$word});
   ($synt) = ($annotation =~ /::synt:([^:]+)::/);
   return $synt || "";
}

sub qualifier_filter {
   local($caller,$surf) = @_;

   return "" if $surf =~ /\b(over|more than|approximately) (million|billion|trillion)/;
   return "" if $surf =~ /\b(over) (once|twice)/;
   return $surf;
}

sub quantity_filter {
   local($caller,$surf) = @_;

   return "" if $surf =~ /^(a|an)-/;   # avoid "the a-week meeting"
   return $surf;
}

sub value_to_english {
   local($caller,$number) = @_;

   $result = "";

   $annot = "value:$number";
   if (defined($annotation_english_ht{$annot})) {
      @elist = @{$annotation_english_ht{$annot}};
      $result = $elist[0] if @elist;
   }
#  print "value_to_english($number)=$result\n";
   return $result;
}

sub value_to_english_ordinal {
   local($caller,$number) = @_;

   $result = "";

   $annot = "synt:ordinal::value:$number";
   if (defined($annotation_english_ht{$annot})) {
      @elist = @{$annotation_english_ht{$annot}};
      $result = $elist[0] if @elist;
   } else {
      $annot = "value:$number";
      if (defined($annotation_english_ht{$annot})) {
         @elist = @{$annotation_english_ht{$annot}};
         $cardinal = $elist[0] if @elist;
	 $result = $cardinal . "th";
	 $result =~ s/yth$/ieth/;
      }
   }
#  print "value_to_english($number)=$result\n";
   return $result;
}

sub english_with_synt_slot_value {
   local($caller, $english, $synt, $slot) = @_;

   return $english_annotation_ht{"_EN_SYNT_"}->{$english}->{$synt}->{$slot};
}

sub english_with_synt_slot_value_defined {
   local($caller, $synt, $slot) = @_;

   @englishes_with_synt_slot_value_defined = ();
   foreach $english (keys %{$english_annotation_ht{"_EN_SYNT_"}}) {
      push(@englishes_with_synt_slot_value_defined, $english) 
	 if defined($english_annotation_ht{"_EN_SYNT_"}->{$english}->{$synt}->{$slot})
	 && ! $util->member($english, @englishes_with_synt_slot_value_defined)
   }
   return @englishes_with_synt_slot_value_defined;
}

sub number_composed_surface_form {
   local($caller,$number,$leave_num_section_p) = @_;

   return "" unless $number =~ /^\d+$/;
   $leave_num_section_p = 0 unless defined($leave_num_section_p);
   $anchor = "1000000000000000000000000";
   while (($number < $anchor) && ($anchor >= 1000000)) {
      $anchor =~ s/000//;
   }
#  print "number_composed_surface_form number: $number anchor:$anchor\n";
   return "" unless $anchor >= 1000000;
   return "" unless $english = $caller->value_to_english($anchor);
   $ending = $anchor;
   $ending =~ s/^1000//;
   return "" unless ($number =~ /$ending$/) || (($number * 1000) % $anchor) == 0;
   $num_section = $number / $anchor;
   if (($num_section =~ /^[1-9]0?$/) && ! $leave_num_section_p) {
      $num_section_english = $caller->value_to_english($num_section);
      $num_section = $num_section_english if $num_section_english;
   }
   $num_section = $caller->commify($num_section); # only for extremely large numbers
   return "$num_section $english";
}

sub de_scientify {
   local($caller,$number) = @_;

#  print "de_scientify: $number\n";
   if ($number =~ /[eE][-+]/) {
      ($n,$exp) = ($number =~ /^(\d+)[eE]\+(\d+)$/);
      if (defined($exp)) {
	 $result = $n;
	 foreach $i (0 .. $exp-1) {
	    $result .= "0" 
	 }
	 return $result;
      } else {
         ($n,$f,$exp) = ($number =~ /^(\d+)\.(\d+)[eE]\+(\d+)$/);
	 if (defined($exp) && ($exp >= length($f))) {
	    $result = "$n$f";
	    foreach $i (0 .. $exp-1-length($f)) {
	       $result .= "0";
	    }
	    return $result;
	 } 
      }
   }
   return $number;
}

sub commify {
   local($caller,$number) = @_;

   my $text = reverse $number;
   $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   return scalar reverse $text;
}

my %plural_rough_number_ht = (
   10 => "tens",
   12 => "dozens",
   20 => "scores",
   100 => "hundreds",
   1000 => "thousands",
   10000 => "tens of thousands",
   100000 => "hundreds of thousands",
   1000000 => "millions",
   10000000 => "tens of millions",
   100000000 => "hundreds of millions",
   1000000000 => "billions",
   10000000000 => "tens of billions",
   100000000000 => "hundreds of billions",
   1000000000000 => "trillions",
   10000000000000 => "tens of trillions",
   100000000000000 => "hundreds of trillions",
);

sub plural_rough_plural_number {
   local($caller,$number) = @_;

   return $plural_rough_number_ht{$number} || "";
}

my %roman_numeral_ht = (
   "I" => 1,
   "II" => 2,
   "III" => 3,
   "IIII" => 4,
   "IV" => 4,
   "V" => 5,
   "VI" => 6,
   "VII" => 7,
   "VIII" => 8,
   "VIIII" => 9,
   "IX" => 9,
   "X" => 10,
   "XX" => 20,
   "XXX" => 30,
   "XXXX" => 40,
   "XL" => 40,
   "L" => 50,
   "LX" => 60,
   "LXX" => 70,
   "LXXX" => 80,
   "LXXXX" => 90,
   "XC" => 90,
   "C" => 100,
   "CC" => 200,
   "CCC" => 300,
   "CCCC" => 400,
   "CD" => 400,
   "D" => 500,
   "DC" => 600,
   "DCC" => 700,
   "DCCC" => 800,
   "DCCCC" => 900,
   "CM" => 900,
   "M" => 1000,
   "MM" => 2000,
   "MMM" => 3000,
   "MMM" => 3000,
);

sub roman_numeral_value {
   local($caller,$s) = @_;
   
   if (($m, $c, $x, $i) = ((uc $s) =~ /^(M{0,3})(C{1,4}|CD|DC{0,4}|CM|)(X{1,4}|XL|LX{0,4}|XC|)(I{1,4}|IV|VI{0,4}|IX|)$/)) {
      $sum = ($roman_numeral_ht{$m} || 0)
	   + ($roman_numeral_ht{$c} || 0)
	   + ($roman_numeral_ht{$x} || 0)
	   + ($roman_numeral_ht{$i} || 0);
      return $sum;
   } else {
      return 0;
   }
}

sub number_surface_forms {
   local($caller,$number,$pe) = @_;

   print STDERR "Warning from number_surface_forms: $number not a number\n" 
      if $logfile && !($number =~ /^(\d+(\.\d+)?|\.\d+)$/);
   # $util->log("number_surface_forms number:$number", $logfile);
   # $util->log("  surf:$surf", $logfile) if $surf = ($pe && $pe->surf);

   $pe = "" unless defined($pe);

   @num_style_list = @{$english_entity_style_ht{"FollowSourceLanguageNumberStyle"}};
   $follow_num_style = $util->member("yes", @num_style_list)
                        && (! (($number =~ /^([1-9]|10)$/) &&
                               $util->member("except-small-numbers", @num_style_list)));
   $num_style = ($pe) ? $pe->get("num_style") : "";
   if ($follow_num_style) {
      if ($num_style =~ /digits_plus_alpha/) {
	 if ($number =~ /^[1-9]\d?\d?000$/) {
            $digital_portion = $number;
            $digital_portion =~ s/000$//;
            return ("$digital_portion thousand");
	 } elsif ($number =~ /^[1-9]\d?\d?000000$/) {
            $digital_portion = $number;
            $digital_portion =~ s/000000$//;
            return ("$digital_portion million");
	 } elsif ($number =~ /^[1-9]\d?\d?000000000$/) {
            $digital_portion = $number;
            $digital_portion =~ s/000000000$//;
            return ("$digital_portion billion");
	 }
      } elsif ($num_style eq "digits") {
	 if ($number =~ /^\d{1,4}$/) {
	    return ($number);
	 }
      }
   }

   $number = $caller->de_scientify($number);

   $composed_form = $caller->number_composed_surface_form($number);
   $composed_form2 = $caller->number_composed_surface_form($number,1);
   $lex_form = $caller->value_to_english($number);
   $commified_form = $caller->commify($number);

   if ($lex_form) {
      if ($number >= 1000000) {
	 @result = ("one $lex_form", "1 $lex_form", "a $lex_form", $lex_form, $commified_form);
	 push(@result, $commified_form) if ($number <= $CardinalMaxNonLex);
      } elsif ($number >= 100) {
	 @result = ($commified_form, "one $lex_form", "a $lex_form", $lex_form);
      } elsif ($number >= 10) {
	 @result = ($number, $lex_form);
      } elsif ($number == 1) {
	 @result = ("a", "an", $lex_form);
      } elsif ($number == 0) {
	 @result = ($number, $lex_form);
      } else {
	 @result = ($lex_form);
      }
   } elsif ($composed_form) {
      if ($composed_form eq $composed_form2) {
         @result = ($composed_form);
      } elsif (($number >= 10000000) && ($composed_form2 =~ /^[1-9]0/)) {
         @result = ($composed_form2, $composed_form);
      } else {
         @result = ($composed_form, $composed_form2);
      }
      push(@result, $commified_form) if $number <= $CardinalMaxNonLex;
   } else {
      ($ten,$one) = ($number =~ /^([2-9])([1-9])$/);
      ($hundred) = ($number =~ /^([1-9])00$/) unless defined($one);
      ($thousand) = ($number =~ /^([1-9]\d?)000$/) unless defined($one) || defined($hundred);
      if (defined($one) && defined($ten)
           && ($part1 = $caller->value_to_english($ten  * 10))
	   && ($part2 = $caller->value_to_english($one))) {
	 $wordy_form = "$part1-$part2";
         @result = ($commified_form, $wordy_form);
      } elsif (defined($hundred)
           && ($part1 = $caller->value_to_english($hundred))) {
	 $wordy_form = "$part1 hundred";
         @result = ($commified_form, $wordy_form);
      } elsif (defined($thousand)
           && ($part1 = $caller->value_to_english($thousand))) {
	 $wordy_form = "$part1 thousand";
         @result = ($commified_form, $wordy_form);
      } elsif ($number =~ /^100000$/) {
         @result = ($commified_form, "one hundred thousand", "a hundred thousand", "hundred thousand");
      } elsif ($pe && ($pe->surf eq $number) && ($number =~ /^\d\d\d\d(\.\d+)?$/)) {
         @result = ($number);
         push(@result, $commified_form) unless $commified_form eq $number;
      } elsif ($number =~ /^\d{4,5}$/) {
	 if ($commified_form eq $number) {
            @result = ($number);
	 } else {
            @result = ($commified_form, $number);
	 }
      } else {
         @result = ($commified_form);
      }
   }
   push (@result, $number) 
       unless $util->member($number, @result) || ($number > $CardinalMaxWithoutComma);
#  $util->log("number_surface_forms result:@result", $logfile);

   # filter according to num_style
   if ($follow_num_style) {
      my @filtered_result = ();
      foreach $r (@result) {
	 push(@filtered_result, $r)
	    if    (($num_style eq "digits") && ($r =~ /^\d+$/))
	       || (($num_style eq "alpha")  && ($r =~ /^[-\@ a-z]*$/i))
	       || (($num_style eq "digits_plus_alpha") && ($r =~ /\d.*[a-z]/i));
      }
      @result = @filtered_result if @filtered_result;
   }

   if ($pe && $pe->childGloss("and")) {
      @new_result = ();
      foreach $r (@result) {
	 if ($r =~ /^and /) {
	    push(@new_result, $r);
	 } else {
	    push(@new_result, "and $r");
	 }
      }
      @result = @new_result;
   }
   return @result;
}

sub number_range_surface_forms {
   local($caller,$pe) = @_;

   $value = $pe->value;
   $value_coord = $pe->get("value-coord");
   unless ($value_coord) {
      return $caller->number_surface_forms($value);
   }
   $prefix = "";
   if ($conj = $pe->get("conj")) {
      $connector = $conj;
   } else {
      $connector = ($value_coord == $value + 1) ? "or" : "to";
   }
   if ($pe->get("between")) {
      $prefix = "between ";
      $connector = "and";
   }

   $pe1 = $pe->child("head");
   $pe2 = $pe->child("coord");
   @result1 = $caller->number_surface_forms($value, $pe1);
   @result2 = $caller->number_surface_forms($value_coord, $pe2);
   @num_style_list = @{$english_entity_style_ht{"FollowSourceLanguageNumberStyle"}};
   $follow_num_style = 1 if $util->member("yes", @num_style_list);

   # between two thousand and three thousand => between two and three thousand
   # 3 million to 5 million => 3 to 5 million
   if ($follow_num_style && ($#result1 == 0) && ($#result2 == 0)) {
      $range = $prefix . $result1[0] . " $connector " . $result2[0];
      $util->log("  range1: $range", $logfile);
      $gazillion = "thousand|million|billion|trillion";
      ($a,$gaz1,$b,$gaz2) = ($range =~ /^(.+) ($gazillion) ($connector .+) ($gazillion)$/);
      if (defined($a) && defined($gaz1) && defined($b) && defined($gaz2) && ($gaz1 eq $gaz2)) {
         $range = "$a $b $gaz1";
         $util->log("  range2: $range", $logfile);
         return ($range);
      }
   }

   @result = ();
   foreach $result1 (@result1) {
      next if ($value >= 1000) && ($result1 =~ /^\d+$/);
      foreach $result2 (@result2) {
	 next if $result1 =~ /^an?\b/;
	 push(@result, "$prefix$result1 $connector $result2")
	   if ($result1 =~ /^[a-z]+$/) && ($result2 =~ /^[a-z]+$/);
	 next if ($result1 =~ /^[a-z]/) || ($result2 =~ /^[a-z]/);
         next if ($value_coord >= 1000) && ($result2 =~ /^\d+$/);
	 ($digits1,$letters1) = ($result1 =~ /^(\d+(?:.\d+)?) ([a-z].*)$/);
	 ($digits2,$letters2) = ($result2 =~ /^(\d+(?:.\d+)?) ([a-z].*)$/);
	 if (defined($digits1) && defined($letters1)
	  && defined($digits2) && defined($letters2)
	  && ($letters1 eq $letters2)) {
	    push(@result, "$prefix$digits1 $connector $digits2 $letters1");
	 } elsif (($result1 =~ /^\d{1,3}$/) && ($result2 =~ /^\d{1,3}$/) && !$prefix) {
	    push(@result, "$result1-$result2");
	    if ($connector eq "to") {
	       my $span = "$result1 to $result2";
	       push(@result, $span) unless $util->member($span, @result);
	    }
	 } else {
	    push(@result, "$prefix$result1 $connector $result2");
	 }
      }
   }
   unless (@result) {
      $result1 = (@result1) ? $result1[0] : $value;
      $result2 = (@result2) ? $result2[0] : $value_coord;
      @result = "$prefix$result1 $connector $result2";
   }
   return @result;
}

sub q_number_surface_forms {
   local($caller,$pe) = @_;
 
   $surf = $pe->surf;
   return ($pe->gloss) unless $value = $pe->value;
   if (($value >= 1961) && ($value <= 2030)
            && 
	  (($pe->get("struct") eq "sequence of digits") 
	       ||
	   ($surf =~ /^\d+$/))) {
      $value = "$prefix $value" if $prefix = $pe->get("prefix");
      @result = ("$value");
   } else {
      @result = $caller->number_surface_forms($value,$pe);
      @result = $caller->qualify_entities($pe,@result);
   }
   return @result;
}

sub ordinal_surface_forms {
   local($caller,$number,$exclude_cardinals_p,$exclude_adverbials_p, $pe) = @_;

   if (defined($os = $english_entity_style_ht{"Ordinal"})) {
      @ordinal_styles = @{$os};
   } else {
      return ();
   }
   $exclude_cardinals_p = 0 unless defined($exclude_cardinals_p);
   @num_style_list = @{$english_entity_style_ht{"FollowSourceLanguageNumberStyle"}};
   $follow_num_style = 1 if $util->member("yes", @num_style_list);
   $num_style = ($pe) ? $pe->get("num_style") : "";
   $alpha_ok = ! ($follow_num_style && ($num_style =~ /^digits$/));
   my $c_number = $caller->commify($number);
   my $lex_form = "";
   $lex_form = $caller->value_to_english_ordinal($number) if $alpha_ok;
   my $adverbial_form 
	 = (($number =~ /^\d+$/) && ($number >= 1) && ($number <= 10) 
		 && $lex_form && $util->member("secondly", @ordinal_styles))
	     ? $lex_form . "ly" : "";
   my $num_form = $caller->numeric_ordinal_form($number);
   my $c_num_form = $caller->numeric_ordinal_form($c_number);
   my @result = ();

#  print "lex_form: $lex_form num_form:$num_form c_num_form:$c_num_form\n";
   if ($lex_form && $util->member("second", @ordinal_styles)) {
      if (! $util->member("2nd", @ordinal_styles)) {
	 @result = ($lex_form);
      } elsif ($c_num_form ne $num_form) {
	 @result = ($c_num_form, $lex_form, $num_form);
      } elsif ($number >= 10) {
	 @result = ($num_form, $lex_form);
      } else {
	 @result = ($lex_form, $num_form);
      }
   } elsif ($util->member("2nd", @ordinal_styles)) {
      if ($c_num_form ne $num_form) {
	 @result = ($c_num_form, $num_form);
      } else {
	 @result = ($num_form);
      }
   }
   unless ($number =~ /^\d+$/) {
      print STDERR "Warning: $number not an integer (for ordinal)\n";
   }
   unless ($exclude_cardinals_p) {
      $incl_num_card = $util->member("2", @ordinal_styles);
      $incl_lex_card = $util->member("two", @ordinal_styles);
      foreach $card ($caller->number_surface_forms($number)) {
	 if ($card =~ /^an?$/) {
	    # don't include
	 } elsif ($card =~ /^[0-9,]+$/) {
            push(@result, $card) if $incl_num_card;
	 } else {
            push(@result, $card) if $incl_lex_card && $alpha_ok;
	 }
      }
   }
   push(@result,$adverbial_form) if $adverbial_form && ! $exclude_adverbials_p;
   push(@result, $num_form) unless @result;
   return @result;
}

sub ordinal_surface_form {
   local($caller,$number,$exclude_cardinals_p,$exclude_adverbials_p, $pe) = @_;

   my @surf_forms = $caller->ordinal_surface_forms($number,$exclude_cardinals_p,$exclude_adverbials_p, $pe);
   return (@surf_forms) ? $surf_forms[0] : $caller->numeric_ordinal_form($number);
}

sub fraction_surface_forms {
   local($caller,$pe,$modp) = @_;

   my @result = ();
   $numerator = $pe->get("numerator");
   $denominator = $pe->get("denominator");
#  print "numerator: $numerator denominator:$denominator\n";
   @surf_nums = $caller->number_surface_forms($numerator,$pe);
   @surf_nums = ("one") if $numerator == 1;
   @surf_dens = $caller->ordinal_surface_forms($denominator,1,1);
   @surf_dens = ("half") if $denominator == 2;
   @surf_dens = ("quarter") if $denominator == 4;
   @surf_dens = ("tenth") if $denominator == 10;
#  print "surf_nums: @surf_nums surf_dens: @surf_dens\n";
   @fraction_patterns = @{$english_entity_style_ht{"Fraction"}};
   if (@surf_nums && @surf_dens) {
      $surf_num = $surf_nums[0];
      $surf_den = $surf_dens[0];
      $surf_num_den = "";
      foreach $sd (@surf_dens) {
         $surf_num_den = $sd if $sd =~ /^\d/;
      }
      $surf_den_w_proper_number = $caller->noun_number_form($surf_den, $numerator);
      foreach $fp (@fraction_patterns) {
	 if ($fp eq "one tenth") {
	    push(@result, $surf_num . " " . $surf_den_w_proper_number) unless $modp;
	 } elsif ($fp eq "one-tenth") {
	    if ($modp) {
	       push(@result, $surf_num . "-" . $surf_den);
	    } else {
	       push(@result, $surf_num . "-" . $surf_den_w_proper_number);
	    }
	 } elsif ($fp eq "1/10") {
	    push(@result, $numerator . "/" . $denominator);
	 } elsif ($fp eq "1/10th") {
	    push(@result, $numerator . "/" . $surf_num_den) if $surf_num_den;
	 }
      }
      return @result;
   } else {
      return ($pe->gloss);
   }
}

sub currency_surface_forms {
   local($caller,$pe) = @_;

   @currency_surf_forms = ();
   return @currency_surf_forms unless $pe->sem =~ /monetary quantity/;
   $unit = $pe->get("unit");
   return ($pe->gloss) unless $quant = $pe->get("quant");
   return ($pe->gloss) if $pe->childSem("head") eq "currency symbol";
   $quant_pe = $pe->child("quant");
   if ($unit =~ /^(US|Hongkong) dollar$/) {
      @units = $caller->entity_style_listing($unit);
   } elsif ($unit eq "yuan") {
      @units = $caller->entity_style_listing("Chinese yuan");
      @rmb_pos = @{$english_entity_style_ht{"Chinese RMB position"}};
      @rmb_pos = ("before-number", "after-number") if $util->member("all",@units);
   } else {
      @units = ($unit);
   }
   if (($pe->sem =~ /range$/) && $quant_pe) {
      @quants = $caller->number_range_surface_forms($quant_pe);
   } else {
      @quants = $caller->number_surface_forms($quant, $quant_pe);
   }
   @quants = ($quant) unless @quants;
   # print STDERR "units: @units \n";
   foreach $q (@quants) {
      foreach $u_sing (@units) {
      $u = ($modp) ? $u_sing : $caller->noun_number_form($u_sing, $quant);
#     print "  q: $q unit: $u value: $quant\n";
	 if ($u eq "RMB") {
	    if ($util->member("before-number", @rmb_pos)) {
	       if ($q =~ /^\d/) {
	          push(@currency_surf_forms, "RMB" . $q);
	       }
	    } 
	    if ($util->member("after-number", @rmb_pos)) {
	       push(@currency_surf_forms, $q . " RMB");
	    }
	 } elsif ($u =~ /\$$/) {
	    if ($q =~ /^\d/) {
	       $currency_surf_form = $u . $q;
	       push(@currency_surf_forms, $currency_surf_form);
	    }
	 } else {
	    $new_form = "$q $u";
	    push(@currency_surf_forms, $new_form) if $caller->indef_art_filter($new_form);
	 }
      }
   }
   @currency_surf_forms = $caller->qualify_entities($pe,@currency_surf_forms);

   # print STDERR "currency_surface_forms: @currency_surf_forms \n";
   return @currency_surf_forms;
}

sub age_surface_forms {
   local($caller,$pe, $modp) = @_;

   $gloss = $pe->gloss;
   @age_surf_forms = ();
   return @age_surf_forms unless $pe->sem =~ /age quantity/;
   $unit = $pe->get("unit");
   return ($gloss) unless $quant = $pe->get("quant");
   $temporal_quant_pe = $pe->child("head");
   $synt = $pe->synt;
   if ($synt =~ /parenthetical/) {
      if ($pe->get("slashed")) {
         @age_markers = $caller->entity_style_listing("ParentheticalAgeFormatSlashed");
         @age_markers = $caller->entity_style_listing("ParentheticalAgeFormat") unless @age_markers;
      } else {
         @age_markers = $caller->entity_style_listing("ParentheticalAgeFormat");
      }
      return ($gloss) unless @age_markers;
      foreach $a (@age_markers) {
         $age_surf_form = $a;
         $age_surf_form =~ s/8/$quant/;
         push(@age_surf_forms, $age_surf_form);
      }
   } elsif (($quant =~ /^\d+$/) && ($temporal_quant_pe->sem eq "age unit")) {
      @quants = $caller->number_surface_forms($quant);
      @quants = ($quant) if $pe->childSurf("quant") =~ /^\d+$/;
      foreach $quant2 (@quants) {
	 if ($modp) {
            push(@age_surf_forms, "$quant2-year-old");
	 } else {
	    $plural_marker = ($quant >= 2) ? "s" : "";
            push(@age_surf_forms, "$quant2 year$plural_marker old");
	 }
      }
   } elsif ($temporal_quant_pe && ($temporal_quant_pe->sem eq "temporal quantity")) {
      @temporal_quants = $caller->quantity_surface_forms($temporal_quant_pe, $modp);
      foreach $temporal_quant (@temporal_quants) {
         push(@age_surf_forms, $temporal_quant . (($modp) ? "-" : " ") . "old");
      }
   } else {
      return ($gloss);
   }

   @age_surf_forms = ($gloss) unless @age_surf_forms;
   return @age_surf_forms;
}

sub occurrence_surface_forms {
   local($caller,$pe,$modp) = @_;

   @quantity_surf_forms = ();
   return ($pe->gloss) unless $quant = $pe->get("quant");
   $quant_coord = $pe->get("quant-coord");
   $quant_pe = $pe->child("quant");
   $unit = "time";
   if (($pe->sem =~ /range$/) && $quant_pe) {
      @quants = $caller->number_range_surface_forms($quant_pe);
   } else {
      @quants = $caller->number_surface_forms($quant, $quant_pe);
   }
   @quants = ($quant) unless @quants;
   if ($modp) {
      return () if $pe->get("qualifier") || $quant_coord;
      return ("one-time") if $quant eq "1";
      return ("two-time", "two-fold", "2-fold") if $quant eq "2";
   } else {
      if ($quant_coord) {
         return $caller->qualify_entities($pe, ("once or twice"))
	    if $quant eq "1" and $quant_coord eq "2";
      } else {
         return $caller->qualify_entities($pe, ("once")) if $quant eq "1";
         return $caller->qualify_entities($pe, ("twice", "two times", "2 times", 
					        "2-fold", "two fold")) if $quant eq "2";
      }
   }
   foreach $q (@quants) {
      $u = ($modp) ? $unit : $caller->noun_number_form($unit, $quant);
      $new_form = "$q $u";
      if ($modp) {
	 # for the time being, no "more than/over/..." in modifiers: more than 20-ton
	 if ($pe->get("qualifier")) {
	    $new_form = "";
         } else {
	    $new_form =~ s/-/-to-/;
	    $new_form =~ s/ /-/g;
	 }
      }
      push(@quantity_surf_forms, $new_form) if $new_form;
      push(@quantity_surf_forms, "$q-fold") if $q =~ /\d/ || ($quant <= 9);
   }
   @quantity_surf_forms = $caller->qualify_entities($pe,@quantity_surf_forms);

   return @quantity_surf_forms;
}

sub quantity_surface_forms {
   local($caller,$pe,$modp) = @_;

   if ($pe->get("complex") eq "true") {
      return () if $modp;
      $quantity_surf_form = $pe->gloss;
      return ($quantity_surf_form);
   }

   @quantity_surf_forms = ();
   $sem = $pe->get("sem");
   $scale = $pe->get("scale");
   $scale_mod = $pe->get("scale_mod");
   $unit = $pe->get("unit") || $scale;
   $mod_gloss = $pe->get("mod");
   return ($pe->gloss) unless $quant = $pe->get("quant");
   $quant_coord = $pe->get("quant-coord");
   $quant_comb = $quant_coord || $quant;
   $quant_pe = $pe->child("quant");
   if (defined($u_style = $english_entity_style_ht{"\u$unit"})) {
      @units = @{$u_style};
   } else {
      @units = ($unit);
   }
   if (($pe->sem =~ /range$/) && $quant_pe) {
      @quants = $caller->number_range_surface_forms($quant_pe);
   } else {
      @quants = $caller->number_surface_forms($quant, $quant_pe);
   }
   @quants = ($quant) unless @quants;
   foreach $q (@quants) {
      foreach $u_sing (@units) {
	 my $u = $u_sing;
	 if (($sem =~ /seismic quantity/) && $scale) {
            $scale =~ s/(\w+)\s*/\u\L$1/g if $scale =~ /^(Richter|Mercalli)/i;
	    $u = "on the $scale_mod $scale scale";
	    $u =~ s/\s+/ /g;
	 } elsif (($u_sing =~ /\S/) && ! $modp) {
            $u = $caller->noun_number_form($u_sing, $quant_comb);
	 }
#     print "  q: $q unit: $u value: $quant modp: $modp\n";
	 @mods = ("");
	 @mods = ("consecutive", "in a row") if $mod_gloss eq "continuous";
	 foreach $mod (@mods) {
            $pre_quant_mod = "";
            $in_quant_mod = ($mod =~ /(consecutive)/) ? "$mod " : "";
            $post_quant_mod = ($mod =~ /(in a row)/) ? " $mod" : "";
	    $new_form = "$pre_quant_mod$q $in_quant_mod$u$post_quant_mod";
	    if ($caller->is_abbreviation($u)) {
	       if (($pe->sem =~ /range/) && ($q =~ /^[-0-9,\. to]+$/)
		     && $modp && !($new_form =~ / (to|or) /)) {
	          $new_form =~ s/-/-to-/;
	          $new_form =~ s/ /-/g;
	       } elsif ($q =~ /^[-0-9,\.]+$/) {
#                 $new_form =~ s/ //g;
	       } else {
	          $new_form = "";
	       }
	    } elsif ($modp) {
	       # for the time being, no "more than/over/..." in modifiers: more than 20-ton
	       if (($pe->get("qualifier")) || $mod) {
	          $new_form = "";
               } elsif ($u =~ /(square|cubic|metric|short)/) {
	          # no hyphenation for the time being (based on CTE style)
               } elsif (($pe->sem =~ /range/) && !($new_form =~ / (to|or) /)) {
	          $new_form =~ s/-/-to-/;
	          $new_form =~ s/ /-/g;
               } else {
	          $new_form =~ s/ /-/g;
	       }
	    }
            push(@quantity_surf_forms, $new_form)
	      if $new_form && $caller->quantity_filter($new_form) && $caller->indef_art_filter($new_form);
	 }
      }
   }
   @quantity_surf_forms = $caller->qualify_entities($pe,@quantity_surf_forms);

   # print STDERR "QSF unit:$unit sem:$sem   Result(s): " . join("; ", @quantity_surf_forms) . "\n";
   return @quantity_surf_forms;
}

sub qualify_entities {
   local($caller,$pe,@surf_forms) = @_;

   $prefix = $pe->get("prefix");
   $prefix_clause = ($prefix) ? "$prefix " : "";
   if ($qualifier = $pe->get("qualifier")) {
      $qualifier =~ s/-/ /g;
      $qualifier_key = $qualifier;
      $qualifier_key =~ s/(\w+)\s*/\u\L$1/g;
      # print "qualifier_key: $qualifier_key\n";
      @new_list = ();
      if (defined($value = $english_entity_style_ht{$qualifier_key})) {
	 @quals = @{$value};
	 # print STDERR "  qk $qualifier_key in ht: @quals :: @surf_forms\n";
         foreach $q (@quals) {
	    foreach $surf_form (@surf_forms) {
	       $new_form = "$prefix_clause$q $surf_form";
	       push(@new_list, $new_form) if $caller->qualifier_filter($new_form);
	    }
	 }
	 return @new_list if @new_list;
      } else {
	 @keys = sort keys %english_entity_style_ht;
	 # print STDERR "  did not find qk $qualifier_key in ht: @keys\n";
	 foreach $surf_form (@surf_forms) {
	    if (($qualifier =~ /^(couple|few|lot|many|number|several|some)$/i)
	     && (($art, $lex) = ($surf_form =~ /^(an?)\s+(\S|\S.*\S)\s*$/i))) {
		$plural_form = $caller->noun_number_form($lex,2);
	       $new_form = "$prefix_clause$qualifier $plural_form";
	    } else {
	       $new_form = "$prefix_clause$qualifier $surf_form";
	    }
	    push(@new_list, $new_form) if $caller->qualifier_filter($new_form);
	 }
	 return @new_list if @new_list;
      }
   }
   if ($prefix) {
      @prefixed_surf_forms = ();
      foreach $surf_form (@surf_forms) {
	 if ($surf_form =~ /^$prefix /) {  # already prefixed
	    push(@prefixed_surf_forms, $surf_form);
	 } else {
	    push(@prefixed_surf_forms, "$prefix $surf_form");
	 }
      }
      return @prefixed_surf_forms;
   } else {
      return @surf_forms;
   }
}

sub percent_surface_forms {
   local($caller,$pe,$modp) = @_;

   @percent_surf_forms = ();
   return @percent_surf_forms unless $pe->sem eq "percentage";
   $prefix = "";
   $quant = $pe->gloss;
   $quant =~ s/%$//;
   $quant =~ s/^and //;
   if ($pe->gloss =~ /^and /) {
      $prefix = "and";
   }
   @percent_markers = $caller->entity_style_listing("Percentage");
   @quants = $caller->number_surface_forms($quant);
   @quants = ($quant) unless @quants;
   foreach $p (@percent_markers) {
      foreach $q (@quants) {
	 if ($p =~ /%$/) {
	    if ($q =~ /\d$/) {
	       $percent_surf_form = $q . "%";
	       $percent_surf_form = "$prefix $percent_surf_form" if $prefix;
	       push(@percent_surf_forms, $percent_surf_form);
	       push(@percent_surf_forms, "by $percent_surf_form") unless $modp || $percent_surf_form =~ /^and /;
	    }
	 } else {
	    if ((($p =~ /^\d/) && ($q =~ /^\d/))
		     ||
	        (($p =~ /^[a-z]/) && ($q =~ /^[a-z]/))) {
	       if ($p =~ /percentage point/) {
		  if ($quant == 1) {
	             $percent_surf_form = $q . " percentage point";
		  } else {
	             $percent_surf_form = $q . " percentage points";
		  }
	       } else {
	          $percent_surf_form = $q . " percent";
	       }
	       $percent_surf_form = "$prefix $percent_surf_form" if $prefix;
	       $percent_surf_form =~ s/ /-/g if $modp;
	       push(@percent_surf_forms, $percent_surf_form);
	       push(@percent_surf_forms, "by $percent_surf_form") unless $modp || $percent_surf_form =~ /^and /;
	    }
	 }
      }
   }
   return @percent_surf_forms;
}

sub decade_century_surface_forms {
   local($caller,$pe) = @_;

   if ($pe->sem =~ /century/) {
      $gloss = $pe->gloss;
      return ("the $gloss", "in the $gloss", $gloss);
   }
   @decade_surf_forms = ();
   return @decade_surf_forms unless $pe->sem =~ /year range\b.*\bdecade/;
   @decade_markers = @{$english_entity_style_ht{"Decade"}};
   @extend_decades = @{$english_entity_style_ht{"ExtendDecades"}};
   @extended_decades = @{$english_entity_style_ht{"ExtendedDecade"}};
   $extended_decade = (@extended_decades) ? $extended_decades[0] : "none";

   $value = $pe->value;
   $extended_value = "";
   foreach $extend_decade (@extend_decades) {
      if ($extend_decade =~ /$value$/) {
	 $extended_value = $extend_decade unless $extended_value eq $extend_decade;
	 last;
      }
   }
   if ($sub = $pe->get("sub")) {
      $sub_clause = "$sub ";
      $sub_clause =~ s/(mid) /$1-/;
   } else {
      $sub_clause = "";
   }

   if (! $extended_value) {
      @values = ($value);
   } elsif ($extended_decade eq "ignore") {
      @values = ($value);
   } elsif ($extended_decade eq "only") {
      @values = ($extended_value);
   } elsif ($extended_decade eq "primary") {
      @values = ($extended_value, $value);
   } elsif ($extended_decade eq "secondary") {
      @values = ($value, $extended_value);
   } else {
      @values = ($value);
   }
   foreach $v (@values) {
      foreach $dm (@decade_markers) {
         $dm_ending = $dm;
         $dm_ending =~ s/^\d+//;
         push (@decade_surf_forms, "the $sub_clause$v$dm_ending");
         push (@decade_surf_forms, "in the $sub_clause$v$dm_ending");
         push (@decade_surf_forms, "$sub_clause$v$dm_ending");
      }
   }
   return @decade_surf_forms;
}

sub day_of_the_month_surface_forms {
   local($caller,$pe) = @_;

   @dom_surf_forms = ();
   return @dom_surf_forms 
      unless ($pe->sem eq "day of the month")
	  && ($day_number = $pe->get("day-number"));
   @dom_markers = @{$english_entity_style_ht{"DayOfTheMonth"}};
   foreach $dm (@dom_markers) {
      $ord = $caller->numeric_ordinal_form($day_number);
      if ($dm eq "on the 5th") {
	 push (@dom_surf_forms, "on the $ord");
      } elsif ($dm eq "the 5th") {
	 push (@dom_surf_forms, "the $ord");
      } elsif ($dm eq "5th") {
	 push (@dom_surf_forms, $ord);
      }
   }
   return @dom_surf_forms;
}

sub score_surface_forms {
   local($caller,$pe) = @_;

   @score_surf_forms = ();
   if (($score1 = $pe->get("score1"))
    && ($score2 = $pe->get("score2"))) {
      @score_markers = @{$english_entity_style_ht{"ScoreMarker"}};
      @score_markers = (":") unless @score_markers;
      foreach $sm (@score_markers) {
         push (@score_surf_forms, "$score1$sm$score2");
      }
   } 
   push(@score_surf_forms, $pe->gloss) unless @score_surf_forms;
   return @score_surf_forms;
}

sub day_of_the_week_surface_forms {
   local($caller,$pe) = @_;

   @dom_surf_forms = ();
   @dom_markers = @{$english_entity_style_ht{"DayOfTheWeek"}};
   $gloss = $pe->get("gloss");
   $weekday = $pe->get("weekday");
   $weekday = $gloss if ($weekday eq "") && ($gloss =~ /^\S+$/);
   $relday = $pe->get("relday");
   $period = $pe->get("period");
   foreach $dm (@dom_markers) {
      if (($dm =~ /NOPERIOD/) && $period) {
	 $surf = ""; # bad combination
      } elsif (($dm eq "Sunday") || ! $relday) {
	 $surf = $weekday;
	 $surf .= " $period" if $period;
      } elsif ($dm =~ /morning/) {
	 if ($period) {
	    $surf = $dm;
            $surf =~ s/tomorrow/$relday/;
	    $surf =~ s/morning/$period/;
            $surf =~ s/Sunday/$weekday/;
	 } else {
	    $surf = ""; # bad combination
	 }
      } else {
	 $surf = $dm;
	 if ($period) {
	    if ($relday eq "today") {
	       $core_surf = "this $period";
	    } else {
	       $core_surf = "$relday $period";
	    }
	 } else {
	    $core_surf = $relday;
	 }
         $surf =~ s/tomorrow/$core_surf/;
         $surf =~ s/Sunday/$weekday/;
      }
      $surf =~ s/yesterday night/last night/;
      $surf =~ s/this noon, ($weekday)(,\s*)?/today, $1, at noon/;
      $surf =~ s/this noon/today at noon/;
      $surf =~ s/this night/tonight/;
      $surf =~ s/\s*NOPERIOD\s*$//;
      push (@dom_surf_forms, $surf) unless $util->member($surf, @dom_surf_forms) || ! $surf;
      $on_weekday = "on $surf";
      push (@dom_surf_forms, $on_weekday)
	 if ($surf eq $weekday) && ! $util->member($on_weekday, @dom_surf_forms);
   }
   return @dom_surf_forms;
}

sub date_surface_forms {
   local($caller,$pe,$modp) = @_;

   @date_surf_forms = ();
   $sem = $pe->sem;
   $synt = $pe->synt;
   return @date_surf_forms unless $sem =~ /date(\+year)?/;
   $day = $pe->get("day");
   $weekday = $pe->get("weekday");
   $month_name = $pe->get("month-name");
   $month_number = $pe->get("month-number");
   $year = $pe->get("year");
   $era = $pe->get("era");
   $era_clause = "";
   $calendar_type = $pe->get("calendar");
   $calendar_type_clause = "";
   $calendar_type_clause = " AH" if $calendar_type eq "Islamic";
   $ad_year = $year;
   if ($era eq "Republic era") {
      $ad_year = $year + 1911;
      $era_clause = " (year $year of the $era)";
   }
   $rel = $pe->get("rel");
   if ($sep = $pe->get("sep")) {
      $date_surf_form = "$month_number$sep$day";
      $date_surf_form .= "$sep$year" if $year;
      $date_surf_form = "$weekday, $date_surf_form" if $weekday;
      $date_surf_form = "on $date_surf_form" if $synt eq "pp";
      return ($date_surf_form);
   }
   @date_months = @{$english_entity_style_ht{"DateMonth"}};
   @date_days = @{$english_entity_style_ht{"DateDay"}};
   @date_order = @{$english_entity_style_ht{"DateOrder"}};
   foreach $m (@date_months) {
      if ($m eq "September") {
	 $surf_month = $month_name;
      } elsif ($m =~ /^Sep(\.)?$/) {
	 if ($month_name eq "May") {
	    $surf_month = $month_name;
	 } else {
	    $period_clause = ($m =~ /\.$/) ? "." : "";
	    $surf_month = substr($month_name, 0, 3) . $period_clause;
	 }
      } elsif ($m =~ /^Sept(\.)?$/) {
	 if ($util->member($month_name, "February", "September"))  {
	    $period_clause = ($m =~ /\.$/) ? "." : "";
	    $surf_month = substr($month_name, 0, 4) . $period_clause;
	 } else {
	    $surf_month = "";
	 }
      } else {
	 $surf_month = "";
      }
      foreach $d (@date_days) {
	 if ($d =~ /^\d+$/) {
	    $surf_day = $day;
	 } elsif ($d =~ /^\d+[sthrd]+$/) {
	    $surf_day = $caller->numeric_ordinal_form($day);
	 } else {
	    $surf_day = "";
	 }
	 if ($surf_month && $surf_day) {
	    foreach $o (@date_order) {
               if ($calendar_type eq "Islamic") {
		  $date_surf_form = "$surf_day $surf_month";
               } elsif ($o eq "September 6, 1998") {
		  $date_surf_form = "$surf_month $surf_day";
	       } elsif ($o eq "6 September, 1998") {
		  $date_surf_form = "$surf_day $surf_month";
	       }
	       $date_surf_form = "$weekday, $date_surf_form" if $weekday;
	       $consider_on_p = 1;
	       if ($year) {
		  $date_surf_form .= "," unless $calendar_type eq "Islamic";
	          $date_surf_form .= " $ad_year$calendar_type_clause$era_clause";
	       } elsif ($rel) {
		  if ($rel eq "current") {
		     $date_surf_form = "this $date_surf_form";
		  } else {
		     $date_surf_form = "$rel $date_surf_form";
		  }
	          $consider_on_p = 0;
	       }
	       push(@date_surf_forms, $date_surf_form)
	          unless $util->member($date_surf_form, @date_surf_forms) || ($synt eq "pp");
	       if ($consider_on_p) {
	          $on_date_surf_form = "on $date_surf_form";
	          push(@date_surf_forms, $on_date_surf_form)
	             unless $modp || $util->member($on_date_surf_form, @date_surf_forms);
               }

	       if (($synt eq "pp") && ($sem eq "date")) {
	          push(@date_surf_forms, $date_surf_form)
	             unless $util->member($date_surf_form, @date_surf_forms);
	       }
	    }
	 }
      }
   }
   return @date_surf_forms;
   # rel, last, next, this
}

sub numeric_ordinal_form {
   local($caller,$cardinal) = @_;

   return $cardinal . "th" if $cardinal =~ /1\d$/;
   return $cardinal . "st" if $cardinal =~ /1$/;
   return $cardinal . "nd" if $cardinal =~ /2$/;
   return $cardinal . "rd" if $cardinal =~ /3$/;
   return $cardinal . "h" if $cardinal =~ /t$/;
   $cardinal =~ s/y$/ie/;
   return $cardinal . "th";
}

sub guard_urls_x045 {
   local($caller, $s) = @_;

   # URLs (http/https/ftp/mailto)
   my $result = "";
   while (($pre, $url, $post) = ($s =~ /^(.*?)((?:(?:https?|ftp):\/\/|mailto:)[#%-;=?-Z_-z~]*[-a-zA-Z0-9\/#])(.*)$/)) {
      $result .= "$pre\x04$url\x05";
      $s = $post;
   }
   $result .= $s;

   # emails
   $s = $result;
   $result = "";
   while (($pre, $email, $post) = ($s =~ /^(.*?[ ,;:()\/\[\]{}<>|"'])([a-z][-_.a-z0-9]*[a-z0-9]\@[a-z][-_.a-z0-9]*[a-z0-9]\.(?:[a-z]{2,}))([ .,;:?!()\/\[\]{}<>|"'].*)$/i)) {
      $result .= "$pre\x04$email\x05";
      $s = $post;
   }
   $result .= $s;

   # (Twitter style) #hashtag or @handle
   $s = $result;
   $result = "";
   while (($pre, $hashtag, $post) = ($s =~ /^(.*?[ .,;()\[\]{}'])([#@](?:[a-z]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|HHERE)(?:[_a-z0-9]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])*(?:[a-z0-9]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]))(.*)$/i)) {
      $result .= "$pre\x04$hashtag\x05";
      $s = $post;
   }
   $result .= $s;

   # Keep together number+letter in: Fig. 4g; Chromosome 12p
   $result =~ s/((?:\b(?:fig))(?:_DONTBREAK_)?\.?|\b(?:figures?|tables?|chromosomes?)|<xref\b[^<>]*\b(?:fig)\b[^<>]*>)\s*(\d+[a-z])\b/$1 \x04$2\x05/gi;

   # special combinations, e.g. =/= emoticons such as :)
   $s = $result;
   $result = "";
   while (($pre, $special, $post) = ($s =~ /^(.*?)(:-?\)|:-?\(|=\/=?|\?+\/\?+|=\[)(.*)$/)) {
      $result .= "$pre\x04$special\x05";
      $s = $post;
   }
   $result .= $s;

   return $result;
}

sub guard_xml_tags_x0123 {
   local($caller, $s) = @_;

   my $result = "";
   # xml tag might or might not already have "@" on left and/or right end: @<br>@
   while (($pre, $tag, $post) = ($s =~ /^(.*?)(\@?<\/?(?:[a-z][-_:a-z0-9]*)(?:\s+[a-z][-_:a-z0-9]*="[^"]*")*\s*\/?>\@?|&(?:amp|gt|lt|quot);|\[(?:QUOTE|URL)=[^ \t\n\[\]]+\]|\[\/?(?:QUOTE|IMG|INDENT|URL)\]|<\$[-_a-z0-9]+\$>|<\!--.*?-->)(.*)$/si)) {
      $result .= $pre;
      if (($pre =~ /\S$/) && ($tag =~ /^\S/)) {
         $result .= " \x01";
	 $result .= "\@" if ($tag =~ /^<[a-z]/i) && (! ($pre =~ /[,;(>]$/)); #)
      } else {
         $result .= "\x01";
      }
      $guarded_tag = $tag;
      $guarded_tag =~ s/ /\x02/g;
      # print STDERR "tag: $tag\nguarded_tag: $guarded_tag\n" if ($result =~ /Harvey/) || ($s =~ /Harvey/);
      $result .= $guarded_tag;
      if (($tag =~ /\S$/) && ($post =~ /^\S/)) { # (
	 $result .= "\@" if (($tag =~ /^<\//) || ($tag =~ /\/>$/)) && (! ($result =~ /\@$/)) && (! ($post =~ /^[,;)<]/));
         $result .= "\x03 ";
      } else {
	 $result .= "\x03";
      }
      $s = $post;
   }
   $result .= $s;
   return $result;
}

sub restore_urls_x045_guarded_string {
   local($caller, $s) = @_;

   my $orig = $s;
   while (($pre, $url, $post) = ($s =~ /^(.*?)\x04([^\x04\x05]*?)\x05(.*)$/)) {
      $url =~ s/ \@([-:\/])/$1/g;
      $url =~ s/([-:\/])\@ /$1/g;
      $url =~ s/ //g;
      $url =~ s/\x02/ /g;
      $s = "$pre$url$post";
   }
   if ($s =~ /[\x04\x05]/) {
      print STDERR "Removing unexpectedly unremoved x04/x05 marks from $s\n";
      $s =~ s/[\x04\x05]//g;
   }
   return $s;
}

sub restore_xml_tags_x0123_guarded_string {
   local($caller, $s) = @_;

   my $result = "";
   while (($pre, $tag, $post) = ($s =~ /^(.*?)\x01(.*?)\x03(.*)$/)) {
      $result .= $pre;
      $tag =~ s/ \@([-:\/])/$1/g;
      $tag =~ s/([-:\/])\@ /$1/g;
      $tag =~ s/ //g;
      $tag =~ s/\x02/ /g;
      $result .= $tag;
      $s = $post;
   }
   $result .= $s;
   return $result;
}

sub load_english_abbreviations {
   local($caller, $filename, *ht, $verbose) = @_;
   # e.g. /nfs/nlg/users/textmap/brahms-ml/arabic/data/EnglishAbbreviations.txt

   $verbose = 1 unless defined($verbose);
   my $n = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
         next if /^\#  /;
         s/\s*$//;
         my @expansions;
         if (@expansions = split(/\s*::\s*/, $_)) {
            my $abbrev = shift @expansions;
            $ht{IS_ABBREVIATION}->{$abbrev} = 1;
            $ht{IS_LC_ABBREVIATION}->{(lc $abbrev)} = 1;
            foreach $expansion (@expansions) {
               $ht{ABBREV_EXPANSION}->{$abbrev}->{$expansion} = 1;
               $ht{ABBREV_EXPANSION_OF}->{$expansion}->{$abbrev} = 1;
            }
	    $n++;
         }
      }
      close(IN);
      print STDERR "Loaded $n entries from $filename\n" if $verbose;
   } else {
      print STDERR "Can't open $filename\n";
   }
}

sub load_split_patterns {
   local($caller, $filename, *ht) = @_;
   # e.g. /nfs/nlg/users/textmap/brahms-ml/arabic/data/BioSplitPatterns.txt

   my $n = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
         next if /^\#  /;
         s/\s*$//;
	 if (($s) = ($_ =~ /^SPLIT-DASH-X\s+(\S.*\S|\S)\s*$/)) {
	    $ht{SPLIT_DASH_X}->{$s} = 1;
	    $ht{LC_SPLIT_DASH_X}->{(lc $s)} = 1;
	    $n++;
	 } elsif (($s) = ($_ =~ /^SPLIT-X-DASH\s+(\S.*\S|\S)\s*$/)) {
	    $ht{SPLIT_X_DASH}->{$s} = 1;
	    $ht{LC_SPLIT_X_DASH}->{(lc $s)} = 1;
	    $n++;
	 } elsif (($s) = ($_ =~ /^DO-NOT-SPLIT-DASH-X\s+(\S.*\S|\S)\s*$/)) {
	    $ht{DO_NOT_SPLIT_DASH_X}->{$s} = 1;
	    $ht{LC_DO_NOT_SPLIT_DASH_X}->{(lc $s)} = 1;
	    $n++;
	 } elsif (($s) = ($_ =~ /^DO-NOT-SPLIT-X-DASH\s+(\S.*\S|\S)\s*$/)) {
	    $ht{DO_NOT_SPLIT_X_DASH}->{$s} = 1;
	    $ht{LC_DO_NOT_SPLIT_X_DASH}->{(lc $s)} = 1;
	    $n++;
	 } elsif (($s) = ($_ =~ /^DO-NOT-SPLIT\s+(\S.*\S|\S)\s*$/)) {
	    $ht{DO_NOT_SPLIT}->{$s} = 1;
	    $ht{LC_DO_NOT_SPLIT}->{(lc $s)} = 1;
	    $n++;
	 } elsif (($s) = ($_ =~ /^SPLIT\s+(\S.*\S|\S)\s*$/)) {
	    $ht{SPLIT}->{$s} = 1;
	    $ht{LC_SPLIT}->{(lc $s)} = 1;
	    $n++;
         }
      }
      close(IN);
      print STDERR "Loaded $n entries from $filename\n";
   } else {
      print STDERR "Can't open $filename\n";
   }
}

sub guard_abbreviations_with_dontbreak {
   local($caller, $s, *ht) = @_;

   my $orig = $s;
   my $result = "";
   while (($pre,$potential_abbrev,$period,$post) = ($s =~ /^(.*?)((?:[a-z]+\.-?)*(?:[a-z]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])+)(\.)(.*)$/i)) {
      if (($pre =~ /([-&\/0-9]|[-\/]\@ )$/)
       && (! ($pre =~ /\b[DR](?: \@)?-(?:\@ )?$/))) { # D-Ariz.
	 $result .= "$pre$potential_abbrev$period";
      } else {
         $result .= $pre . $potential_abbrev;
         $potential_abbrev_with_period = $potential_abbrev . $period;
         if ($ht{IS_ABBREVIATION}->{$potential_abbrev_with_period}) {
            $result .= "_DONTBREAK_";
         } elsif ($ht{IS_LC_ABBREVIATION}->{(lc $potential_abbrev_with_period)}) {
            $result .= "_DONTBREAK_";
         }
         $result .= $period;
      }
      $s = $post;
   }
   $result .= $s;
   $result =~ s/\b([Nn])o\.(\s*\d)/$1o_DONTBREAK_.$2/g;
   return $result;
}

$alpha = "(?:[a-z]|\xCE[\xB1-\xBF]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])";
$alphanum = "(?:[a-z0-9]|\xCE[\xB1-\xBF]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])(?:[-_a-z0-9]|\xCE[\xB1-\xBF]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])*(?:[a-z0-9]|\xCE[\xB1-\xBF]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])|(?:[a-z0-9]|\xCE[\xB1-\xBF]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])";

sub normalize_punctuation {
   local($caller, $s) = @_;

   $s =~ s/\xE2\x80[\x93\x94]/-/g; # ndash, mdash to hyphen
   $s =~ s/ \@([-\/])/$1/g;
   $s =~ s/([-\/])\@ /$1/g;
   return $s;
}

sub update_replace_characters_based_on_context {
   local($caller, $s) = @_;

   # This is just a start. Collect stats over text with non-ASCII, e.g. K?ln.
   # HHERE
   my $rest = $s;
   $s = "";
   while (($pre, $left, $repl_char, $right, $post) = ($rest =~ /^(.*?\s+)(\S*)(\xEF\xBF\xBD)(\S*)(\s.*)$/)) {
      $s .= "$pre$left";
      if (($left =~ /[a-z]$/i) && ($right =~ /^s(?:[-.,:;?!].*)?$/i)) { # China's etc.
	 $repl_char = "\xE2\x80\x99"; # right single quotation mark
      } elsif (($left =~ /n$/i) && ($right =~ /^t$/i)) { # don't etc.
	 $repl_char = "\xE2\x80\x99"; # right single quotation mark
      } elsif (($left =~ /[a-z]\s*[.]$/i) && ($right eq "")) { # end of sentence
	 $repl_char = "\xE2\x80\x9D"; # right double quotation mark
      } elsif (($left eq "") && ($right =~ /^[A-Z]/i)) { # start of word
	 $repl_char = "\xE2\x80\x9C"; # left double quotation mark
      }
      $s .= "$repl_char$right";
      $rest = $post;
   }
   $s .= $rest;

   return $s;
}

sub tokenize {
   local($caller, $s, *ht, $control) = @_;

   my $local_verbose = 0;
   print "Point A: $s\n" if $local_verbose;
   $control = "" unless defined($control);
   my $bio_p = ($control =~ /\bbio\b/);

   $s = $utf8->repair_misconverted_windows_to_utf8_strings($s);
   print "Point A2: $s\n" if $local_verbose;
   $s = $utf8->delete_weird_stuff($s);
   print "Point B: $s\n" if $local_verbose;

   # reposition xml-tag with odd space
   $s =~ s/( +)((?:<\/[a-z][-_a-z0-9]*>)+)(\S)/$2$1$3/ig;
   $s =~ s/(\S)((?:<[a-z][^<>]*>)+)( +)/$1$3$2/ig;
   print "Point C: $s\n" if $local_verbose;

   $a_value = $ht{IS_ABBREVIATION}->{"Fig."} || "n/a";
   $s = $caller->guard_abbreviations_with_dontbreak($s, *ht);
   my $standard_abbrev_s = "Adm|al|Apr|Aug|Calif|Co|Dec|Dr|etc|e.g|Feb|Febr|Gen|Gov|i.e|Jan|Ltd|Lt|Mr|Mrs|Nov|Oct|Pfc|Pres|Prof|Sen|Sept|U.S.A|U.S|vs";
   my $pre;
   my $core;
   my $post;
   $s = " $core " if ($pre,$core,$post) = ($s =~ /^(\s*)(.*?)(\s*)$/i);
   $s =~ s/\xE2\x80\x89/ /g; # thin space
   $standard_abbrev_s =~ s/\./\\\./g;
   $s =~ s/[\x01-\x05]//g;
   $s = $caller->guard_urls_x045($s);
   $s = $caller->guard_xml_tags_x0123($s);
   $s = $caller->update_replace_characters_based_on_context($s);
   $s =~ s/((?:[a-zA-Z_]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])\.)([,;]) /$1 $2 /g;
   $s =~ s/((?:[a-zA-Z_]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])\.)(\x04)/$1 $2/g;
   if ($bio_p) {
      $s =~ s/(\S)((?:wt\/|onc\/)?(?:[-+]|\?+|\xE2\x80[\x93\x94])\/(?:[-+]|\?+|\xE2\x80[\x93\x94]))/$1 $2/g;
      $s =~ s/((?:[-+]|\xE2\x80[\x93\x94])\/(?:[-+]|\xE2\x80[\x93\x94]))(\S)/$1 $2/g;
   }
   print "Point D: $s\n" if $local_verbose;
   $s =~ s/(~+)/ $1 /g;
   $s =~ s/((?:\xE2\x80\xB9|\xE2\x80\xBA|\xC2\xAB|\xC2\xBB|\xE2\x80\x9E)+)/ $1 /g; # triangular bracket(s) "<" or ">" etc.
   $s =~ s/(``)([A-Za-z])/$1 $2/g; # added Nov. 30, 2017
   $s =~ s/((?:<|&lt;)?=+(?:>|&gt;)?)/ $1 /g;    # include arrows
   $s =~ s/(\\")/ $1 /g;
   $s =~ s/([^\\])("+)/$1 $2 /g;
   $s =~ s/([^\\])((?:\xE2\x80\x9C)+)/$1 $2 /g;  # open "
   $s =~ s/([^\\])((?:\xE2\x80\x9D)+)/$1 $2 /g;  # close "
   $s =~ s/((?:<|&lt;)?-{2,}(?:>|&gt;)?)/ $1 /g; # include arrows
   $s =~ s/((?:\xE2\x80\xA6)+)/ $1 /g; # ellipsis
   print "Point E: $s\n" if $local_verbose;
   foreach $_ ((1..2)) {
      # colon
      $s =~ s/([.,;])(:+)/$1 \@$2/g;
      $s =~ s/(:+)([.,;])/$1 \@\@ $2/g;
      # # question mark/exclamation mark blocks
      # $s =~ s/([^!?])([!?]+)([^!?])/$1 $2 $3/g;
   }
   print "Point F: $s\n" if $local_verbose;
   $s =~ s/(\?)/ $1 /g;
   $s =~ s/(\!)/ $1 /g;
   $s =~ s/ +/ /g;
   $s =~ s/(\$+|\xC2\xA3|\xE2\x82[\xA0-\xBE])/ $1 /g; # currency signs (Euro sign; British pound sign; Yen sign etc.)
   $s =~ s/(\xC2\xA9|\xE2\x84\xA2)/ $1 /g;           # copyright/trademark signs
   $s =~ s/(\xC2\xB2)([-.,;:!?()])/$1 $2/g; # superscript 2
   $s =~ s/([^ ])(&#160;)/$1 $2/g;
   $s =~ s/(&#160;)([^ ])/$1 $2/g;
   $s =~ s/(&#\d+|&#x[0-9A-F]+);/$1_DONTBREAK_;/gi;
   $s =~ s/([\@\.]\S*\d)([a-z][A-z])/$1_DONTBREAK_$2/g; # email address, URL
   $s =~ s/ ($standard_abbrev_s)\./ $1_DONTBREAK_\./gi;
   $s =~ s/ ($standard_abbrev_s) \. (\S)/ $1_DONTBREAK_\. $2/gi;
   $s =~ s/\b((?:[A-Za-z]\.){1,3}[A-Za-z])\.\s+/$1_DONTBREAK_\. /g; # e.g. a.m. O.B.E.
   $s =~ s/([ ])([A-Z])\. ([A-Z])/$1$2_DONTBREAK_\. $3/; # e.g. George W. Bush
   $s =~ s/(\S\.*?[ ])([A-Z])_DONTBREAK_\. (After|All|And|But|Each|Every|He|How|In|It|My|She|So|That|The|Then|There|These|They|This|Those|We|What|When|Which|Who|Why|You)([', ])/$1$2\. $3$4/; # Exceptions to previous line, e.g. "plan B. This"
   $s =~ s/\b(degrees C|[Ff]ig\.? \d+ ?[A-Z]|(?:plan|Scud) [A-Z])_DONTBREAK_\./$1\./g; # Exception, e.g. "plan B";
   $s =~ s/([^-_a-z0-9])(art|fig|no|p)((?:_DONTBREAK_)?\.)(\d)/$1$2$3 $4/gi; # Fig.2 No.14
   $s =~ s/([^-_A-Za-z0-9])(\d+(?:\.\d+)?)(?:_DONTBREAK_)?(thousand|million|billion|trillion|min|mol|sec|kg|km|g|m|p)\b/$1$2 $3/g; # 3.4kg 1.7million 49.9p
   $s =~ s/([^-_a-z0-9])((?:[1-9]|1[0-2])(?:[.:][0-5]\d)?)(?:_DONTBREAK_)?([ap]m\b|[ap]\.m(?:_DONTBREAK_)?\.)/$1$2 $3/gi; # 3.15pm 12:00p.m. 8am
   print "Point H: $s\n" if $local_verbose;

   $s =~ s/(\d)([a-z][A-z])/$1 $2/g;
   $s =~ s/(\w|`|'|%|[a-zA-Z]\.|[a-zA-Z]_DONTBREAK_\.)(-|\xE2\x80\x93)(\w|`|')/$1 \@$2\@ $3/g;
   $s =~ s/(\w|`|'|%|[a-zA-Z]\.|[a-zA-Z]_DONTBREAK_\.)(-|\xE2\x80\x93)(\w|`|')/$1 \@$2\@ $3/g;
   $s =~ s/(\w)- /$1 \@- /g;
   $s =~ s/ -(\w)/ -\@ $1/g;
   $s =~ s/(\d):(\d)/$1 \@:\@ $2/g;
   $s =~ s/(\d)\/(\d)/$1 \@\/\@ $2/g;
   $s =~ s/($alphanum)\/([,;:!?])/$1 \@\/\@  $2/g;
   $s =~ s/($alphanum)([-+]+)\/($alphanum)/$1$2 \@\/\@ $3/gi;
   print "Point I: $s\n" if $local_verbose;
   foreach $_ ((1..5)) {
      $s =~ s/([ \/()])($alphanum) ?\/ ?($alphanum)([-+ \/().,;])/$1$2 \@\/\@ $3$4/gi;
   }
   $s =~ s/([a-zA-Z%\/\[\]]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]|\x05|[a-zA-Z]_DONTBREAK_\.)([,;:!?])\s*(\S)/$1 $2 $3/g;
   # asterisk
   $s =~ s/( [(\[]?)(\*)([a-z0-9])/$1$2\@ $3/gi;
   $s =~ s/([a-z0-9])(\*)([.,;:)\]]* )/$1 \@$2$3/gi;
   print "Point J: $s\n" if $local_verbose;

   # Arabic script
   if ($s =~ /[\xD8-\xDB]/) {
      for (my $i=0; $i <= 1; $i++) {
         $s =~ s/([\xD8-\xDB][\x80-\xBF])([,;:!?.\(\)\[\]\/]|\xD8\x8C|\xD8\x9B|\xD8\x9F|\xD9\xAA|\xC2\xAB|\xC2\xBB|\xE2[\x80-\x9F][\x80-\xBF])/$1 $2/gi; # punctuation includes Arabic ,;?%
         $s =~ s/([,;:!?.\(\)\[\]\/]|\xD8\x8C|\xD8\x9B|\xD8\x9F|\xD9\xAA|\xC2\xAB|\xC2\xBB|\xE2[\x80-\x9F][\x80-\xBF])([\xD8-\xDB][\x80-\xBF])/$1 $2/gi;
      }
   }
   $s =~ s/(\d|[a-zA-Z]|[\xD8-\xDB][\x80-\xBF])([-])([\xD8-\xDB][\x80-\xBF])/$1 \@$2\@ $3/g;
   $s =~ s/(\d|[a-zA-Z])([\xD8-\xDB][\x80-\xBF])/$1 \@\@ $2/g;
   print "Point K: $s\n" if $local_verbose;

   # misc. non-ASCII punctuation
   $s =~ s/(\xC2[\xA1\xBF]|\xD5\x9D|\xD6\x89|\xD8[\x8C\x9B]|\xD8\x9F|\xD9[\xAA\xAC]|\xDB\x94|\xDC[\x80\x82])/ $1 /g;
   $s =~ s/(\xE0\xA5[\xA4\xA5]|\xE0\xBC[\x84-\x86\x8D-\x8F\x91\xBC\xBD])/ $1 /g;
   $s =~ s/(\xE1\x81[\x8A\x8B]|\xE1\x8D[\xA2-\xA6])/ $1 /g;
   $s =~ s/(\xE1\x81[\x8A\x8B]|\xE1\x8D[\xA2-\xA6]|\xE1\x9F[\x94\x96])/ $1 /g;
   $s =~ s/([^0-9])(5\xE2\x80\xB2)(-)([ACGTU])/$1 $2 \@$3\@ $4/g; # 5-prime-DNA-seq.
   $s =~ s/([^0-9])([35]\xE2\x80\xB2)/$1 $2 /g; # prime (keep 3-prime/5-prime together for bio domain)
   $s =~ s/([^0-9])(\xE2\x80\xB2)/$1 $2 /g; # prime
   $s =~ s/(\xE2\x81\x99)/ $1 /g; # five dot punctuation
   $s =~ s/(\xE3\x80[\x81\x82\x8A-\x91]|\xE3\x83\xBB|xEF\xB8\xB0|\xEF\xBC\x8C)/ $1 /g;
   $s =~ s/(\xEF\xBC[\x81-\x8F\x9A\x9F])/ $1 /g; # CJK fullwidth punctuation (e.g. fullwidth exclamation mark)
   print "Point L: $s\n" if $local_verbose;
   # spaces
   $s =~ s/((?:\xE3\x80\x80)+)/ $1 /g; # idiographic space
   $s =~ s/((?:\xE1\x8D\xA1)+)/ $1 /g; # Ethiopic space

   # isolate \xF0 and up from much more normal characters
   $s =~ s/([\xF0-\xFE][\x80-\xBF]*)([\x00-\x7F\xC0-\xDF][\x80-\xBF]*)/$1 $2/g;
   $s =~ s/([\x00-\x7F\xC0-\xDF][\x80-\xBF]*)([\xF0-\xFE][\x80-\xBF]*)/$1 $2/g;
   print "Point M: $s\n" if $local_verbose;

   $s =~ s/( \d+)([,;:!?] )/$1 $2/g;
   $s =~ s/ ([,;()\[\]])([a-zA-Z0-9.,;])/ $1 $2/g;
   $s =~ s/(\)+)([-\/])([a-zA-Z0-9])/$1 $2 $3/g;
   $s =~ s/([0-9\*\[\]()]|\xE2\x80\xB2)([.,;:] )/$1 $2/g;
   $s =~ s/([a-zA-Z%]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]|\x05)([,;:.!?])([")]|''|\xE2\x80[\x99\x9D]|)(\s)/$1 $2 $3$4/g;
   $s =~ s/([a-zA-Z%]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]|\x05)([,;:.!?])([")]|''|\xE2\x80[\x99\x9D]|)\s*$/$1 $2 $3/g;
   $s =~ s/([.,;:]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]|\x05)('|\xE2\x80[\x99\x9D])/$1 $2/g;
   $s =~ s/('|\xE2\x80[\x99\x9D])([.,;:]|\x04)/$1 $2/g;
   $s =~ s/([(){}\[\]]|\xC2\xB1)/ $1 /g;
   $s =~ s/([a-zA-Z0-9]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]|\x05)\.\s*$/$1 ./g;
   $s =~ s/([a-zA-Z]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]|\x05)\.\s+/$1 . /g;
   $s =~ s/([a-zA-Z]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF]|\x05)\.(\x04)/$1 . $2/g;
   $s =~ s/([0-9]),\s+(\S)/$1 , $2/g;
   $s =~ s/([a-zA-Z])(\$)/$1 $2/g;
   $s =~ s/(\$|[~<=>]|\xC2\xB1|\xE2\x89[\xA4\xA5]|\xE2\xA9[\xBD\xBE])(\d)/$1 $2/g;
   $s =~ s/(RMB)(\d)/$1 $2/g;
   print "Point N: $s\n" if $local_verbose;
   foreach $_ ((1..2)) {
      $s =~ s/([ '"]|\xE2\x80\x9C)(are|could|did|do|does|had|has|have|is|should|was|were|would)(n't|n\xE2\x80\x99t)([ '"]|\xE2\x80\x9D)/$1 $2 $3 $4/gi;
      $s =~ s/ (can)(not) / $1 $2 /gi;
      $s =~ s/ (ca)\s*(n)('t|\xE2\x80\x99t) / $1$2 $2$3 /gi;
      $s =~ s/ ([Ww])o\s*n('|\xE2\x80\x99)t / $1ill n$2t /g;
      $s =~ s/ WO\s*N('|\xE2\x80\x99)T / WILL N$1T /g;
      $s =~ s/ ([Ss])ha\s*n('|\xE2\x80\x99)t / $1hall n$2t /g;
      $s =~ s/ SHAN('|\xE2\x80\x99)T / SHALL N$1T /g;
    # $s =~ s/ ain('|\xE2\x80\x99)t / is n$1t /g;
    # $s =~ s/ Ain('|\xE2\x80\x99)t / Is n$1t /g;
    # $s =~ s/ AIN('|\xE2\x80\x99)T / IS N$1T /g;
   }
   print "Point O: $s\n" if $local_verbose;
   $s =~ s/(\d)%/$1 %/g;
   $s =~ s/ '(d|ll|m|re|s|ve|em) / '_DONTBREAK_$1 /g; # 'd = would; 'll = will; 'em = them
   $s =~ s/ \xE2\x80\x99t(d|ll|m|re|s|ve) / \xE2\x80\x99t_DONTBREAK_$1 /g;
   $s =~ s/([^0-9a-z'.])('|\xE2\x80\x98)([0-9a-z])/$1$2 $3/gi;
   $s =~ s/([0-9a-z])(\.(?:'|\xE2\x80\x99))([^0-9a-z']|\xE2\x80\x99)/$1 $2$3/gi;
   $s =~ s/([0-9a-z]_?\.?)((?:'|\xE2\x80\x99)(?:d|ll|m|re|s|ve|))([^0-9a-z'])/$1 $2$3/gi;
   $s =~ s/([("]|\xE2\x80\x9C|'')(\w)/$1 $2/g;
   print "Point P: $s\n" if $local_verbose;
   $s =~ s/(\w|[.,;:?!])([")]|''|\xE2\x80\x9D)/$1 $2/g;
   $s =~ s/ ([,;()\[\]])([a-zA-Z0-9.,;])/ $1 $2/g;
   $s =~ s/([a-z0-9]) ?(\()([-+_ a-z0-9\/]+)(\))/$1 $2 $3 $4 /ig;
   $s =~ s/([a-z0-9]) ?(\[)([-+_ a-z0-9\/]+)(\])/$1 $2 $3 $4 /ig;
   $s =~ s/([a-z0-9]) ?(\{)([-+_ a-z0-9\/]+)(\})/$1 $2 $3 $4 /ig;
   $s =~ s/([%])-(\d+(?:\.\d+)? ?%)/$1 \@-\@ $2/g;
   $s =~ s/( )(art|No)_DONTBREAK_(\.{2,})/$1 $2$3/gi;
   $s =~ s/(_DONTBREAK_\.)(\.{1,})/$1 $2/g;
   print "Point Q: $s\n" if $local_verbose;
   foreach $_ ((1 .. 2)) {
      $s =~ s/(\s(?:[-a-z0-9()']|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])*)(\.{2,})((?:[-a-z0-9()?!:\/']|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])*\s|(?:[-a-z0-9()'\/]|\xC3[\x80-\x96\x98-\xB6\xB8-\xBF]|[\xC4-\xC9\xCE-\xD3][\x80-\xBF]|\xE0[\xA4-\xA5][\x80-\xBF]|\xE0[\xB6-\xB7][\x80-\xBF])+\.\s)/$1 $2 $3/gi;
   }
   $s =~ s/0s\b/0 s/g;
   $s =~ s/([0-9])(\x04)/$1 $2/g;
   $s =~ s/ +/ /g;
   print "Point R: $s\n" if $local_verbose;

   if ($bio_p) {
      foreach $_ ((1 .. 2)) {
         $s =~ s/([a-z]) \@(-|\xE2\x80[\x93\x94])\@ (\d+(?:$alpha)?\d*\+?)([- \/])/$1$2$3$4/ig;
         $s =~ s/([a-z]) \@(-|\xE2\x80[\x93\x94])\@ ((?:alpha|beta|kappa)\d+)([- \/])/$1$2$3$4/ig;
         $s =~ s/([a-z]) \@(-|\xE2\x80[\x93\x94])\@ ((?:a|b|h|k)\d)([- \/])/$1$2$3$4/ig;
         $s =~ s/([a-z0-9]) \@(-|\xE2\x80[\x93\x94])\@ ([a-z])([- \/])/$1$2$3$4/ig;
         $s =~ s/([- \/])(\d*[a-z]) \@(-|\xE2\x80[\x93\x94])\@ ([a-z0-9])/$1$2$3$4/ig;
      }
      # mutation indicators such -/- etc.
      $s =~ s/(\?\/) +(\?)/$1$2/g;
      $s =~ s/([^ ?])((?:wt\/|onc\/)?(?:[-+]|\?+|\xE2\x80[\x93\x94])\/(?:[-+]|\?+|\xE2\x80[\x93\x94]))/$1 $2/g;
      $s =~ s/((?:[-+]|\xE2\x80[\x93\x94])\/(?:[-+]|\xE2\x80[\x93\x94]))(\S)/$1 $2/g;

      # Erk1/2
      $rest = $s;
      $s = "";
      while (($pre, $stem, $slashed_number_s, $post) = ($rest =~ /^(.*?[^-_a-z0-9])([a-z][-_a-z]*)(\d+(?:(?: \@)?\/(?:\@ )?(?:\d+))+)([^-+a-z0-9].*|)$/i)) {
	 if ((($pre =~ /\x04[^\x05]*$/) && ($post =~ /^[^\x04]*\x05/))
	  || ($stem =~ /^(mid|pre|post|sub|to)$/i)) {
	    $s .= "$pre$stem$slashed_number_s";
	 } else {
	    $s .= $pre;
	    my @slashed_numbers = split(/(?: \@)?\/(?:\@ )?/, $slashed_number_s);
	    foreach $i ((0 .. $#slashed_numbers)) {
	       my $number = $slashed_numbers[$i];
	       $s .= "$stem$number";
	       $s .= " @\/@ " unless $i == $#slashed_numbers;
	    }
	 }
	 $rest = $post;
      }
      $s .= $rest;

      # Erk-1/-2
      while (($pre, $stem, $dash1, $number1, $dash2, $number2, $post) = ($s =~ /^(.*[^-_a-z0-9])([a-z][-_a-z]*)(?: \@)?(-|\xE2\x80[\x93\x94])(?:\@ )?(\d+)(?: \@)?\/(?:\@ )?(?:\@ )?(-|\xE2\x80[\x93\x94])(?:\@ )?(\d+)([^-+a-z0-9].*|)$/i)) {
	 $s = "$pre$stem$dash1$number1 \@\/\@ $stem$dash2$number2$post";
      }
      $rest = $s;
      $s = "";
      # IFN-a/b  (Slac2-a/b/c)
      while (($pre, $stem, $dash, $slashed_letter_s, $post) = ($rest =~ /^(.*[^-_a-z0-9])([a-z][-_a-z0-9]*)(-|\xE2\x80[\x93\x94])([a-z](?:(?: \@)?\/(?:\@ )?(?:[a-z]))+)([^-+a-z0-9].*|)$/i)) {
	 if (($pre =~ /\x04[^\x05]*$/) && ($post =~ /^[^\x04]*\x05/)) {
	    $s .= "$pre$stem$dash1$number1$dash2$number2";
	 } else {
	    $s .= $pre;
	    my @slashed_letters = split(/(?: \@)?\/(?:\@ )?/, $slashed_letter_s);
	    foreach $i ((0 .. $#slashed_letters)) {
	       my $letter = $slashed_letters[$i];
	       $s .= "$stem$dash$letter";
	       $s .= " @\/@ " unless $i == $#slashed_letters;
	    }
	 }
	 $rest = $post;
      }
      $s .= $rest;

      # SPLIT X-induced
      my $rest = $s;
      my $new_s = "";
      while (($pre, $dash, $right, $post) = ($rest =~ /^(.*?)(-|\xE2\x80[\x93\x94])([a-z]+)( .*|)$/i)) {
	 $new_s .= $pre;
	 if (($right eq "I") && ($pre =~ / [a-zA-Z][a-z]*$/)) {
	    # compatriots-I have a dream
	    $new_s .= " \@" . $dash . "\@ ";
	 } elsif ($ht{LC_SPLIT_DASH_X}->{($caller->normalize_punctuation(lc $right))}) {
	    $new_s .= " \@" . $dash . "\@ ";
	 } else {
	    $new_s .= $dash;
	 }
	 $new_s .= $right;
	 $rest = $post;
      }
      $new_s .= $rest;
      $s = $new_s;

      # SPLIT ubiquinated-X
      $rest = $s;
      $new_s = "";
      while (($pre, $left, $dash, $post) = ($rest =~ /^(.*? |)([a-z0-9]+|'s)(-|\xE2\x80[\x93\x94])([a-z0-9].*)$/i)) {
	 $new_s .= "$pre$left";
	 if ($ht{LC_SPLIT_X_DASH}->{($caller->normalize_punctuation(lc $left))}) {
	    $new_s .= " \@" . $dash . "\@ ";
	 } else {
	    $new_s .= $dash;
	 }
	 $rest = $post;
      }
      $new_s .= $rest;
      $s = $new_s;

      # SPLIT low-frequency
      $rest = $s;
      $new_s = "";
      if (($pre, $left, $dash, $right, $post) = ($rest =~ /^(.*?[- ]|)([a-z]+)([-\/]|\xE2\x80[\x93\x94])([a-z]+)([- ].*|)$/i)) {
      }
      while (($pre, $left, $dash, $right, $post) = ($rest =~ /^(.*?[-\/ ]|)([a-z]+)((?: \@)?(?:[-\/]|\xE2\x80[\x93\x94])(?:\@ )?)([a-z]+)([-\/ ].*|)$/i)) {
	 $x = $caller->normalize_punctuation(lc ($left . $dash . $right));
	 if ($ht{LC_SPLIT}->{($caller->normalize_punctuation(lc ($left . $dash . $right)))}) {
	    $pre =~ s/([-\/])$/ \@$1\@ /;
	    $post =~ s/^([-\/])/ \@$1\@ /;
	    $dash = $caller->normalize_punctuation($dash);
	    $new_s .= "$pre$left";
	    $new_s .= " \@" . $dash . "\@ ";
	    $new_s .= $right;
	    $rest = $post;
	 } elsif ($pre =~ /[-\/]$/) {
	    $new_s .= $pre;
	    $rest = "$left$dash$right$post";
	 } else {
	    $new_s .= "$pre$left";
	    $rest = "$dash$right$post";
	 }
      }
      $new_s .= $rest;
      $s = $new_s;

      # DO-NOT-SPLIT X-ras
      $rest = $s;
      $new_s = "";
      while (($pre, $dash, $right, $post) = ($rest =~ /^(.*?) \@(-|\xE2\x80[\x93\x94])\@ ([a-z0-9]+)( .*|)$/i)) {
	 $new_s .= $pre;
	 if ($ht{LC_DO_NOT_SPLIT_DASH_X}->{($caller->normalize_punctuation(lc $right))}) {
	    $new_s .= $dash;
	 } else {
	    $new_s .= " \@" . $dash . "\@ ";
	 }
	 $new_s .= $right;
	 $rest = $post;
      }
      $new_s .= $rest;
      $s = $new_s;

      # DO-NOT-SPLIT Caco-X
      $rest = $s;
      $new_s = "";
      while (($pre, $left, $dash, $post) = ($rest =~ /^(.*? |)([a-z0-9]+) \@([-\/]|\xE2\x80[\x93\x94]])\@ ([a-z0-9].*)$/i)) {
	 $new_s .= "$pre$left";
	 if ($ht{LC_DO_NOT_SPLIT_X_DASH}->{($caller->normalize_punctuation(lc $left))}) {
	    $new_s .= $dash;
	 } else {
	    $new_s .= " \@" . $dash . "\@ ";
	 }
	 $rest = $post;
      }
      $new_s .= $rest;
      $s = $new_s;

      # DO-NOT-SPLIT down-modulate (2 elements)
      $rest = $s;
      $new_s = "";
      while (($pre, $left, $dash, $right, $post) = ($rest =~ /^(.*? |)([a-z0-9]+) \@([-\/]|\xE2\x80[\x93\x94]])\@ ([a-z0-9]+)( .*|)$/i)) {
	 $new_s .= "$pre$left";
	 if ($ht{LC_DO_NOT_SPLIT}->{($caller->normalize_punctuation(lc ($left . $dash . $right)))}) {
	    $new_s .= $dash;
	 } else {
	    $new_s .= " \@" . $dash . "\@ ";
	 }
	 $new_s .= $right;
	 $rest = $post;
      }
      $new_s .= $rest;
      $s = $new_s;

      # DO-NOT-SPLIT 14-3-3 (3 elements)
      $rest = $s;
      $new_s = "";
      while (($pre, $left, $dash_group1, $dash1, $middle, $dash_group2, $dash2, $right, $post) = ($rest =~ /^(.*? |)([a-z0-9]+)((?: \@)?([-\/]|\xE2\x80[\x93\x94]])(?:\@ )?)([a-z0-9]+)((?: \@)?([-\/]|\xE2\x80[\x93\x94]])(?:\@ )?)([a-z0-9]+)( .*|)$/i)) {
	 $new_s .= "$pre$left";
	 if ($ht{LC_DO_NOT_SPLIT}->{($caller->normalize_punctuation(lc ($left . $dash1 . $middle . $dash2 . $right)))}) {
	    $new_s .= $dash1;
	 } else {
	    $new_s .= $dash_group1;
	 }
	 $new_s .= $middle;
	 if ($ht{LC_DO_NOT_SPLIT}->{($caller->normalize_punctuation(lc ($left . $dash1 . $middle . $dash2 . $right)))}) {
	    $new_s .= $dash2;
	 } else {
	    $new_s .= $dash_group2;
	 }
	 $new_s .= $right;
	 $rest = $post;
      }
      $new_s .= $rest;
      $s = $new_s;

      $s =~ s/ +/ /g;
   }
   print "Point S: $s\n" if $local_verbose;
   
   $s =~ s/_DONTBREAK_//g;
   $s =~ s/( )(ark|ill|mass|miss|wash|GA|LA|MO|OP|PA|VA|VT)(\.)( )/$1$2 $3$4/g;
   print "Point T: $s\n" if $local_verbose;
   $s = $caller->restore_urls_x045_guarded_string($s);
   $s = $caller->restore_xml_tags_x0123_guarded_string($s);
   print "Point U: $s\n" if $local_verbose;
   $s =~ s/(https?|ftp)\s*(:)\s*(\/\/)/$1$2$3/gi;
   $s =~ s/\b(mailto)\s*(:)\s*([a-z])/$1$2$3/gi;
   $s =~ s/(\d)\s*(:)\s*([0-5]\d[^0-9])/$1$2$3/gi;
   print "Point V: $s\n" if $local_verbose;
   $s =~ s/(5\xE2\x80\xB2-[ACGT]+)\s*(-|\xE2\x80[\x93\x94])\s*(3\xE2\x80\xB2)/$1$2$3/g; # repair broken DNA sequence
   $s =~ s/ (etc) \. / $1. /g; # repair most egrareous separations
   print "Point W: $s\n" if $local_verbose;
   $s = $caller->repair_separated_periods($s);
   print "Point X: $s\n" if $local_verbose;
   $s =~ s/^\s+//;
   $s =~ s/\s+$//;
   $s = "$pre$s$post" if defined($pre) && defined($post);
   $s =~ s/ +/ /g;
   print "Point Y: $s\n" if $local_verbose;

   return $s;
}

sub tokenize_plus_for_noisy_text {
   local($caller, $s, *ht, $control) = @_;

   $control = "" unless defined($control);
   my $pre;
   my $code;
   my $post;
   $s = " $core " if ($pre,$core,$post) = ($s =~ /^(\s*)(.*?)(\s*)$/i);
   foreach $i ((1 .. 2)) {
      $s =~ s/ ([A-Z][a-z]+'?[a-z]+)(-) / $1 $2 /gi; # Example: Beijing-
      $s =~ s/ (\d+(?:\.\d+)?)(-|:-|:|_|\.|'|;)([A-Z][a-z]+'?[a-z]+|[A-Z]{3,}) / $1 $2 $3 /gi; # Example: 3:-Maxkamado
      $s =~ s/ (\d+(?:\.\d+)?)(')([A-Za-z]{3,}) / $1 $2 $3 /gi; # Example: 42'daqiiqo
      $s =~ s/ (-|:-|:|_|\.)([A-Z][a-z]+'?[a-z]+|[A-Z]{3,}) / $1 $2 /gi; # Example: -Xassan
      $s =~ s/ ((?:[A-Z]\.[A-Z]|[A-Z]|Amb|Col|Dr|Eng|Gen|Inj|Lt|Maj|Md|Miss|Mr|Mrs|Ms|Pres|Prof|Sen)\.)([A-Z][a-z]+|[A-Z]{2,}) / $1 $2 /gi; # Example: Dr.Smith
      $s =~ s/ (\d+)(,)([a-z]{3,}) / $1 $2 $3 /gi; # Example: 24,October
      $s =~ s/ (%)(\d+(?:\.\d+)?) / $1 $2 /gi; # Example: %0.6
      $s =~ s/ ([A-Za-z][a-z]{3,}\d*)([.,\/]|:\()([A-Za-z][a-z]{3,}|[A-Z]{3,}) / $1 $2 $3 /gi; # Example: Windows8,falanqeeyaal
      $s =~ s/ ([A-Za-z]{3,}\d*?|[A-Za-z]+'[A-Za-z]+)([,\/]|:\()([A-Za-z]{3,}|[A-Za-z]+'[A-Za-z]+) / $1 $2 $3 /gi; # Example: GAROOWE:(SHL
      $s =~ s/ (\d[0-9.,]*\d)(;)([a-z]+) / $1 $2 $3 /gi; # Example: 2.1.2014;Waraka
   }
   $s =~ s/^\s+//;
   $s =~ s/\s+$//;
   $s = "$pre$s$post" if defined($pre) && defined($post);
   return $s;
}

# preparation for sub repair_separated_periods:

my $abbrev_s = "etc.|e.g.|i.e.|U.K.|S.p.A.|A.F.P.";
my @abbrevs = split(/\|/, $abbrev_s);
my @exp_abbrevs = ();
foreach $abbrev (@abbrevs) {
   if (($core,$period) = ($abbrev =~ /^(.*?)(\.|)$/)) {
      $core =~ s/\./\\s*\\.\\s*/g;
      $abbrev = $core;
      $abbrev .= "\\b" if $abbrev =~ /[a-z]$/i; # don't split etcetera -> etc. etera
      $abbrev .= "(?:\\s*\\.|)" if $period;
      push(@exp_abbrevs, $abbrev);
   }
}
my $exp_abbrev_s = join("|", @exp_abbrevs);

sub repair_separated_periods {
   local($caller,$s) = @_;

   # separated or missing period
   my $result = "";
   while (($pre, $abbrev, $post) = ($s =~ /^(.*? |)($exp_abbrev_s)(.*)$/)) {
      $abbrev =~ s/ //g;
      $abbrev .= "." unless $abbrev =~ /\.$/;
      $result .= "$pre$abbrev ";
      $s = $post;
   }
   $result .= $s;
   $result =~ s/ +/ /g;
   return $result;
}

# provided by Alex Fraser
sub fix_tokenize {
   local($caller,$s) = @_;

   ## change "2:15" to "2 @:@ 15"
   $s =~ s/(\d)\:(\d)/$1 \@:\@ $2/g;

   ## strip leading zeros from numbers
   $s =~ s/(^|\s)0+(\d)/$1$2/g;

   ## fix rule typo
   $s =~ s/associatedpress/associated press/g;

   ## fix _ entities
   $s =~ s/hong_kong/hong kong/g;
   $s =~ s/united_states/united states/g;

   return $s;
}

sub de_mt_tokenize {
   local($caller,$s) = @_;

   $s =~ s/\s+\@([-:\/])/$1/g;
   $s =~ s/([-:\/])\@\s+/$1/g;
   $s =~ s/\s+\/\s+/\//g;
   return $s;
}

sub surface_forms {
   local($caller,$pe,$modp) = @_;

   $sem = $pe->sem;
   $surf = $pe->surf;
   $synt = $pe->synt;
   $value = $pe->value;
   $gloss = $pe->gloss;
#  $util->log("surface_forms surf:$surf sem:$sem gloss:$gloss value:$value", $logfile);
   if ($sem eq "integer") {
      return ($gloss) if ($gloss =~ /several/) && !($value =~ /\S/);
      print STDERR "Warning: $value not an integer\n" unless $value =~ /^\d+(e\+\d+)?$/;
      if ($pe->get("reliable") =~ /sequence of digits/) {
	 $english = $value;
	 $english = "$prefix $english" if $prefix = $pe->get("prefix");
	 @result = ($english);
      } else {
         @result = $caller->q_number_surface_forms($pe);
      }
   } elsif ($sem eq "decimal number") {
      @result = $caller->q_number_surface_forms($pe);
   } elsif ($sem =~ /(integer|decimal number) range/) {
      @result = $caller->number_range_surface_forms($pe);
   } elsif ($sem eq "ordinal") {
      if ($pe->get("definite")) {
	 $exclude_adverbials_p = 1;
      } elsif (defined($chinesePM) && ($hao = $chinesePM->e2c("hao-day"))
                              && ($gc = $chinesePM->e2c("generic counter"))) {
         $exclude_adverbials_p = ($surf =~ /($hao|$gc)$/);
      } else {
	 $exclude_adverbials_p = 1;
      }
      @result = $caller->ordinal_surface_forms($pe->get("ordvalue") || $pe->value,0,$exclude_adverbials_p, $pe);
   } elsif ($sem eq "fraction") {
      @result = $caller->fraction_surface_forms($pe,$modp);
   } elsif ($sem =~ /monetary quantity/) {
      @result = $caller->currency_surface_forms($pe);
   } elsif ($sem =~ /occurrence quantity/) {
      @result = $caller->occurrence_surface_forms($pe,$modp);
   } elsif ($sem =~ /score quantity/) {
      @result = $caller->score_surface_forms($pe);
   } elsif ($sem =~ /age quantity/) {
      @result = $caller->age_surface_forms($pe, $modp);
   } elsif ($sem =~ /quantity/) {
      @result = $caller->quantity_surface_forms($pe,$modp);
   } elsif ($sem eq "percentage") {
      @result = $caller->percent_surface_forms($pe,$modp);
   } elsif ($sem eq "percentage range") {
      if ($gloss =~ /^and /) {
         @result = ($gloss);
      } else {
         @result = ($gloss, "by $gloss", "of $gloss");
      }
   } elsif ($sem =~ /^(month of the year|month\+year|year)$/) {
      if ($synt eq "pp") {
         @result = ($gloss);
      } elsif ($gloss =~ /^the (beginning|end) of/) {
         @result = ($gloss, "at $gloss");
      } elsif ($gloss =~ /^(last|this|current|next)/) {
         @result = ($gloss);
      } else {
	 # in November; in mid-November
         @result = ($gloss, "in $gloss");
      }
   } elsif ($sem =~ /date(\+year)?$/) {
      @result = $caller->date_surface_forms($pe,$modp);
   } elsif ($sem =~ /year range\b.*\b(decade|century)$/) {
      @result = $caller->decade_century_surface_forms($pe);
   } elsif ($sem eq "day of the month") {
      @result = $caller->day_of_the_month_surface_forms($pe);
   } elsif ($sem =~ /period of the day\+day of the week/) {
      @result = ($gloss);
      push(@result, "on $gloss") if $gloss =~ /^the night/;
   } elsif ($sem =~ /day of the week/) {
      @result = $caller->day_of_the_week_surface_forms($pe);
   } elsif ($sem =~ /^(time)$/) {
      if ($gloss =~ /^at /) {
         @result = ($gloss);
      } else {
         @result = ($gloss, "at $gloss");
      }
   } elsif ($sem =~ /^date range$/) {
      if ($synt eq "pp") {
         @result = ($gloss);
      } elsif ($pe->get("between")) {
	 $b_gloss = "between $gloss";
	 $b_gloss =~ s/-/ and /;
         @result = ($b_gloss, $gloss, "from $gloss");
      } else {
         @result = ($gloss, "from $gloss");
      }
   } elsif ($sem =~ /^date enumeration$/) {
      if ($synt eq "pp") {
         @result = ($gloss);
      } else {
         @result = ($gloss, "on $gloss");
      }
   } elsif ($pe->get("unknown-in-pc")) {
      @result = ();
      foreach $unknown_pos_en (split(/;;/, $pe->get("unknown-pos-en-list"))) {
	 ($engl) = ($unknown_pos_en =~ /^[^:]+:[^:]+:(.*)$/);
         push(@result, $engl) if defined($engl) && ! $util->member($engl, @result);
      }
      @result = ($gloss) unless @result;
   } elsif (($sem =~ /\b(name|unknown)\b/) && (($en_s = $pe->get("english")) =~ /[a-z]/i)) {
      @result = split(/\s*\|\s*/, $en_s);
   } elsif (($sem =~ /^proper\b/) && (($en_s = $pe->get("english")) =~ /[a-z]/i)) {
      @result = split(/\s*\|\s*/, $en_s);
   } else {
      @result = ($gloss);
   }

   if (($sem =~ /^(date\+year|month\+year|year)$/)
       && ($year = $pe->get("year"))
       && ($year =~ /^\d\d$/)
       && (@extend_years = @{$english_entity_style_ht{"ExtendYears"}})
       && ($#extend_years == 1)
       && ($extended_year_start = $extend_years[0])
       && ($extended_year_end   = $extend_years[1])
       && ($extended_year_start <= $extended_year_end)
       && ($extended_year_start + 99 >= $extended_year_end)
       && ($extended_year_start =~ /^\d\d\d\d$/)
       && ($extended_year_end   =~ /^\d\d\d\d$/)) {
      $century1 = substr($extended_year_start, 0, 2);
      $century2 = substr($extended_year_end, 0, 2);
      $exp_year1 = "$century1$year";
      $exp_year2 = "$century2$year";
      if (($extended_year_start <= $exp_year1) && ($exp_year1 <= $extended_year_end)) {
	 $exp_year = $exp_year1;
      } elsif (($extended_year_start <= $exp_year2) && ($exp_year2 <= $extended_year_end)) {
	 $exp_year = $exp_year2;
      } else {
	 $exp_year = "";
      }
      if ($exp_year) {
	 @new_glosses = ();
	 foreach $old_gloss (@result) {
	    $new_gloss = $old_gloss;
	    $new_gloss =~ s/\b$year$/$exp_year/;
	    push (@new_glosses, $new_gloss) unless $new_gloss eq $old_gloss;
	 }
	 push (@result, @new_glosses);
      }
   }

   # tokenize as requested
   @tokenize_list = @{$english_entity_style_ht{"Tokenize"}};
   $tokenize_p = 1 if $util->member("yes", @tokenize_list) 
		   || $util->member("all", @tokenize_list);
   $dont_tokenize_p = 1 if $util->member("no", @tokenize_list) 
		        || $util->member("all", @tokenize_list);
   if ($tokenize_p) {
      @new_result = ();
      foreach $item (@result) {
 	 $t_item = $caller->tokenize($item, *dummy_ht);
	 push(@new_result, $item) if $dont_tokenize_p && ($item ne $t_item);
	 push(@new_result, $t_item);
      }
      @result = @new_result;
   }

   # case as requested
   @case_list = @{$english_entity_style_ht{"Case"}};
   $lower_case_p = $util->member("lower", @case_list) 
	        || $util->member("all", @case_list);
   $reg_case_p = $util->member("regular", @case_list) 
	      || $util->member("all", @case_list);
   if ($lower_case_p) {
      @new_result = ();
      foreach $item (@result) {
         $l_item = "\L$item";
	 push(@new_result, $item) if $reg_case_p && ($item ne $l_item);
	 push(@new_result, $l_item) unless $util->member($l_item, @new_result);
      }
      @result = @new_result;
   }
   # $value = "n/a" unless $value;
   # print STDERR "SF surf:$surf sem:$sem gloss:$gloss value:$value  Result(s): " . join("; ", @result) . "\n";
   return @result; 
}

sub case_list {
   return @{$english_entity_style_ht{"Case"}};
}

sub right_cased_list {
   local($caller, $word) = @_;

   @case_list = @{$english_entity_style_ht{"Case"}};

   @right_cased_core_list = ();
   push(@right_cased_core_list, $word)
      if ($util->member("regular", @case_list) || $util->member("all", @case_list))
     && ! $util->member($word, @right_cased_core_list);
   push(@right_cased_core_list, lc $word)
      if ($util->member("lower", @case_list) || $util->member("all", @case_list))
     && ! $util->member(lc $word, @right_cased_core_list);

   return @right_cased_core_list;
}

sub string2surf_forms {
   local($caller, $text, $lang, $alt_sep) = @_;

   $alt_sep = " | " unless defined($alt_sep);
   $lang = "zh" unless defined($lang);

   if ($lang eq "zh") {
      @pes = $chinesePM->parse_entities_in_string($text);
      $n = $#pes + 1;
#     print "  $n pes\n";
      @pes = $chinesePM->select_reliable_entities(@pes);
      my @res_surf_forms_copy = $caller->reliable_pes2surf_forms($alt_sep, @pes);
      return @res_surf_forms_copy;
   } else {
      return ();
   }
}

sub reliable_pe2surf_forms {
   local($caller, $pe, $parent_reliant_suffices_p) = @_;

   $parent_reliant_suffices_p = 0 unless defined($parent_reliant_suffices_p);
   if ((defined($r = $pe->get("reliable")) && $r)
    || ($parent_reliant_suffices_p && ($parent_pe = $pe->get("parent")) && 
	$parent_pe->get("reliable"))) {
      @surf_forms = $caller->surface_forms($pe);
      if ((($pe->sem =~ /quantity( range)?$/) && !($pe->sem =~ /monetary quantity/))
       || ($util->member($pe->sem, "percentage","fraction"))) {
	    foreach $mod_form ($caller->surface_forms($pe, 1)) {
	       push(@surf_forms, $mod_form) unless $util->member($mod_form, @surf_forms);
	    }
      }
      return @surf_forms;
   }
   return ();
}

sub reliable_pe2surf_form {
   local($caller, $alt_sep, $pe) = @_;

   if (@surf_forms = $caller->reliable_pe2surf_forms($pe)) {
      return $pe->surf . " == " . join($alt_sep, @surf_forms);
   } else {
      return "";
   }
}

sub reliable_pes2surf_forms {
   local($caller, $alt_sep, @pes) = @_;

   my @res_surf_forms = ();
   foreach $pe (@pes) {
      if ($new_surf_form = $caller->reliable_pe2surf_form($alt_sep, $pe)) {
         push(@res_surf_forms, $new_surf_form);
      }
   }
   return @res_surf_forms;
}

sub string_contains_ascii_letter {
   local($caller,$string) = @_;
   return $string =~ /[a-zA-Z]/;
}

sub string_starts_w_ascii_letter {
   local($caller,$string) = @_;
   return $string =~ /^[a-zA-Z]/;
}

sub en_lex_bin {
   local($caller, $word) = @_;

   $word =~ s/\s+//g;
   $word =~ s/[-_'\/]//g;
   $word =~ tr/A-Z/a-z/;
   return "digit" if $word =~ /^\d/;
   return "special" unless $word =~ /^[a-z]/;
   return substr($word, 0, 1);
}

sub skeleton_bin {
   local($caller, $sk_bin_control, $word) = @_;

   $word =~ s/\s+//g;
   $word =~ s/[-_'\/]//g;
   $word =~ tr/A-Z/a-z/;
   return "E" unless $word;
   if ($sk_bin_control =~ /^v1/i) {
      return $word if length($word) <= 2;
      return substr($word, 0, 3) if $word =~ /^(b|f[lnrt]|gr|j[nr]|k|l[nt]|m|n[kmst]|r[knst]|s|t)/;
      return substr($word, 0, 2);
   } elsif ($sk_bin_control =~ /d6f$/) {
      return $word if length($word) <= 6;
      return substr($word, 0, 6);
   } elsif ($sk_bin_control =~ /d5f$/) {
      return $word if length($word) <= 5;
      return substr($word, 0, 5);
   } elsif ($sk_bin_control =~ /d4f$/) {
      return $word if length($word) <= 4;
      return substr($word, 0, 4);
   } else {
      return $word if length($word) <= 4;
      return substr($word, 0, 5) if $word =~ /^(bnts|brnt|brst|brtk|brtn|brts|frst|frts|klts|kntr|knts|krst|krtn|krts|ksks|kstr|lktr|ntrs|sbrt|skrt|sntr|strn|strt|trns|trts|ts)/;
      return substr($word, 0, 4);
   }
}

sub skeleton_bin_sub_dir {
   local($caller, $sk_bin_control, $skeleton_bin) = @_;

   $sk_bin_control = "v1" unless defined($sk_bin_control);
   return "" if $sk_bin_control =~ /^v1/i;
   if ($sk_bin_control =~ /^2d4d\df$/) {
      return "SH/SHOR" if (length($skeleton_bin) < 2);
      return substr($skeleton_bin, 0, 2) . "/" . substr($skeleton_bin, 0, 2) . "SH" if (length($skeleton_bin) < 4);
      return substr($skeleton_bin, 0, 2) . "/" . substr($skeleton_bin, 0, 4);
   } elsif ($sk_bin_control =~ /^2d3d\df$/) {
      return "SH/SHO" if (length($skeleton_bin) < 2);
      return substr($skeleton_bin, 0, 2) . "/" . substr($skeleton_bin, 0, 2) . "S" if (length($skeleton_bin) < 3);
      return substr($skeleton_bin, 0, 2) . "/" . substr($skeleton_bin, 0, 3);
   }
   $bin3 = "ts";
   return "SH" if (length($skeleton_bin) < 2) || ($skeleton_bin =~ /^($bin3)$/);
   return substr($skeleton_bin, 0, 3) if $skeleton_bin =~ /^($bin3)/;
   return substr($skeleton_bin, 0, 2);
}

sub en_words_and_counts_matching_skeletons {
   local($caller, $sk_bin_version, @skeletons) = @_;

   return () unless @skeletons;

   @rem_skeletons = sort @skeletons;
   $previous_skeleton = "";
   $current_skeleton = shift @rem_skeletons;
   @list = ($current_skeleton);
   @lists = ();

   $current_bin = "";
   while ($current_skeleton) {
      unless ($current_skeleton eq $previous_skeleton) {
         $current_skeleton_bin = $caller->skeleton_bin($sk_bin_version, $current_skeleton);
	 unless ($current_skeleton_bin eq $current_bin) {
	    # need to read from new file
	    close(IN) if $current_bin;
	    $current_bin = $current_skeleton_bin;
	    $current_bin_subdir
	       = $caller->skeleton_bin_sub_dir($sk_bin_version, $current_bin);
	    if ($current_bin_subdir) {
	       $en_skeleton_file = File::Spec->catfile($english_resources_skeleton_dir, 
						       $current_bin_subdir, 
						       "$current_bin.txt");
	    } else {
	       $en_skeleton_file = File::Spec->catfile($english_resources_skeleton_dir, 
						       "$current_bin.txt");
	    }
	    # print STDERR "  Perusing $en_skeleton_file ...\n";
            if (open(IN, $en_skeleton_file)) {
	       $en_skeleton_file_exists = 1;
	    } else {
	       $en_skeleton_file_exists = 0;
	       print STDERR "Can't open $en_skeleton_file (Point A)\n";
	    }
	 }
	 $previous_skeleton = $current_skeleton;
      }
      $_ = <IN> if $en_skeleton_file_exists;
      unless ($en_skeleton_file_exists && defined($_)) {
	 push(@lists, join(' ; ', @list));
	 if (@rem_skeletons) {
	    $current_skeleton = shift @rem_skeletons;
	    @list = ($current_skeleton);
	 } else {
	    $current_skeleton = "";
	 }
	 next;
      }
      ($skeleton) = ($_ =~ /^(\S+)\t/);
      next unless defined($skeleton);
      $skeletons_match_p = $caller->skeletons_match_p($skeleton, $current_skeleton);
      next if ($skeleton lt $current_skeleton) && ! $skeletons_match_p;
      if ($skeletons_match_p) {
	 ($token, $count) = ($_ =~ /^\S+\t(\S|\S[-' a-zA-Z]*\S)\t(\d+)\s*$/);
	 push(@list, "$token : $count") if defined($token) && defined($count);
      } else {
	 while ($current_skeleton lt $skeleton) {
	    push(@lists, join(' ; ', @list));
	    unless (@rem_skeletons) {
	       close(IN) if $current_bin;
	       $current_skeleton = "";
	       last;
	    }
	    $current_skeleton = shift @rem_skeletons;
	    @list = ($current_skeleton);
	 }
	 if ($caller->skeletons_match_p($skeleton, $current_skeleton)) {
	    ($token, $count) = ($_ =~ /^\S+\t(\S|\S[-' a-zA-Z]*\S)\t(\d+)\s*$/);
	    push(@list, "$token : $count") if defined($token) && defined($count);
	 }
      }
   }
   close(IN) if $current_bin;
   return @lists;
}

sub skeletons_match_p {
# one of the skeletons might have been cut off at max
   local($caller, $skeleton1, $skeleton2, $max) = @_;

   return 1 if $skeleton1 eq $skeleton2;

   $max = 5 unless defined($max);
   if ((length($skeleton1) > length($skeleton2)) && (length($skeleton2) == $max)) {
      return ($skeleton1 =~ /^$skeleton2/) ? 1 : 0;
   } elsif ((length($skeleton2) > length($skeleton1)) && (length($skeleton1) == $max)) {
      return ($skeleton2 =~ /^$skeleton1/) ? 1 : 0;
   } else {
      return 0;
   }
}

sub token_weird_or_too_long {
   local($caller, *WARNING_FH, $token) = @_;

   $lc_token = lc $token;
   $norm_token = $lc_token;
   $norm_token =~ s/[-' ,]//g;
   $snippet4_5 = "";
   $snippet4_5 = substr($norm_token, 4, 2) if length($norm_token) >= 10;
   $snippet4_6 = "";
   $snippet4_6 = substr($norm_token, 4, 3) if length($norm_token) >= 10;
   if (($norm_token =~ /(kkk|vvv|www|xxx|yyy|zzz)/) ||
       ($norm_token =~ /[acgt]{15,}/) ||                # DNA sequence
       ($snippet4_5 && ($norm_token =~ /($snippet4_5){5,}/)) ||  # 2-letter repetition
       ($snippet4_6 && ($norm_token =~ /($snippet4_6){4,}/)) ||  # 3-letter repetition
       ($norm_token =~ /[bcdfghjklmnpqrstvwxz]{8,}/) || # too many consonants
       ($token =~ /(DDD)/) ||
	 (($lc_token =~ /fff/) && ! ($lc_token =~ /schifff/))) {
      print WARNING_FH "skipping (WEIRD): $_";
      return 1;
   }
   if ((length($norm_token) >= 50) ||
       ((length($norm_token) >= 28)

	  # typical German compound noun components
          && ! ($norm_token =~ /entwicklung/)
          && ! ($norm_token =~ /fabrik/)
          && ! ($norm_token =~ /finanz/)
          && ! ($norm_token =~ /forschung/)
          && ! ($norm_token =~ /geschwindigkeit/)
          && ! ($norm_token =~ /gesundheit/)
          && ! ($norm_token =~ /gewohnheit/)
          && ! ($norm_token =~ /schaft/)
          && ! ($norm_token =~ /schifffahrt/)
          && ! ($norm_token =~ /sicherheit/)
          && ! ($norm_token =~ /vergangen/)
          && ! ($norm_token =~ /versicherung/)
          && ! ($norm_token =~ /unternehmen/)
          && ! ($norm_token =~ /verwaltung/)

	  # Other Germanic languages
          && ! ($norm_token =~ /aktiebolag/)
          && ! ($norm_token =~ /aktieselskab/)
          && ! ($norm_token =~ /ontwikkeling/)

	  # chemical
          && ! ($norm_token =~ /phetamine/)
          && ! ($norm_token =~ /ethyl/)

	  # medical
	  && ! ($norm_token =~ /^pneumonaultramicroscopicsilicovolcanoconios[ei]s$/)

	  # business
          && ! ($norm_token =~ /PriceWaterhouse/)
      )) {
             print WARNING_FH "skipping (TOO LONG): $_";
             return 1;
   }
   return 0;
}

sub xml_de_accent {
   local($caller, $string) = @_;

   # for the time being, unlauts are mapped to main vowel (without "e")

   $string =~ s/\&#19[2-7];/A/g;
   $string =~ s/\&#198;/Ae/g;
   $string =~ s/\&#199;/C/g;
   $string =~ s/\&#20[0-3];/E/g;
   $string =~ s/\&#20[4-7];/I/g;
   $string =~ s/\&#208;/Dh/g;
   $string =~ s/\&#209;/N/g;
   $string =~ s/\&#21[0-4];/O/g;
   $string =~ s/\&#216;/O/g;
   $string =~ s/\&#21[7-9];/U/g;
   $string =~ s/\&#220;/U/g;
   $string =~ s/\&#221;/Y/g;
   $string =~ s/\&#222;/Th/g;

   $string =~ s/\&#223;/ss/g;
   $string =~ s/\&#22[4-9];/a/g;
   $string =~ s/\&#230;/ae/g;
   $string =~ s/\&#231;/c/g;
   $string =~ s/\&#23[2-5];/e/g;
   $string =~ s/\&#23[6-9];/i/g;
   $string =~ s/\&#240;/dh/g;
   $string =~ s/\&#241;/n/g;
   $string =~ s/\&#24[2-6];/o/g;
   $string =~ s/\&#248;/o/g;
   $string =~ s/\&#249;/u/g;
   $string =~ s/\&#25[0-2];/u/g;
   $string =~ s/\&#253;/y/g;
   $string =~ s/\&#254;/th/g;
   $string =~ s/\&#255;/y/g;
   $string =~ s/\xE2\x80\x99/'/g;

   return $string;
}

sub de_accent {
   local($caller, $string) = @_;

   # for the time being, unlauts are mapped to main vowel (without "e")

   $string =~ s/\xC3[\x80-\x85]/A/g;
   $string =~ s/\xC3\x86/Ae/g;
   $string =~ s/\xC3\x87/C/g;
   $string =~ s/\xC3[\x88-\x8B]/E/g;
   $string =~ s/\xC3[\x8C-\x8F]/I/g;
   $string =~ s/\xC3\x90/Dh/g;
   $string =~ s/\xC3\x91/N/g;
   $string =~ s/\xC3[\x92-\x96]/O/g;
   $string =~ s/\xC3\x98/O/g;
   $string =~ s/\xC3[\x99-\x9C]/U/g;
   $string =~ s/\xC3\x9D/Y/g;
   $string =~ s/\xC3\x9E/Th/g;

   $string =~ s/\xC3\x9F/ss/g;
   $string =~ s/\xC3[\xA0-\xA5]/a/g;
   $string =~ s/\xC3\xA6/ae/g;
   $string =~ s/\xC3\xA7/c/g;
   $string =~ s/\xC3[\xA8-\xAB]/e/g;
   $string =~ s/\xC3[\xAC-\xAF]/i/g;
   $string =~ s/\xC3\xB0/dh/g;
   $string =~ s/\xC3\xB1/n/g;
   $string =~ s/\xC3[\xB2-\xB6]/o/g;
   $string =~ s/\xC3\xB8/o/g;
   $string =~ s/\xC3[\xB9-\xBC]/u/g;
   $string =~ s/\xC3\xBD/y/g;
   $string =~ s/\xC3\xBE/th/g;
   $string =~ s/\xC3\xBF/y/g;
   $string =~ s/\xE2\x80\x99/'/g;

   return $string;
}

sub common_non_name_cap_p {
   local($caller, $word) = @_;
   return defined($english_ht{(lc $word)}->{COMMON_NON_NAME_CAP});
}

sub language {
   return "English";
}

sub language_id {
   return "en";
}

sub parse_entities_in_string {
   local($caller, $string) = @_;

   $ParseEntry->set_current_lang("en");
   @pes = $ParseEntry->init_ParseEntry_list($string);
   @pes = $caller->lexical_heuristic(@pes);
   @pes = $caller->base_number_heuristic(@pes);

   return @pes;
}

sub lexical_heuristic {
   local($caller, @pes) = @_;

   $i = 0;
   while ($i <= $#pes) {
      $pe = $pes[$i];
      if ($pe->undefined("synt")) {
	 if ($pe->surf =~ /^\d+(,\d\d\d)*\.\d+/) {
	    $pe->set("synt", "cardinal");
	    $pe->set("sem", "decimal number");
	    $value = $pe->surf;
	    $value =~ s/,//g;
	    $pe->set("value", $value);
	 } elsif ($pe->surf =~ /^\d+(,\d\d\d)*$/) {
	    $pe->set("synt", "cardinal");
	    $pe->set("sem", "integer");
	    $value = $pe->surf;
	    $value =~ s/,//g;
	    $pe->set("value", $value);
	 } elsif ($pe->surf =~ /^([-",\.;\s:()\/%]|\@[-:\/]\@|[-:\/]\@|\@[-:\/])$/) {
	    $pe->set("gloss", $pe->surf);
	    $pe->set("synt", "punctuation");
         } else {
	    ($length,$english) = $caller->find_max_lex_match($i,3,@pes);
	    if ($length) {
	       if ($length > 1) {
		  @slot_value_list = ();
	          @children = splice(@pes,$i,$length);
		  @roles = $util->list_with_same_elem($length,"lex");
		  $pe = $ParseEntry->newParent(*slot_value_list,*children,*roles);
		  $pe->set("surf",$english);
		  $pe->set("eot",1) if $pe->eot_p;
		  splice(@pes,$i,0,$pe);
	       } else {
		  $pe = $pes[$i];
	       }
	       $annot_s = $english_annotation_ht{$english};
	       $annot_s =~ s/^\s*:+//;
	       $annot_s =~ s/^\s+//;
	       $annot_s =~ s/\s+$//;
	       $annot_s =~ s/#.*$//;
               foreach $annot (split('::', $annot_s)) {
                  ($slot, $value) = ($annot =~ /^([^:]+):(.*)$/);
		  if (defined($slot) && defined($value)) {
		     $pe->set($slot, $value);
		  }
		  $pe->set("sem", "integer") if ($slot eq "synt") && ($value eq "cardinal");
	       } 
	       $pe->set("ord-value", $ord_value)
	          if $ord_value = $english_annotation_ht{"_EN_SYNT_"}->{(lc $english)}->{"ordinal"}->{"value"};
	       $pe->set("card-value", $card_value)
	          if $card_value = $english_annotation_ht{"_EN_SYNT_"}->{(lc $english)}->{"cardinal"}->{"value"};
	    }
	 }
      }
      $i++;
   }
   return @pes;
}

# builds numbers, incl. integers, decimal numbers, fractions, percentages, ordinals
sub base_number_heuristic {
   local($caller, @pes) = @_;

   $i = 0;
   # $ParseEntry->print_pes("start base_number_heuristic",$i,@pes);
   while ($i <= $#pes) {
      # forty-five
      ($head_pe, @pes) =
	 $ParseEntry->build_parse_entry("composite number plus","",$i,*pes,
	   '        :head :($pe->sem eq "integer") && ($pe->value =~ /^[1-9]0$/)',
           'optional:dummy:$pe->surf eq "\@-\@"',
	   '        :mod  :($pe->sem eq "integer") && ($pe->value =~ /^[1-9]$/)');
      if ($head_pe) { # match succeeded
	 $value1 = $head_pe->childValue("head");
	 $value2 = $head_pe->childValue("mod");
	 $head_pe->set("value", $value1 + $value2);
      }
      # six billion
      ($head_pe, @pes) =
	 $ParseEntry->build_parse_entry("composite number 1000","",$i,*pes,
	   '  :mod :(($value1 = $pe->value) =~ /^\d+(.\d+)?$/) && ($value1 < 1000)',
	   '  :head:($value2 = $pe->value) =~ /^1(000)+$/');
      if ($head_pe) { # match succeeded
	 $value1 = $head_pe->childValue("mod");
	 $value2 = $head_pe->childValue("head");
	 $head_pe->set("value", $value1 * $value2);
      }
      # twenty-second
      ($head_pe, @pes) =
	 $ParseEntry->build_parse_entry("composite ordinal","",$i,*pes,
	   '        :mod  :($pe->sem eq "integer") && ($pe->value =~ /^[1-9]0$/)',
	   'optional:dummy:$pe->surf eq "\@-\@"',
	   '        :head :$pe->get("ord-value") =~ /^[1-9]$/');
      if ($head_pe) { # match succeeded
	 $value1 = $head_pe->childSlot("head", "ord-value");
	 $value2 = $head_pe->childValue("mod");
	 $head_pe->set("value", $value1 + $value2);
      }
      $i++;
   }
 
   return @pes;
}

sub find_max_lex_match {
   local($caller,$start,$maxlength,@pes) = @_;

   while ($maxlength > 0) {
      if (($english = $util->pes_subseq_surf($start,$maxlength,"en",@pes))
       && defined($english_annotation_ht{$english})
       && ($english =~ /\S/)) {
	 return ($maxlength, $english);
      } else {
	 $maxlength--;
      }
   }
   return (0,"");
}

sub select_reliable_entities {
   local($caller, @pes) = @_;

   foreach $i (0 .. $#pes) {
      $pe = $pes[$i];
      $surf = $pe->surf;
      
      $pe->set("reliable",1);
   }
   return @pes;
}

sub negatives_p {
   # (cool <-> uncool), (improper <-> proper), ...
   local($caller, $s1, $s2) = @_;

   my $g_s1 = $util->regex_guard($s1);
   my $g_s2 = $util->regex_guard($s2);
   return 1 if $s1 =~ /^[iu]n$g_s2$/;
   return 1 if $s1 =~ /^il$g_s2$/ && ($s2 =~ /^l/);
   return 1 if $s1 =~ /^im$g_s2$/ && ($s2 =~ /^[mp]/);

   return 1 if $s2 =~ /^[iu]n$g_s1$/;
   return 1 if $s2 =~ /^il$g_s1$/ && ($s1 =~ /^l/);
   return 1 if $s2 =~ /^im$g_s1$/ && ($s1 =~ /^[mp]/);

   return 0;
}

sub present_participle_p {
   local($caller, $pe) = @_;

   my $aux_pe = $pe->child("aux");
   return $caller->present_participle_p($aux_pe) if $aux_pe;
   my $head_pe = $pe->child("head");
   return $caller->present_participle_p($head_pe) if $head_pe;
   return ($pe->synt =~ /^VBG/);
}


%engl_value_ht = (
   "monday" => 1,
   "tuesday" => 2,
   "wednesday" => 3,
   "thursday" => 4,
   "friday" => 5,
   "saturday" => 6,
   "sunday" => 7,

   "january" => 1,
   "february" => 2,
   "march" => 3,
   "april" => 4,
   "may" => 5,
   "june" => 6,
   "july" => 7,
   "august" => 8,
   "september" => 9,
   "october" => 10,
   "november" => 11,
   "december" => 12,

   "spring" => 1,
   "summer" => 2,
   "fall" => 3,
   "autumn" => 3,
   "winter" => 4,

   "morning" => 1,
   "noon" => 2,
   "afternoon" => 3,
   "evening" => 4,
   "night" => 5,

   "picosecond" => 1,
   "nanosecond" => 2,
   "microsecond" => 3,
   "millisecond" => 4,
   "second" => 5,
   "minute" => 6,
   "hour" => 7,
   "day" => 8,
   "week" => 9,
   "fortnight" => 10,
   "month" => 11,
   "year" => 12,
   "decade" => 13,
   "century" => 14,
   "millennium" => 15,

   "nanometer" => 2,
   "micrometer" => 3,
   "millimeter" => 4,
   "centimeter" => 5,
   "decimeter" => 6,
   "meter" => 7,
   "kilometer" => 8,
   "inch" => 11,
   "foot" => 12,
   "yard" => 13,
   "mile" => 14,
   "lightyear" => 20,

   "microgram" => 2,
   "milligram" => 3,
   "gram" => 4,
   "kilogram" => 5,
   "ton" => 6,
   "ounce" => 14,
);

sub engl_order_value {
   local($this, $s) = @_;

   return $value = $engl_value_ht{(lc $s)} || 0;
}

1;

