################################################################
#                                                              #
# Chinese                                                      #
#                                                              #
################################################################

package NLP::Chinese;

$utf8 = NLP::UTF8;
%empty_ht = ();

sub read_chinese_tonal_pinyin_files {
   local($caller, *ht, @filenames) = @_;

   $n_kHanyuPinlu = 0;
   $n_kXHC1983 = 0;
   $n_kHanyuPinyin = 0;
   $n_kMandarin = 0;
   $n_cedict = 0;
   $n_simple_pinyin = 0;

   foreach $filename (@filenames) {
      if ($filename =~ /unihan/i) {
	 my $line_number = 0;
         if (open(IN, $filename)) {
            while (<IN>) {
	       $line_number++;
               next if /^#/;
               s/\s*$//;
               if (($u, $type, $value) = split(/\t/, $_)) {
                  if ($type =~ /^(kHanyuPinlu|kXHC1983|kHanyuPinyin|kMandarin)$/) {
	             $u = $util->trim($u);
	             $type = $util->trim($type);
	             $value = $util->trim($value);
                     $f = $utf8->unicode_string2string($u);

                     if ($type eq "kHanyuPinlu") {
	                $value =~ s/\(.*?\)//g;
			$value = $util->trim($value);
                        $translit = $caller->number_to_accent_tone($value);
	                $ht{"kHanyuPinlu"}->{$f} = $translit;
	                $n_kHanyuPinlu++;
                     } elsif ($type eq "kXHC1983") {
	                @translits = ($value =~ /:(\S+)/g);
	                $translit = join(" ", @translits);
	                $ht{"kXHC1983"}->{$f} = $translit;
	                $n_kXHC1983++;
                     } elsif ($type eq "kHanyuPinyin") {
	                $value =~ s/^.*://;
	                $value =~ s/,/ /g;
	                $ht{"kHanyuPinyin"}->{$f} = $value;
	                $n_kHanyuPinyin++;
                     } elsif ($type eq "kMandarin") {
			$ht{"kMandarin"}->{$f} = $value;
			$n_kMandarin++;
                     }
                  }
               }
            }
            close(IN);
            print "Read in $n_kHanyuPinlu kHanyuPinlu, $n_kXHC1983 n_kXHC1983, $n_kHanyuPinyin n_kHanyuPinyin $n_kMandarin n_kMandarin\n";
         } else {
	    print STDERR "Can't open $filename\n";
	 }
      } elsif ($filename =~ /cedict/i) {
         if (open(IN, $filename)) {
	    my $line_number = 0;
            while (<IN>) {
	       $line_number++;
               next if /^#/;
               s/\s*$//;
               if (($f, $translit) = ($_ =~ /^\S+\s+(\S+)\s+\[([^\[\]]+)\]/)) {
                  $translit = $utf8->extended_lower_case($translit);
                  $translit = $caller->number_to_accent_tone($translit);
                  $translit =~ s/\s//g;
		  if ($old_translit = $ht{"cedict"}->{$f}) {
                     # $ht{CONFLICT}->{("DUPLICATE " . $f)} = "CEDICT($f): $old_translit\nCEDICT($f): $translit (duplicate)\n" unless $translit eq $old_translit;
                     $ht{"cedicts"}->{$f} = join(" ", $ht{"cedicts"}->{$f}, $translit) unless $old_translit eq $translit;
		  } else {
                     $ht{"cedict"}->{$f} = $translit;
                     $ht{"cedicts"}->{$f} = $translit;
		  }
                  $n_cedict++;
	       }
            }
            close(IN);
            # print "Read in $n_cedict n_cedict\n";
         } else {
	    print STDERR "Can't open $filename";
         }
      } elsif ($filename =~ /chinese_to_pinyin/i) {
	 if (open(IN, $filename)) {
	    my $line_number = 0;
	    while (<IN>) {
	       $line_number++;
	       next if /^#/;
	       if (($f, $translit) = ($_ =~ /^(\S+)\t(\S+)\s*$/)) {
		  $ht{"simple_pinyin"}->{$f} = $translit; 
		  $n_simple_pinyin++;
	       }
	    }
	    close(IN);
	    # print "Read in $n_simple_pinyin n_simple_pinyin\n";
	 } else {
	    print STDERR "Can't open $filename";
	 }
      } else {
	 print STDERR "Don't know what to do with file $filename (in read_chinese_tonal_pinyin_files)\n";
      }
   }
}

sub tonal_pinyin {
   local($caller, $s, *ht, $gloss) = @_;

   return $result if defined($result = $ht{COMBINED}->{$s});

   $cedict_pinyin = $ht{"cedict"}->{$s} || "";
   $cedicts_pinyin = $ht{"cedicts"}->{$s} || "";
   $unihan_pinyin = "";
   @characters = $utf8->split_into_utf8_characters($s, "return only chars", *empty_ht);
   foreach $c (@characters) {
      if ($pinyin = $ht{"simple_pinyin"}->{$c}) {
	 $unihan_pinyin .= $pinyin;
      } elsif ($pinyin = $ht{"kHanyuPinlu"}->{$c}) {
	 $pinyin =~ s/^(\S+)\s.*$/$1/;
	 $unihan_pinyin .= $pinyin;
      } elsif ($pinyin = $ht{"kXHC1983"}->{$c}) {
	 $pinyin =~ s/^(\S+)\s.*$/$1/;
	 $unihan_pinyin .= $pinyin;
      } elsif ($pinyin = $ht{"kHanyuPinyin"}->{$c}) {
	 $pinyin =~ s/^(\S+)\s.*$/$1/;
	 $unihan_pinyin .= $pinyin;
      } elsif ($pinyin = $ht{"cedicts"}->{$c}) {
	 $pinyin =~ s/^(\S+)\s.*$/$1/;
	 $unihan_pinyin .= $pinyin;
      # middle dot, katakana middle dot, multiplication sign
      } elsif ($c =~ /^(\xC2\xB7|\xE3\x83\xBB|\xC3\x97)$/) {
	 $unihan_pinyin .= $c;
      # ASCII
      } elsif ($c =~ /^([\x21-\x7E])$/) {
	 $unihan_pinyin .= $c;
      } else {
	 $unihan_pinyin .= "?";
	 $hex = $utf8->utf8_to_hex($c);
	 $unicode = uc $utf8->utf8_to_4hex_unicode($c);
	 # print STDERR "Tonal pinyin: Unknown character $c ($hex/U+$unicode) -> ?\n";
      }
   }
   $pinyin_title = "";
   if (($#characters >= 1) && $cedicts_pinyin) {
      foreach $pinyin (split(/\s+/, $cedicts_pinyin)) {
	 $pinyin_title .= "$s $pinyin (CEDICT)\n";
      }
      $pinyin_title .= "\n";
   }
   foreach $c (@characters) {
      my %local_ht = ();
      @pinyins = ();
      foreach $type (("kHanyuPinlu", "kXHC1983", "kHanyuPinyin", "cedicts")) {
	 if ($pinyin_s = $ht{$type}->{$c}) {
	    foreach $pinyin (split(/\s+/, $pinyin_s)) {
	       push(@pinyins, $pinyin) unless $util->member($pinyin, @pinyins);
	       $type2 = ($type eq "cedicts") ? "CEDICT" : $type;
	       $local_ht{$pinyin} = ($local_ht{$pinyin}) ? join(", ", $local_ht{$pinyin}, $type2) : $type2;
	    }
	 }
      }
      foreach $pinyin (@pinyins) {
	 $type_s = $local_ht{$pinyin};
	 $pinyin_title .= "$c $pinyin ($type_s)\n";
      }
   }
   $pinyin_title =~ s/\n$//;
   $pinyin_title =~ s/\n/&#xA;/g;
   $unihan_pinyin = "" if $unihan_pinyin =~ /^\?+$/;
   if (($#characters >= 1) && $cedict_pinyin && $unihan_pinyin && ($unihan_pinyin ne $cedict_pinyin)) {
      $log = "Gloss($s): $gloss\nCEdict($s): $cedicts_pinyin\nUnihan($s): $unihan_pinyin\n";
      foreach $type (("kHanyuPinlu", "kXHC1983", "kHanyuPinyin")) {
	 $log_line = "$type($s): ";
	 foreach $c (@characters) {
	    $pinyin = $ht{$type}->{$c} || "";
	    if ($pinyin =~ / /) {
	       $log_line .= "($pinyin)";
	    } elsif ($pinyin) {
	       $log_line .= $pinyin;
	    } else {
	       $log_line .= "?";
	    }
	 }
	 $log .= "$log_line\n";
      }
      $ht{CONFLICT}->{$s} = $log;
   }
   $result = $unihan_pinyin || $cedict_pinyin;
   $result = $cedict_pinyin if ($#characters > 0) && $cedict_pinyin;
   $ht{COMBINED}->{$s} = $result;
   $ht{PINYIN_TITLE}->{$s} = $pinyin_title;
   return $result;
}

%number_to_accent_tone_ht = (
   "a1", "\xC4\x81", "a2", "\xC3\xA1", "a3", "\xC7\x8E", "a4", "\xC3\xA0",
   "e1", "\xC4\x93", "e2", "\xC3\xA9", "e3", "\xC4\x9B", "e4", "\xC3\xA8",
   "i1", "\xC4\xAB", "i2", "\xC3\xAD", "i3", "\xC7\x90", "i4", "\xC3\xAC",
   "o1", "\xC5\x8D", "o2", "\xC3\xB3", "o3", "\xC7\x92", "o4", "\xC3\xB2",
   "u1", "\xC5\xAB", "u2", "\xC3\xBA", "u3", "\xC7\x94", "u4", "\xC3\xB9",
   "u:1","\xC7\x96", "u:2","\xC7\x98", "u:3","\xC7\x9A", "u:4","\xC7\x9C",
   "\xC3\xBC1","\xC7\x96","\xC3\xBC2","\xC7\x98","\xC3\xBC3","\xC7\x9A","\xC3\xBC4","\xC7\x9C"
);

sub number_to_accent_tone {
   local($caller, $s) = @_;

   my $result = "";
   while (($pre,$alpha,$tone_number,$rest) = ($s =~ /^(.*?)((?:[a-z]|u:|\xC3\xBC)+)([1-5])(.*)$/i)) {
      if ($tone_number eq "5") {
         $result .= "$pre$alpha";
      } elsif ((($pre_acc,$acc_letter,$post_acc) = ($alpha =~ /^(.*)([ae])(.*)$/))
       || (($pre_acc,$acc_letter,$post_acc) = ($alpha =~ /^(.*)(o)(u.*)$/))
       || (($pre_acc,$acc_letter,$post_acc) = ($alpha =~ /^(.*)(u:|[iou]|\xC3\xBC)([^aeiou]*)$/))) {
         $result .= "$pre$pre_acc" . ($number_to_accent_tone_ht{($acc_letter . $tone_number)} || ($acc_letter . $tone_number)) . $post_acc;
      } else {
         $result .= "$pre$alpha$tone_number";
      }
      $s = $rest;
   }
   $result .= $s;
   $result =~ s/u:/\xC3\xBC/g;
   return $result;
}

sub string_contains_utf8_cjk_unified_ideograph_p {
   local($caller, $s) = @_;

   return ($s =~ /([\xE4-\xE9]|\xE3[\x90-\xBF]|\xF0[\xA0-\xAC])/);
}

1;
