################################################################
#                                                              #
# utilities                                                    #
#                                                              #
################################################################

package NLP::utilities;

use File::Spec;
use Time::Local;

use constant DEBUGGING => 0;

sub member {
   local($this,$elem,@array) = @_;

   my $a;
   if (defined($elem)) {
      foreach $a (@array) {
	 if (defined($a)) {
            return 1 if $elem eq $a;
	 } else {
	    $DB::single = 1; # debugger breakpoint
	    print STDERR "\nWarning: Undefined variable utilities::member::a\n";
	 }
      }
   } else {
      $DB::single = 1; # debugger breakpoint
      print STDERR "\nWarning: Undefined variable utilities::member::elem\n";
   }
   return 0;
}

sub dual_member {
   local($this,$elem1,$elem2,*array1,*array2) = @_;
   # returns 1 if there exists a position $n
   #   such that $elem1 occurs at position $n in @array1 
   #    and $elem2 occurs at same position $n in @array2

   return 0 unless defined($elem1) && defined($elem2);
   my $last_index = ($#array1 < $#array2) ? $#array1 : $#array2; #min
   my $a;
   my $b;
   foreach $i ((0 .. $last_index)) {
      return 1 if defined($a = $array1[$i]) && defined($b = $array2[$i]) && ($a eq $elem1) && ($b eq $elem2);
   }
   return 0;
}

sub sorted_list_equal {
   local($this,*list1,*list2) = @_;

   return 0 unless $#list1 == $#list2;
   foreach $i ((0 .. $#list1)) {
      return 0 unless $list1[$i] eq $list2[$i];
   }
   return 1;
}

sub trim {
   local($this, $s) = @_;

   $s =~ s/^\s*//;
   $s =~ s/\s*$//;
   $s =~ s/\s+/ /g;
   return $s;
}

sub trim2 {
   local($this, $s) = @_;

   $s =~ s/^\s*//;
   $s =~ s/\s*$//;
   return $s;
}

sub cap_member {
   local($this,$elem,@array) = @_;

   my $a;
   my $lc_elem = lc $elem;
   foreach $a (@array) {
      return $a if $lc_elem eq lc $a;
   }
   return "";
}

sub remove_elem {
   local($this,$elem,@array) = @_;

   return @array unless $this->member($elem, @array);
   @rm_list = ();
   foreach $a (@array) {
      push(@rm_list, $a) unless $elem eq $a;
   }
   return @rm_list;
}

sub intersect_p {
   local($this,*list1,*list2) = @_;

   foreach $elem1 (@list1) {
      if (defined($elem1)) {
         foreach $elem2 (@list2) {
	    if (defined($elem2)) {
	       return 1 if $elem1 eq $elem2;
	    } else {
	       $DB::single = 1; # debugger breakpoint
               print STDERR "\nWarning: Undefined variable utilities::intersect_p::elem2\n";
            }
         }
      } else {
	 $DB::single = 1; # debugger breakpoint
         print STDERR "\nWarning: Undefined variable utilities::intersect_p::elem1\n";
      }
   }
   return 0;
}

sub intersect_expl_p {
   local($this,*list1,@list2) = @_;

   foreach $elem1 (@list1) {
      foreach $elem2 (@list2) {
	 return 1 if $elem1 eq $elem2;
      }
   }
   return 0;
}

sub intersection {
   local($this,*list1,*list2) = @_;

   @intersection_list = ();
   foreach $elem1 (@list1) {
      foreach $elem2 (@list2) {
	 push(@intersection_list, $elem1) if ($elem1 eq $elem2) && ! $this->member($elem1, @intersection_list);
      }
   }
   return @intersection_list;
}

sub cap_intersect_p {
   local($this,*list1,*list2) = @_;

   foreach $elem1 (@list1) {
      $lc_elem1 = lc $elem1;
      foreach $elem2 (@list2) {
	 return 1 if $lc_elem1 eq lc $elem2;
      }
   }
   return 0;
}

sub subset_p {
   local($this,*list1,*list2) = @_;

   foreach $elem1 (@list1) {
      return 0 unless $this->member($elem1, @list2);
   }
   return 1;
}

sub cap_subset_p {
   local($this,*list1,*list2) = @_;

   foreach $elem1 (@list1) {
      return 0 unless $this->cap_member($elem1, @list2);
   }
   return 1;
}

sub unique {
   local($this, @list) = @_;

   my %seen = ();
   @uniq = ();
   foreach $item (@list) {
      push(@uniq, $item) unless $seen{$item}++;
   }
   return @uniq;
}

sub position {
   local($this,$elem,@array) = @_;
   $i = 0;
   foreach $a (@array) {
      return $i if $elem eq $a;
      $i++;
   }
   return -1;
}

sub positions {
   local($this,$elem,@array) = @_;
   $i = 0;
   @positions_in_list = ();
   foreach $a (@array) {
      push(@positions_in_list, $i) if $elem eq $a;
      $i++;
   }
   return @positions_in_list;
}

sub rand_n_digit_number {
   local($this,$n) = @_;

   return 0 unless $n =~ /^[1-9]\d*$/;
   $ten_power_n = 10 ** ($n - 1);
   return int(rand(9 * $ten_power_n)) + $ten_power_n;
}

# Consider File::Temp
sub new_tmp_filename {
   local($this,$filename) = @_;

   $loop_limit = 1000;
   ($dir,$simple_filename) = ($filename =~ /^(.+)\/([^\/]+)$/);
   $simple_filename = $filename unless defined($simple_filename);
   $new_filename = "$dir/tmp-" . $this->rand_n_digit_number(8) . "-$simple_filename";
   while ((-e $new_filename) && ($loop_limit-- >= 0)) {
      $new_filename = "$dir/tmp-" . $this->rand_n_digit_number(8) . "-$simple_filename";
   }
   return $new_filename;
}

# support sorting order: "8", "8.0", "8.5", "8.5.1.", "8.10", "10", "10-12"

sub compare_complex_numeric {
   local($this,$a,$b) = @_;

   (my $a_num,my $a_rest) = ($a =~ /^(\d+)\D*(.*)$/);
   (my $b_num,my $b_rest) = ($b =~ /^(\d+)\D*(.*)$/);

   if (defined($a_rest) && defined($b_rest)) {
      return ($a_num <=> $b_num)
	  || $this->compare_complex_numeric($a_rest,$b_rest);
   } else {
      return $a cmp $b;
   }
}

# support sorting order: "lesson8-ps-v1.9.xml", "Lesson 10_ps-v_1.11.xml"
# approach: segment strings into alphabetic and numerical sections and compare pairwise

sub compare_mixed_alpha_numeric {
   local($this,$a,$b) = @_;

   ($a_alpha,$a_num,$a_rest) = ($a =~ /^(\D*)(\d[-\d\.]*)(.*)$/);
   ($b_alpha,$b_num,$b_rest) = ($b =~ /^(\D*)(\d[-\d\.]*)(.*)$/);

   ($a_alpha) = ($a =~ /^(\D*)/) unless defined $a_alpha;
   ($b_alpha) = ($b =~ /^(\D*)/) unless defined $b_alpha;

   # ignore non-alphabetic characters in alpha sections
   $a_alpha =~ s/\W|_//g;
   $b_alpha =~ s/\W|_//g;

   if ($alpha_cmp = lc $a_alpha cmp lc $b_alpha) {
      return $alpha_cmp;
   } elsif (defined($a_rest) && defined($b_rest)) {
      return $this->compare_complex_numeric($a_num,$b_num)
	  || $this->compare_mixed_alpha_numeric ($a_rest,$b_rest);
   } else {
      return (defined($a_num) <=> defined($b_num)) || ($a cmp $b);
   }
}

# @sorted_lessons = sort { NLP::utilities->compare_mixed_alpha_numeric($a,$b) } @lessons;

sub html_guarded_p {
   local($this,$string) = @_;

   return 0 if $string =~ /[<>"]/;
   @segs = split('&',$string);
   shift @segs;
   foreach $seg (@segs) {
      next if $seg =~ /^amp;/;
      next if $seg =~ /^quot;/;
      next if $seg =~ /^nbsp;/;
      next if $seg =~ /^gt;/;
      next if $seg =~ /^lt;/;
      next if $seg =~ /^#(\d+);/;
      next if $seg =~ /^#x([0-9a-fA-F]+);/;
      return 0;
   }
   return 1;
}

sub guard_tooltip_text {
   local($this,$string) = @_;

   $string =~ s/\xCB\x88/'/g;
   return $string;
}

sub guard_html {
   local($this,$string,$control_string) = @_;

   return "" unless defined($string);
   my $guarded_string;
   $control_string = "" unless defined($control_string);
   return $string if ($string =~ /&/) 
		       && (! ($control_string =~ /\bstrict\b/))
		       && $this->html_guarded_p($string);
   $guarded_string = $string;
   $guarded_string =~ s/&/&amp;/g;
   if ($control_string =~ /slash quote/) {
      $guarded_string =~ s/"/\\"/g;
   } elsif ($control_string =~ /keep quote/) {
   } else {
      $guarded_string =~ s/\"/&quot;/g;
   }
   $guarded_string =~ s/>/&gt;/g;
   $guarded_string =~ s/</&lt;/g;
   return $guarded_string;
}

sub unguard_html {
   local($this,$string) = @_;

   return undef unless defined($string);
   $string=~ s[&(\S*?);]{
      local $_ = $1;
      /^amp$/i        ? "&" :
      /^quot$/i       ? '"' :
      /^apos$/i       ? "'" :
      /^gt$/i         ? ">" :
      /^lt$/i         ? "<" :
      /^nbsp$/i       ? "\xC2\xA0" :
      /^#(\d+)$/      ? $this->chr($1) :
      /^#x([0-9a-f]+)$/i ? $this->chr(hex($1)) :
      $_
      }gex;
   return $string;
}

sub unguard_html_r {
   local($this,$string) = @_;

   return undef unless defined($string);

   $string =~ s/&amp;/&/g;
   $string =~ s/&quot;/'/g;
   $string =~ s/&lt;/</g;
   $string =~ s/&gt;/>/g;

   ($d) = ($string =~ /&#(\d+);/);
   while (defined($d)) {
      $c = $this->chr($d);
      $string =~ s/&#$d;/$c/g;
      ($d) = ($string =~ /&#(\d+);/);
   }
   ($x) = ($string =~ /&#x([0-9a-f]+);/i);
   while (defined($x)) {
      $c = $this->chr(hex($x));
      $string =~ s/&#x$x;/$c/g;
      ($x) = ($string =~ /&#x([0-9a-f]+);/i);
   }
   $string0 = $string;
   ($x) = ($string =~ /(?:http|www|\.com)\S*\%([0-9a-f]{2,2})/i);
   while (defined($x)) {
      $c = $this->chr("%" . hex($x));
      $string =~ s/\%$x/$c/g;
      ($x) = ($string =~ /(?:http|www|\.com)\S*\%([0-9a-f]{2,2})/i);
   }
   return $string;
}

sub unguard_html_l {
   local($caller,$string) = @_;

   return undef unless defined($string);

   my $pre;
   my $core;
   my $post;
   my $repl;
   my $s = $string;
   if (($pre,$core,$post) = ($s =~ /^(.*)&(amp|quot|lt|gt|#\d+|#x[0-9a-f]+);(.*)$/i)) {
      $repl = "?";
      $repl = "&" if $core =~ /^amp$/i;
      $repl = "'" if $core =~ /^quot$/i;
      $repl = "<" if $core =~ /^lt$/i;
      $repl = ">" if $core =~ /^gt$/i;
      if ($core =~ /^#\d+$/i) {
	 $core2 = substr($core,1);
         $repl = $caller->chr($core2);
      }
      $repl = $caller->chr(hex(substr($core,2))) if $core =~ /^#x[0-9a-f]+$/i;
      $s = $pre . $repl . $post;
   }
   return $s;
}

sub guard_html_quote {
   local($caller,$string) = @_;

   $string =~ s/"/&quot;/g;
   return $string;
}

sub unguard_html_quote {
   local($caller,$string) = @_;

   $string =~ s/&quot;/"/g;
   return $string;
}

sub remove_xml_tags {
   local($caller,$string) = @_;

   $string =~ s/<\/?[a-zA-Z][-_:a-zA-Z0-9]*(\s+[a-zA-Z][-_:a-zA-Z0-9]*=\"[^"]*\")*\s*\/?>//g;
   return $string;
}

sub remove_any_tokenization_at_signs_around_xml_tags {
   local($caller,$string) = @_;

   $string =~ s/(?:\@ \@)?(<[^<>]+>)(?:\@ \@)?/$1/g;
   $string =~ s/\@?(<[^<>]+>)\@?/$1/g;
   return $string;
}

sub remove_xml_tags_and_any_bordering_at_signs {
   # at-signs from tokenization
   local($caller,$string) = @_;

   $string =~ s/\@?<\/?[a-zA-Z][-_:a-zA-Z0-9]*(\s+[a-zA-Z][-_:a-zA-Z0-9]*=\"[^"]*\")*\s*\/?>\@?//g;
   return $string;
}

sub chr {
   local($caller,$i) = @_;

   return undef unless $i =~ /^\%?\d+$/;
   if ($i =~ /^%/) {
      $i =~ s/^\%//;
      return chr($i)                                  if $i < 128;
      return "\x80" | chr($i - 128)                   if $i < 256;
   } else {
      return chr($i)                                  if $i < 128;
      return ("\xC0" | chr(($i / 64) % 32)) 
	   . ("\x80" | chr($i % 64))                  if $i < 2048;
      return ("\xE0" | chr(int($i / 4096) % 16)) 
	   . ("\x80" | chr(int($i / 64) % 64)) 
	   . ("\x80" | chr($i % 64))                  if $i < 65536;
      return ("\xF0" | chr(int($i / 262144) % 8)) 
	   . ("\x80" | chr(int($i / 4096) % 64)) 
	   . ("\x80" | chr(int($i / 64) % 64)) 
	   . ("\x80" | chr($i % 64))                  if $i < 2097152;
   }
   return "?";
}

sub guard_cgi {
   local($caller,$string) = @_;

   $guarded_string = $string;
   if ($string =~ /[\x80-\xFF]/) {
      $guarded_string = "";
      while ($string ne "") {
	 $char = substr($string, 0, 1);
         $string = substr($string, 1);
         if ($char =~ /^[\\ ;\#\&\:\=\"\'\+\?\x00-\x1F\x80-\xFF]$/) {
	    $hex = sprintf("%2.2x",ord($char));
	    $guarded_string .= "%$hex";
	 } else {
	    $guarded_string .= $char;
	 }
      }
   } else {
      $guarded_string = $string;
      $guarded_string =~ s/%/%25/g;
      $guarded_string =~ s/\n/%5Cn/g;
      $guarded_string =~ s/\t/%5Ct/g;
      $guarded_string =~ s/ /%20/g;
      $guarded_string =~ s/"/%22/g;
      $guarded_string =~ s/#/%23/g;
      $guarded_string =~ s/&/%26/g;
      $guarded_string =~ s/'/%27/g;
      $guarded_string =~ s/\+/%2B/g;
      $guarded_string =~ s/\//%2F/g;
      $guarded_string =~ s/:/%3A/g;
      $guarded_string =~ s/;/%3B/g;
      $guarded_string =~ s/</%3C/g;
      $guarded_string =~ s/=/%3D/g;
      $guarded_string =~ s/>/%3E/g;
      $guarded_string =~ s/\?/%3F/g;
   }
   return $guarded_string;
}

sub repair_cgi_guard {
   local($caller,$string) = @_;
   # undo second cgi-guard, e.g. "Jo%25C3%25ABlle_Aubron" -> "Jo%C3%ABlle_Aubron"

   $string =~ s/(%)25([CD][0-9A-F]%)25([89AB][0-9A-F])/$1$2$3/g;
   $string =~ s/(%)25(E[0-9A-F]%)25([89AB][0-9A-F]%)25([89AB][0-9A-F])/$1$2$3$4/g;
   return $string;
}

sub unguard_cgi {
   local($caller,$string) = @_;

   $unguarded_string = $string;
   $unguarded_string =~ s/%5Cn/\n/g;
   $unguarded_string =~ s/%5Ct/\t/g;
   $unguarded_string =~ s/%20/ /g;
   $unguarded_string =~ s/%23/#/g;
   $unguarded_string =~ s/%26/&/g;
   $unguarded_string =~ s/%2B/+/g;
   $unguarded_string =~ s/%2C/,/g;
   $unguarded_string =~ s/%3A/:/g;
   $unguarded_string =~ s/%3D/=/g;
   $unguarded_string =~ s/%3F/?/g;
   $unguarded_string =~ s/%C3%A9/\xC3\xA9/g;

   # more general
   ($code) = ($unguarded_string =~ /%([0-9A-F]{2,2})/);
   while (defined($code)) {
      $percent_code = "%" . $code;
      $hex_code = sprintf("%c", hex($code));
      $unguarded_string =~ s/$percent_code/$hex_code/g;
      ($code) = ($unguarded_string =~ /%([0-9A-F]{2,2})/);
   }
   # system("echo \"$string $unguarded_string\" >> /nfs/brahms1/ulf/www/.unguard_cgi.log")
   #    unless $string eq $unguarded_string;

   return $unguarded_string;
}

sub regex_guard {
   local($caller,$string) = @_;

   $guarded_string = $string;
   $guarded_string =~ s/([\\\/\^\|\(\)\{\}\$\@\*\+\?\.\[\]])/\\$1/g
      if $guarded_string =~ /[\\\/\^\|\(\)\{\}\$\@\*\+\?\.\[\]]/;

   return $guarded_string;
}

sub string_guard {
   local($caller,$string) = @_;

   return "" unless defined($string);
   $guarded_string = $string;
   $guarded_string =~ s/([\\"])/\\$1/g
      if $guarded_string =~ /[\\"]/;

   return $guarded_string;
}

sub guard_javascript_arg {
   local($caller,$string) = @_;

   return "" unless defined($string);
   $guarded_string = $string;
   $guarded_string =~ s/'/\\'/g;
   return $guarded_string;
}

sub guard_substitution_right_hand_side {
   # "$1x" => "$1 . \"x\""
   local($caller,$string) = @_;

   my $result = "";
   ($pre,$var,$post) = ($string =~ /^([^\$]*)(\$\d)(.*)$/);
   while (defined($var)) {
      $result .= " . " if $result;
      $result .= "\"$pre\" . " unless $pre eq "";
      $result .= $var;
      $string = $post;
      ($pre,$var,$post) = ($string =~ /^([^\$]*)(\$\d)(.*)$/);
   }
   $result .= " . \"$string\"" if $string;
   return $result;
}

sub string_starts_with_substring {
   local($caller,$string,$substring) = @_;

   $guarded_substring = $caller->regex_guard($substring);
   return $string =~ /^$guarded_substring/;
}

sub one_string_starts_with_the_other {
   local($caller,$s1,$s2) = @_;

   return ($s1 eq $s2)
       || $caller->string_starts_with_substring($s1,$s2)
       || $caller->string_starts_with_substring($s2,$s1);
}

sub string_ends_in_substring {
   local($caller,$string,$substring) = @_;

   $guarded_substring = $caller->regex_guard($substring);
   return $string =~ /$guarded_substring$/;
}

sub string_equal_ignore_leading_multiple_or_trailing_blanks {
   local($caller,$string1,$string2) = @_;

   return 1 if $string1 eq $string2;
   $string1 =~ s/\s+/ /;
   $string2 =~ s/\s+/ /;
   $string1 =~ s/^\s+//;
   $string2 =~ s/^\s+//;
   $string1 =~ s/\s+$//;
   $string2 =~ s/\s+$//;

   return $string1 eq $string2;
}

sub strip_substring_from_start_of_string {
   local($caller,$string,$substring,$error_code) = @_;

   $error_code = "ERROR" unless defined($error_code);
   my $reg_surf = $caller->regex_guard($substring);
   if ($string =~ /^$guarded_substring/) {
      $string =~ s/^$reg_surf//;
      return $string;
   } else {
      return $error_code;
   }
}

sub strip_substring_from_end_of_string {
   local($caller,$string,$substring,$error_code) = @_;

   $error_code = "ERROR" unless defined($error_code);
   my $reg_surf = $caller->regex_guard($substring);
   if ($string =~ /$reg_surf$/) {
      $string =~ s/$reg_surf$//;
      return $string;
   } else {
      return $error_code;
   }
}

# to be deprecated
sub lang_code {
   local($caller,$language) = @_;

   $langPM = NLP::Language->new();
   return $langPM->lang_code($language);
}

sub full_language {
   local($caller,$lang_code) = @_;

   return "Arabic"       if $lang_code eq "ar";
   return "Chinese"      if $lang_code eq "zh";
   return "Czech"        if $lang_code eq "cs";
   return "Danish"       if $lang_code eq "da";
   return "Dutch"        if $lang_code eq "nl";
   return "English"      if $lang_code eq "en";
   return "Finnish"      if $lang_code eq "fi";
   return "French"       if $lang_code eq "fr";
   return "German"       if $lang_code eq "de";
   return "Greek"        if $lang_code eq "el";
   return "Hebrew"       if $lang_code eq "he";
   return "Hindi"        if $lang_code eq "hi";
   return "Hungarian"    if $lang_code eq "hu";
   return "Icelandic"    if $lang_code eq "is";
   return "Indonesian"   if $lang_code eq "id";
   return "Italian"      if $lang_code eq "it";
   return "Japanese"     if $lang_code eq "ja";
   return "Kinyarwanda"  if $lang_code eq "rw";
   return "Korean"       if $lang_code eq "ko";
   return "Latin"        if $lang_code eq "la";
   return "Malagasy"     if $lang_code eq "mg";
   return "Norwegian"    if $lang_code eq "no";
   return "Pashto"       if $lang_code eq "ps";
   return "Persian"      if $lang_code eq "fa";
   return "Polish"       if $lang_code eq "pl";
   return "Portuguese"   if $lang_code eq "pt";
   return "Romanian"     if $lang_code eq "ro";
   return "Russian"      if $lang_code eq "ru";
   return "Spanish"      if $lang_code eq "es";
   return "Swedish"      if $lang_code eq "sv";
   return "Turkish"      if $lang_code eq "tr";
   return "Urdu"         if $lang_code eq "ur";
   return "";
}

# to be deprecated
sub short_lang_name {
   local($caller,$lang_code) = @_;

   $langPM = NLP::Language->new();
   return $langPM->shortname($lang_code);
}

sub ml_dir {
   local($caller,$language,$type) = @_;

   $type = "MSB" unless defined($type);
   $lang_code = $langPM->lang_code($language);
   return $caller->ml_dir($lang_code, "lex") . "/corpora" if $type eq "corpora";
   return "" unless defined($rc);
   $ml_home = $rc->ml_home_dir();
   return File::Spec->catfile($ml_home, "arabic")
      if ($lang_code eq "ar-iq") && ! $caller->member(lc $type,"lex","onto","dict");
   $langPM = NLP::Language->new();
   $lexdir = $langPM->lexdir($lang_code);
   return $lexdir if defined($lexdir);
   return "";
}

sub language_lex_filename {
   local($caller,$language,$type) = @_;

   $langPM = NLP::Language->new();
   if (($lang_code = $langPM->lang_code($language))
    && ($ml_dir = $caller->ml_dir($lang_code,$type))
    && ($norm_language = $caller->short_lang_name($lang_code))) {
      return "$ml_dir/$norm_language-lex" if ($type eq "lex");
      return "$ml_dir/onto" if ($type eq "onto");
      return "$ml_dir/$norm_language-english-dict" if ($type eq "dict") && !($lang_code eq "en");
      return "";
   } else {
      return "";
   }
}

# filename_without_path is obsolete - replace with
#   use File::Basename;
#   basename($filename)
sub filename_without_path {
   local($caller,$filename) = @_;

   $filename =~ s/^.*\/([^\/]+)$/$1/;
   return $filename;
}

sub option_string {
   local($caller,$input_name,$default,*values,*labels) = @_;

   my $s = "<select id=\"$input_name\" name=\"$input_name\" size=\"1\">";
   for $i (0 .. $#values) {
     my $value = $values[$i];
     my $label = $labels[$i];
     my $selected_clause = ($default eq $value) ? "selected" : "";
     $s .= "<option $selected_clause value=\"$value\">$label</option>";
   }
   $s .= "</select>";
   return $s;
}

sub pes_subseq_surf {
   local($this,$start,$length,$langCode,@pes) = @_;

   my $surf = "";
   if ($start+$length-1 <= $#pes) {
      foreach $i ($start .. $start + $length - 1) {
	 my $pe = $pes[$i];
	 $surf .= $pe->get("surf","");
	 $surf .= " " if $langCode =~ /^(ar|en|fr)$/;
      }
   }
   $surf =~ s/\s+$//;
   return $surf;
}

sub copyList {
   local($this,@list) = @_;

   @copy_list = ();
   foreach $elem (@list) {
      push(@copy_list,$elem);
   }
   return @copy_list;
}

sub list_with_same_elem {
   local($this,$size,$elem) = @_;

   @list = ();
   foreach $i (0 .. $size-1) {
      push(@list,$elem);
   }
   return @list;
}

sub count_occurrences {
   local($this,$s,$substring) = @_;

   $occ = 0;
   $new = $s;
   $guarded_substring = $this->regex_guard($substring);
   $new =~ s/$guarded_substring//;
   while ($new ne $s) {
      $occ++;
      $s = $new;
      $new =~ s/$guarded_substring//;
   }
   return $occ;
}

sub position_of_nth_occurrence {
   local($this,$s,$substring,$occ) = @_;

   return -1 unless $occ > 0;
   my $pos = 0;
   while (($pos = index($s, $substring, $pos)) >= 0) {
      return $pos if $occ == 1;
      $occ--;
      $pos = $pos + length($substring);
   }
   return -1;
}

sub has_diff_elements_p {
   local($this,@array) = @_;

   return 0 if $#array < 1;
   $elem = $array[0];

   foreach $a (@array) {
      return 1 if $elem ne $a;
   }
   return 0;
}

sub init_log {
   local($this,$logfile) = @_;
   if (DEBUGGING && $logfile) {
      system("rm -f $logfile");
      system("date > $logfile; chmod 777 $logfile");
   }
}

sub time_stamp_log {
   local($this,$logfile) = @_;
   if (DEBUGGING && $logfile) {
      system("date >> $logfile; chmod 777 $logfile");
   }
}

sub log {
   local($this,$message,$logfile) = @_;

   if (DEBUGGING && $logfile) {
      $guarded_message = $message;
      $guarded_message =~ s/"/\\"/g;
      system("echo \"$guarded_message\" >> $logfile");
   }
}

sub month_name_to_month_number {
   local($this,$month_name) = @_;

   $month_name_init = lc substr($month_name,0,3);
   return $this->position($month_name_init, "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec") + 1;
}

my @short_month_names = ("Jan.","Febr.","March","April","May","June","July","Aug.","Sept.","Oct.","Nov.","Dec.");
my @full_month_names = ("January","February","March","April","May","June","July","August","September","October","November","December");

sub month_number_to_month_name {
   local($this,$month_number, $control) = @_;

   $month_number =~ s/^0//;
   if ($month_number =~ /^([1-9]|1[0-2])$/) {
      return ($control && ($control =~ /short/i))
	 ? $short_month_names[$month_number-1]
	 : $full_month_names[$month_number-1];
   } else {
      return "";
   }
}

sub datetime {
   local($this,$format,$time_in_secs) = @_;

   $time_in_secs = time unless defined($time_in_secs);
   ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime($time_in_secs);
   $thisyear = $year + 1900;
   $thismon=(Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec)[$mon];
   $thismon2=("Jan.","Febr.","March","April","May","June","July","Aug.","Sept.","Oct.","Nov.","Dec.")[$mon];
   $thismonth = $mon + 1;
   $thisday=(Sun,Mon,Tue,Wed,Thu,Fri,Sat)[$wday];
   $date="$thisday $thismon $mday, $thisyear";
   $sdate="$thismon $mday, $thisyear";
   $dashedDate = sprintf("%04d-%02d-%02d",$thisyear,$thismonth,$mday);
   $slashedDate = sprintf("%02d/%02d/%04d",$mday,$thismonth,$thisyear);
   $time=sprintf("%02d:%02d:%02d",$hour,$min,$sec);
   $shorttime=sprintf("%d:%02d",$hour,$min);
   $shortdatetime = "$thismon2 $mday, $shorttime";

   if ($date =~ /undefined/) {
      return "";
   } elsif ($format eq "date at time") {
      return "$date at $time";
   } elsif ($format eq "date") {
      return "$date";
   } elsif ($format eq "sdate") {
      return "$sdate";
   } elsif ($format eq "ddate") {
      return "$dashedDate";
   } elsif ($format eq "time") {
      return "$time";
   } elsif ($format eq "dateTtime") {
      return $dashedDate . "T" . $time;
   } elsif ($format eq "short date at time") {
      return $shortdatetime;
   } else {
      return "$date at $time";
   }
}

sub add_1sec {
   local($this,$datetime) = @_;

   if (($year,$month,$day,$hour,$minute,$second) = ($datetime =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/)) {
      $second++;
      if ($second >= 60) { $second -= 60; $minute++; }
      if ($minute >= 60) { $minute -= 60; $hour++;   }
      if ($hour   >= 24) { $hour   -= 24; $day++;    }
      if ($month =~ /^(01|03|05|07|08|10|12)$/) {
         if ($day >  31) { $day    -= 31; $month++;  }
      } elsif ($month =~ /^(04|06|09|11)$/) {
         if ($day >  30) { $day    -= 30; $month++;  }
      } elsif (($month eq "02") && $this->leap_year($year)) {
         if ($day >  29) { $day    -= 29; $month++;  }
      } elsif ($month eq "02") {
         if ($day >  28) { $day    -= 28; $month++;  }
      }
      if ($month  >  12) { $month  -= 12; $year++;   }
      return sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $year,$month,$day,$hour,$minute,$second);
   } else {
      return "";
   }
}

sub leap_year {
   local($this,$year) = @_;

   return 0 if $year %   4 != 0;
   return 1 if $year % 400 == 0;
   return 0 if $year % 100 == 0;
   return 1;
}

sub print_html_banner {
   local($this,$text,$bgcolor,*OUT,$control) = @_;

   $control = "" unless defined($control);
   $bgcolor = "#BBCCFF" unless defined($bgcolor);
   print OUT "<table width=\"100%\" border=\"0\" cellpadding=\"3\" cellspacing=\"0\"><tr bgcolor=\"$bgcolor\"><td>";
   print OUT "&nbsp; " unless $text =~ /^\s*<(table|nobr)/;
   print OUT $text;
   print OUT "</td></tr></table>\n";
   print OUT "<br />\n" unless $control =~ /nobr/i;
}

sub print_html_head {
   local($this, $title, *OUT, $control, $onload_fc, $add_javascript) = @_;

   $control = "" unless defined($control);
   $onload_fc = "" unless defined($onload_fc);
   $onload_clause = ($onload_fc) ? " onload=\"$onload_fc\"" : "";
   $add_javascript = "" unless defined($add_javascript);
   $max_age_clause = "";
   $max_age_clause = "<meta http-equiv=\"cache-control\" content=\"max-age=3600\" \/>"; # if $control =~ /\bexp1hour\b/;
   $css_clause = "";
   $css_clause = "\n    <link rel=\"stylesheet\" type=\"text/css\" href=\"http://www.isi.edu/~ulf/css/handheld/default.css\" media=\"handheld\"\/>" if $control =~ /css/;
   $css_clause .= "\n    <link rel=\"stylesheet\" type=\"text/css\" href=\"http://www.isi.edu/~ulf/css/handheld/default.css\" media=\"only screen and (max-device-width:480px)\"\/>" if $control =~ /css/;
   $css_clause = "\n    <link rel=\"stylesheet\" type=\"text/css\" href=\"http://www.isi.edu/~ulf/css/handheld/default.css\">" if $control =~ /css-handheld/;
   $icon_clause = "";
   $icon_clause .= "\n   <link rel=\"shortcut icon\" href=\"http://www.isi.edu/~ulf/amr/images/AMR-favicon.ico\">" if $control =~ /\bAMR\b/i;
   print OUT "\xEF\xBB\xBF\n"; # utf8 marker
   print OUT<<END_OF_HEADER1;
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    $max_age_clause
    <title>$title</title>$css_clause$icon_clause
END_OF_HEADER1
;

   unless ($control =~ /no javascript/) {
   print OUT<<END_OF_HEADER2;
    <script type="text/javascript">
    <!--
    function toggle(id) {
       if ((s = document.getElementById(id)) != null) {
          if (s.style.display == 'none') {
             s.style.display = 'inline';
          } else {
             s.style.display = 'none';
          }
       }
    }

    function toggle_group(group_id, url, new_search_help_id) {
       if (((s = document.getElementById('new_search_on_next_click_p')) == null) || (s.value == 0)) {          
          i = 1;         
          id = group_id + '_' + i;
          while ((s = document.getElementById(id)) != null) {
             if (s.style.display == 'none') {
                s.style.display = 'inline';
             } else {
                s.style.display = 'none';
             }
             i = i + 1;
             id = group_id + '_' + i;
          }
       }

       if ((s = document.getElementById('new_search_on_next_click_p')) != null) {
          new_search_value = s.value;
          s.value = 0;
          if ((new_search_help_id != 0) && ((s2 = document.getElementById(new_search_help_id)) != null)) {
             s2.style.display = 'none';
          }
          if ((new_search_value == 1) && (url != 0)) {
             popUpBottom(url,750,400);
          }
       }
    }

    function set_group_display(group_id, value) {
       i = 1;         
       id = group_id + '_' + i;
       while ((s = document.getElementById(id)) != null) {
          s.style.display = value;
          i = i + 1;
          id = group_id + '_' + i;
       }
    }

    function popUpBottom(URL,width,height) {
       day = new Date();
       id = day.getTime();
       eval("myWindow = window.open(URL, '" + id + "', 'toolbar=0,scrollbars=1,location=0,statusbar=0,menubar=0,resizable=1,width=" + width + ",height=" + height + "');");
    }

    function popUpWarning(warning) {
       newwindow=window.open('','Warning','height=160,width=400,resizable=1,scrollbars=1,toolbar=0,statusbar=0,menubar=0');
       var tmp = newwindow.document;
       tmp.write('<html>\\n');
       tmp.write('  <head><title>AMR Editor Warning</title></head>\\n');
       tmp.write('  <body' + ' style="background-color:#FFFFEE;">\\n');
       tmp.write('    <h3>Warning</h3>\\n');
       tmp.write('    ' + warning + '\\n');
       tmp.write('    <p>\\n');
       tmp.write('    <input type=\"submit\" title=\"Close this window.\" value=\"OK\" onclick=\"self.close();\">\\n');
       tmp.write('  </body>\\n');
       tmp.write('</html>\\n');
       tmp.close();
    }

    function new_search_on_next_click(new_search_help_id) {
       if ((s = document.getElementById(new_search_help_id)) != null) {
          s.style.display = 'inline';
       }
       if ((s = document.getElementById('new_search_on_next_click_p')) != null) {
          s.value = 1;
       }
    }

    function set(id, value) {
       if ((s = document.getElementById(id)) != null) {
	  s.value = value;
       }
    }

    function set_group_pairwise(snt_id, odd_value, even_value) {
       gi = 0;
       group_id = snt_id + '_' + gi;
       i = 1;
       id = group_id + '_' + i;
       while (((s = document.getElementById(id)) != null) || (gi == 0)) {
          while ((s = document.getElementById(id)) != null) {
	     s.style.display = odd_value;
             i = i + 1;
	     id = group_id + '_' + i;
	     if ((s = document.getElementById(id)) != null) {
	        s.style.display = even_value;
	     }
             i = i + 1;
	     id = group_id + '_' + i;
          }
          gi = gi + 1;
          group_id = snt_id + '_' + gi;
          i = 1;
          id = group_id + '_' + i;
       }
    }

    function clear(id) {
       if (s = document.getElementById(id)) {
          s.value = '';
       }
    }

    function goto_page_loc(hash, id, y) {
       var s ;
       var page_dynamically_created_p = 0;
       if (page_dynamically_created_p) {
          if ((s = document.getElementById(id)) != null) {
             s.checked = "true";
             s.focus();
             if (document.body.scrollTop > 0) {
               document.body.scrollTop += y;
             } else {
               // document.body.scrollTop = document.body.scrollHeight;
               // s.focus();
             }
          } 
       } else {
          window.location.hash = hash;
          if ((s = document.getElementById(id)) != null) {
             s.checked = "true";
          }
       }
    }

    function redirect(url) {
       window.location = url;
    }

    $add_javascript
    -->
    </script>
END_OF_HEADER2
;
   }

   print OUT<<END_OF_HEADER3;
  </head>
  <body bgcolor="#FFFFEE"$onload_clause>
END_OF_HEADER3
;
}

sub print_html_foot {
   local($this, *OUT) = @_;

   print OUT "   </body>\n";
   print OUT "</html>\n";
}

sub http_catfile {
   local($this, @path) = @_;

   $result = File::Spec->catfile(@path);
   $result =~ s/http:\/([a-zA-Z])/http:\/\/$1/;
   return $result;
}

sub underscore_to_space {
   local($this, $s) = @_;

   return "" unless defined($s);

   $s =~ s/_+/ /g;
   return $s;
}

sub space_to_underscore {
   local($this, $s) = @_;

   return "" unless defined($s);

   $s =~ s/ /_/g;
   return $s;
}

sub remove_spaces {
   local($this, $s) = @_;

   $s =~ s/\s//g;
   return $s;
}

sub is_punctuation_string_p {
   local($this, $s) = @_;

   return "" unless $s;
   $s = $this->normalize_string($s) if $s =~ /[\x80-\xBF]/;
   return $s =~ /^[-_,;:.?!\/\@+*"()]+$/;
}

sub is_rare_punctuation_string_p {
   local($this, $s) = @_;

   return 0 unless $s =~ /^[\x21-\x2F\x3A\x40\x5B-\x60\x7B-\x7E]{2,}$/;
   return 0 if $s =~ /^(\.{2,3}|-{2,3}|\*{2,3}|::|\@?[-\/:]\@?)$/;
   return 1;
}

sub simplify_punctuation {
   local($this, $s) = @_;

   $s =~ s/\xE2\x80\x92/-/g;
   $s =~ s/\xE2\x80\x93/-/g;
   $s =~ s/\xE2\x80\x94/-/g;
   $s =~ s/\xE2\x80\x95/-/g;
   $s =~ s/\xE2\x80\x98/`/g;
   $s =~ s/\xE2\x80\x99/'/g;
   $s =~ s/\xE2\x80\x9A/`/g;
   $s =~ s/\xE2\x80\x9C/"/g;
   $s =~ s/\xE2\x80\x9D/"/g;
   $s =~ s/\xE2\x80\x9E/"/g;
   $s =~ s/\xE2\x80\x9F/"/g;
   $s =~ s/\xE2\x80\xA2/*/g;
   $s =~ s/\xE2\x80\xA4/./g;
   $s =~ s/\xE2\x80\xA5/../g;
   $s =~ s/\xE2\x80\xA6/.../g;
   return $s;
}

sub latin_plus_p {
   local($this, $s, $control) = @_;

   $control = "" unless defined($control);
   return $s =~ /^([\x20-\x7E]|\xC2[\xA1-\xBF]|\xC3[\x80-\xBF]|\xE2\x82[\xA0-\xB5])+$/;
}

sub nth_line_in_file {
   local($this, $filename, $n) = @_;

   return "" unless $n =~ /^[1-9]\d*$/;
   open(IN, $filename) || return "";
   my $line_no = 0;
   while (<IN>) {
      $line_no++;
      if ($n == $line_no) {
	 $_ =~ s/\s+$//;
         close(IN);
	 return $_;
      }
   }
   close(IN);
   return "";
}

sub read_file {
   local($this, $filename) = @_;

   my $file_content = "";
   open(IN, $filename) || return "";
   while (<IN>) {
      $file_content .= $_;
   }
   close(IN);
   return $file_content;
}

sub cap_list {
   local($this, @list) = @_;

   @cap_list = ();
   foreach $l (@list) {
      ($premod, $core) = ($l =~ /^(a|an) (\S.*)$/);
      if (defined($premod) && defined($core)) {
         push(@cap_list, "$premod \u$core");
      } elsif ($this->cap_member($l, "US")) {
	 push(@cap_list, uc $l);
      } else {
         push(@cap_list, "\u$l");
      }
   }
   return @cap_list;
}

sub integer_list_with_commas_and_ranges {
   local($this, @list) = @_;

   my $in_range_p = 0;
   my $last_value = 0;
   my $result = "";
   while (@list) {
      $elem = shift @list;
      if ($elem =~ /^\d+$/) {
         if ($in_range_p) {
	    if ($elem == $last_value + 1) {
	       $last_value = $elem;
	    } else {
	       $result .= "-$last_value, $elem";
	       if (@list && ($next = $list[0]) && ($elem =~ /^\d+$/) && ($next =~ /^\d+$/)
			 && ($next == $elem + 1)) {
		  $last_value = $elem;
		  $in_range_p = 1;
	       } else {
		  $in_range_p = 0;
	       }
	    }
         } else {
	    $result .= ", $elem";
	    if (@list && ($next = $list[0]) && ($elem =~ /^\d+$/) && ($next =~ /^\d+$/)
		      && ($next == $elem + 1)) {
	       $last_value = $elem;
	       $in_range_p = 1;
	    }
	 }
      } else {
	 if ($in_range_p) {
	    $result .= "-$last_value, $elem";
	    $in_range_p = 0;
	 } else {
	    $result .= ", $elem";
	 }
      }
   }
   if ($in_range_p) {
      $result .= "-$last_value";
   }
   $result =~ s/^,\s*//;
   return $result;
}

sub comma_append {
   local($this, $a, $b) = @_;

   if (defined($a) && ($a =~ /\S/)) {
      if (defined($b) && ($b =~ /\S/)) {
	 return "$a,$b";
      } else {
	 return $a;
      }
   } else {
      if (defined($b) && ($b =~ /\S/)) {
	 return $b;
      } else {
	 return "";
      }
   }
}

sub version {
   return "3.17";
}

sub print_stderr {
   local($this, $message, $verbose) = @_;

   $verbose = 1 unless defined($verbose);
   print STDERR $message if $verbose;
   return 1;
}

sub compare_alignment {
   local($this, $a, $b, $delimiter) = @_;

   $delimiter = "-" unless $delimiter;
   my @a_list = split($delimiter, $a);
   my @b_list = split($delimiter, $b);

   while (@a_list && @b_list) {
      $a_head = shift @a_list;
      $b_head = shift @b_list;
      next if $a_head eq $b_head;
      return $a_head <=> $b_head if ($a_head =~ /^\d+$/) && ($b_head =~ /^\d+$/);
      return $a_head cmp $b_head;
   }
   return -1 if @a_list;
   return 1 if @b_list;
   return 0;
}

sub normalize_string {
   # normalize punctuation, full-width characters (to ASCII)
   local($this, $s, $control) = @_;

   $control = "" unless defined($control);

   $norm_s = $s;
   $norm_s =~ tr/A-Z/a-z/;

   $norm_s =~ s/ \@([-:\/])/ $1/g; # non-initial left  @
   $norm_s =~ s/^\@([-:\/])/$1/;   #     initial left  @
   $norm_s =~ s/([-:\/])\@ /$1 /g; # non-initial right @
   $norm_s =~ s/([-:\/])\@$/$1/;   #     initial right @
   $norm_s =~ s/([\(\)"])([,;.?!])/$1 $2/g;
   $norm_s =~ s/\bcannot\b/can not/g;

   $norm_s =~ s/\xC2\xAD/-/g; # soft hyphen

   $norm_s =~ s/\xE2\x80\x94/-/g; # em dash
   $norm_s =~ s/\xE2\x80\x95/-/g; # horizontal bar
   $norm_s =~ s/\xE2\x80\x98/`/g; # grave accent
   $norm_s =~ s/\xE2\x80\x99/'/g; # apostrophe
   $norm_s =~ s/\xE2\x80\x9C/"/g; # left double quote mark
   $norm_s =~ s/\xE2\x80\x9D/"/g; # right double quote mark
   $norm_s =~ s/\xE2\x94\x80/-/g; # box drawings light horizontal
   $norm_s =~ s/\xE2\x94\x81/-/g; # box drawings heavy horizontal
   $norm_s =~ s/\xE3\x80\x81/,/g; # ideographic comma
   $norm_s =~ s/\xE3\x80\x82/./g; # ideographic full stop
   $norm_s =~ s/\xE3\x80\x88/"/g; # left angle bracket
   $norm_s =~ s/\xE3\x80\x89/"/g; # right angle bracket
   $norm_s =~ s/\xE3\x80\x8A/"/g; # left double angle bracket
   $norm_s =~ s/\xE3\x80\x8B/"/g; # right double angle bracket
   $norm_s =~ s/\xE3\x80\x8C/"/g; # left corner bracket
   $norm_s =~ s/\xE3\x80\x8D/"/g; # right corner bracket
   $norm_s =~ s/\xE3\x80\x8E/"/g; # left white corner bracket
   $norm_s =~ s/\xE3\x80\x8F/"/g; # right white corner bracket
   $norm_s =~ s/\xE3\x83\xBB/\xC2\xB7/g; # katakana middle dot -> middle dot
   $norm_s =~ s/\xEF\xBB\xBF//g; # UTF8 marker

   if ($control =~ /\bzh\b/i) {
      # de-tokenize Chinese
      unless ($control =~ /\bpreserve-tok\b/) {
         while ($norm_s =~ /[\xE0-\xEF][\x80-\xBF][\x80-\xBF] [\xE0-\xEF][\x80-\xBF][\x80-\xBF]/) {
            $norm_s =~ s/([\xE0-\xEF][\x80-\xBF][\x80-\xBF]) ([\xE0-\xEF][\x80-\xBF][\x80-\xBF])/$1$2/g;
         }
         $norm_s =~ s/([\xE0-\xEF][\x80-\xBF][\x80-\xBF]) ([\x21-\x7E])/$1$2/g;
         $norm_s =~ s/([\x21-\x7E]) ([\xE0-\xEF][\x80-\xBF][\x80-\xBF])/$1$2/g;
      }

      # fullwidth characters
      while ($norm_s =~ /\xEF\xBC[\x81-\xBF]/) {
         ($pre,$fullwidth,$post) = ($norm_s =~ /^(.*)(\xEF\xBC[\x81-\xBF])(.*)$/);
         $fullwidth =~ s/^\xEF\xBC//;
         $fullwidth =~ tr/[\x81-\xBF]/[\x21-\x5F]/;
         $norm_s = "$pre$fullwidth$post";
      }
      while ($norm_s =~ /\xEF\xBD[\x80-\x9E]/) {
         ($pre,$fullwidth,$post) = ($norm_s =~ /^(.*)(\xEF\xBD[\x80-\x9E])(.*)$/);
         $fullwidth =~ s/^\xEF\xBD//;
         $fullwidth =~ tr/[\x80-\x9E]/[\x60-\x7E]/;
         $norm_s = "$pre$fullwidth$post";
      }
      $norm_s =~ tr/A-Z/a-z/ unless $control =~ /\bpreserve-case\b/;

      unless ($control =~ /\bpreserve-tok\b/) {
         while ($norm_s =~ /[\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E] [\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]/) {
            $norm_s =~ s/([\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]) ([\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E])/$1$2/g;
         }
         $norm_s =~ s/([\x21-\x7E]) ([\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E])/$1$2/g;
         $norm_s =~ s/([\x21-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]) ([\x21-\x7E])/$1$2/g;
         $norm_s =~ s/ (\xC2\xA9|\xC2\xB7|\xC3\x97) /$1/g; # copyright sign, middle dot, multiplication sign
      }
   }

   if (($control =~ /\bzh\b/i) && ($control =~ /\bnorm-char\b/)) {
       $norm_s =~ s/\xE6\x96\xBC/\xE4\xBA\x8E/g; # feng1 (first char. of Chin. "lie low", line 1308)
       $norm_s =~ s/\xE6\xAD\xA7/\xE5\xB2\x90/g; # qi2 (second char. of Chin. "difference", line 1623)
       $norm_s =~ s/\xE8\x82\xB2/\xE6\xAF\x93/g; # yu4 (second char. of Chin. "sports", line 440)
       $norm_s =~ s/\xE8\x91\x97/\xE7\x9D\x80/g; # zhao (second char. of Chin. "prominent", line 4)
       $norm_s =~ s/\xE9\x81\x87/\xE8\xBF\x82/g; # yu4 (second char. of Chin. "good luck", line 959)
   }

   if ($control =~ /\bspurious-punct\b/) {
      $norm_s =~ s/^\s*[-_\." ]+//;
      $norm_s =~ s/[-_\." ]+\s*$//;
      $norm_s =~ s/\(\s+end\s+\)\s*$//i;
      $norm_s =~ s/^\s*null\s*$//i;
   }

   $norm_s =~ s/^\s+//;
   $norm_s =~ s/\s+$//;
   $norm_s =~ s/\s+/ /g;

   return $norm_s;
}

sub normalize_extreme_string {
   local($this, $s, $control) = @_;

   $control = "" unless defined($control);

   $norm_s = $s;
   $norm_s =~ s/\xE2\xA9\xBE/\xE2\x89\xA5/g; # slanted greater than or equal to

   return $norm_s;
}

sub increase_ht_count {
   local($this, *ht, $incr, @path) = @_;

   if ($#path == 0) {
      $ht{($path[0])} = ($ht{($path[0])} || 0) + $incr;
   } elsif ($#path == 1) {
         $ht{($path[0])}->{($path[1])}
      = ($ht{($path[0])}->{($path[1])} || 0) + $incr;
   } elsif ($#path == 2) {
         $ht{($path[0])}->{($path[1])}->{($path[2])} 
      = ($ht{($path[0])}->{($path[1])}->{($path[2])} || 0) + $incr;
   } elsif ($#path == 3) {
         $ht{($path[0])}->{($path[1])}->{($path[2])}->{($path[3])} 
      = ($ht{($path[0])}->{($path[1])}->{($path[2])}->{($path[3])} || 0) + $incr;
   } elsif ($#path == 4) {
         $ht{($path[0])}->{($path[1])}->{($path[2])}->{($path[3])}->{($path[4])}
      = ($ht{($path[0])}->{($path[1])}->{($path[2])}->{($path[3])}->{($path[4])} || 0) + $incr;
   } else {
      print STDERR "increase_ht_count unsupported for path of length " . ($#path + 1) . "\n";
   }
}

sub adjust_numbers {
   # non-negative integers
   local($this, $s, $delta) = @_;

   $result = "";
   while ($s =~ /\d/) {
      ($pre,$i,$post) = ($s =~ /^([^0-9]*)(\d+)([^0-9].*|)$/);
      $result .= $pre . ($i + $delta);
      $s = $post;
   }
   $result .= $s;
   return $result;
}

sub first_defined {
   local($this, @list) = @_;

   foreach $elem (@list) {
      return $elem if defined($elem);
   }
   return "";
}

sub first_defined_non_empty {
   local($this, @list) = @_;

   foreach $item (@list) {
      return $item if defined($item) && ($item ne "");
   }
   return "";
}

sub elem_after_member_list {
   local($this,$elem,@array) = @_;

   my @elem_after_member_list = ();
   foreach $i ((0 .. ($#array - 1))) {
      push(@elem_after_member_list, $array[$i+1]) if $elem eq $array[$i];
   }
   return join(" ", @elem_after_member_list);
}

sub add_value_to_list {
   local($this,$s,$value,$sep) = @_;

   $s = "" unless defined($s);
   $sep = "," unless defined($sep);
   return ($s =~ /\S/) ? "$s$sep$value" : $value;
}

sub add_new_value_to_list {
   local($this,$s,$value,$sep) = @_;

   $s = "" unless defined($s);
   $sep = "," unless defined($sep);
   my @values = split(/$sep/, $s);
   push(@values, $value) if defined($value) && ! $this->member($value, @values);

   return join($sep, @values);
}

sub add_new_hash_value_to_list {
   local($this,*ht,$key,$value,$sep) = @_;

   $sep = "," unless defined($sep);
   my $value_s = $ht{$key};
   if (defined($value_s)) {
      my @values = split(/$sep/, $value_s);
      push(@values, $value) unless $this->member($value, @values);
      $ht{$key} = join($sep, @values);
   } else {
      $ht{$key} = $value;
   }
}

sub ip_info {
   local($this, $ip_address) = @_;
    
   my %ip_map = ();
   $ip_map{"128.9.208.69"}  = "Ulf Hermjakob (bach.isi.edu)";
   $ip_map{"128.9.208.169"} = "Ulf Hermjakob (brahms.isi.edu)";
   $ip_map{"128.9.184.148"} = "Ulf Hermjakob (beethoven.isi.edu ?)";
   $ip_map{"128.9.184.162"} = "Ulf Hermjakob (beethoven.isi.edu)";
   $ip_map{"128.9.176.39"}  = "Kevin Knight";
   $ip_map{"128.9.184.187"} = "Kevin Knight";
   $ip_map{"128.9.216.56"}  = "Kevin Knight";
   $ip_map{"128.9.208.155"} = "cage.isi.edu";

   return ($ip_name = $ip_map{$ip_address}) ? "$ip_address - $ip_name" : $ip_address;
}

# from standalone de-accent.pl
sub de_accent_string {
   local($this, $s) = @_;

   $s =~ tr/A-Z/a-z/;
   unless (0) {
      # Latin-1
      if ($s =~ /\xC3[\x80-\xBF]/) {
         $s =~ s/(À|Á|Â|Ã|Ä|Å)/A/g;
         $s =~ s/Æ/Ae/g;
         $s =~ s/Ç/C/g;
         $s =~ s/Ð/D/g;
         $s =~ s/(È|É|Ê|Ë)/E/g;
         $s =~ s/(Ì|Í|Î|Ï)/I/g;
         $s =~ s/Ñ/N/g;
         $s =~ s/(Ò|Ó|Ô|Õ|Ö|Ø)/O/g;
         $s =~ s/(Ù|Ú|Û|Ü)/U/g;
         $s =~ s/Þ/Th/g;
         $s =~ s/Ý/Y/g;
         $s =~ s/(à|á|â|ã|ä|å)/a/g;
         $s =~ s/æ/ae/g;
         $s =~ s/ç/c/g;
         $s =~ s/(è|é|ê|ë)/e/g;
         $s =~ s/(ì|í|î|ï)/i/g;
         $s =~ s/ð/d/g;
         $s =~ s/ñ/n/g;
         $s =~ s/(ò|ó|ô|õ|ö)/o/g;
         $s =~ s/ß/ss/g;
         $s =~ s/þ/th/g;
         $s =~ s/(ù|ú|û|ü)/u/g;
         $s =~ s/(ý|ÿ)/y/g;
      }
      # Latin Extended-A
      if ($s =~ /[\xC4-\xC5][\x80-\xBF]/) {
         $s =~ s/(Ā|Ă|Ą)/A/g;
         $s =~ s/(ā|ă|ą)/a/g;
         $s =~ s/(Ć|Ĉ|Ċ|Č)/C/g;
         $s =~ s/(ć|ĉ|ċ|č)/c/g;
         $s =~ s/(Ď|Đ)/D/g;
         $s =~ s/(ď|đ)/d/g;
         $s =~ s/(Ē|Ĕ|Ė|Ę|Ě)/E/g;
         $s =~ s/(ē|ĕ|ė|ę|ě)/e/g;
         $s =~ s/(Ĝ|Ğ|Ġ|Ģ)/G/g;
         $s =~ s/(ĝ|ğ|ġ|ģ)/g/g;
         $s =~ s/(Ĥ|Ħ)/H/g;
         $s =~ s/(ĥ|ħ)/h/g;
         $s =~ s/(Ĩ|Ī|Ĭ|Į|İ)/I/g;
         $s =~ s/(ĩ|ī|ĭ|į|ı)/i/g;
         $s =~ s/Ĳ/Ij/g;
         $s =~ s/ĳ/ij/g;
         $s =~ s/Ĵ/J/g;
         $s =~ s/ĵ/j/g;
         $s =~ s/Ķ/K/g;
         $s =~ s/(ķ|ĸ)/k/g;
         $s =~ s/(Ĺ|Ļ|Ľ|Ŀ|Ł)/L/g;
         $s =~ s/(ļ|ľ|ŀ|ł)/l/g;
         $s =~ s/(Ń|Ņ|Ň|Ŋ)/N/g;
         $s =~ s/(ń|ņ|ň|ŉ|ŋ)/n/g;
         $s =~ s/(Ō|Ŏ|Ő)/O/g;
         $s =~ s/(ō|ŏ|ő)/o/g;
         $s =~ s/Œ/Oe/g;
         $s =~ s/œ/oe/g;
         $s =~ s/(Ŕ|Ŗ|Ř)/R/g;
         $s =~ s/(ŕ|ŗ|ř)/r/g;
         $s =~ s/(Ś|Ŝ|Ş|Š)/S/g;
         $s =~ s/(ś|ŝ|ş|š|ſ)/s/g;
         $s =~ s/(Ţ|Ť|Ŧ)/T/g;
         $s =~ s/(ţ|ť|ŧ)/t/g;
         $s =~ s/(Ũ|Ū|Ŭ|Ů|Ű|Ų)/U/g;
         $s =~ s/(ũ|ū|ŭ|ů|ű|ų)/u/g;
         $s =~ s/Ŵ/W/g;
         $s =~ s/ŵ/w/g;
         $s =~ s/(Ŷ|Ÿ)/Y/g;
         $s =~ s/ŷ/y/g;
         $s =~ s/(Ź|Ż|Ž)/Z/g;
         $s =~ s/(ź|ż|ž)/z/g;
      }
      # Latin Extended-B
      if ($s =~ /[\xC7-\xC7][\x80-\xBF]/) {
	 $s =~ s/(\xC7\x8D)/A/g;
	 $s =~ s/(\xC7\x8E)/a/g;
	 $s =~ s/(\xC7\x8F)/I/g;
	 $s =~ s/(\xC7\x90)/i/g;
	 $s =~ s/(\xC7\x91)/O/g;
	 $s =~ s/(\xC7\x92)/o/g;
	 $s =~ s/(\xC7\x93)/U/g;
	 $s =~ s/(\xC7\x94)/u/g;
	 $s =~ s/(\xC7\x95)/U/g;
	 $s =~ s/(\xC7\x96)/u/g;
	 $s =~ s/(\xC7\x97)/U/g;
	 $s =~ s/(\xC7\x98)/u/g;
	 $s =~ s/(\xC7\x99)/U/g;
	 $s =~ s/(\xC7\x9A)/u/g;
	 $s =~ s/(\xC7\x9B)/U/g;
	 $s =~ s/(\xC7\x9C)/u/g;
      }
      # Latin Extended Additional
      if ($s =~ /\xE1[\xB8-\xBF][\x80-\xBF]/) {
          $s =~ s/(ḁ|ạ|ả|ấ|ầ|ẩ|ẫ|ậ|ắ|ằ|ẳ|ẵ|ặ|ẚ)/a/g;
          $s =~ s/(ḃ|ḅ|ḇ)/b/g;
          $s =~ s/(ḉ)/c/g;
          $s =~ s/(ḋ|ḍ|ḏ|ḑ|ḓ)/d/g;
          $s =~ s/(ḕ|ḗ|ḙ|ḛ|ḝ|ẹ|ẻ|ẽ|ế|ề|ể|ễ|ệ)/e/g;
          $s =~ s/(ḟ)/f/g;
          $s =~ s/(ḡ)/g/g;
          $s =~ s/(ḣ|ḥ|ḧ|ḩ|ḫ)/h/g;
          $s =~ s/(ḭ|ḯ|ỉ|ị)/i/g;
          $s =~ s/(ḱ|ḳ|ḵ)/k/g;
          $s =~ s/(ḷ|ḹ|ḻ|ḽ)/l/g;
          $s =~ s/(ḿ|ṁ|ṃ)/m/g;
          $s =~ s/(ṅ|ṇ|ṉ|ṋ)/m/g;
          $s =~ s/(ọ|ỏ|ố|ồ|ổ|ỗ|ộ|ớ|ờ|ở|ỡ|ợ|ṍ|ṏ|ṑ|ṓ)/o/g;
          $s =~ s/(ṕ|ṗ)/p/g;
          $s =~ s/(ṙ|ṛ|ṝ|ṟ)/r/g;
          $s =~ s/(ṡ|ṣ|ṥ|ṧ|ṩ|ẛ)/s/g;
          $s =~ s/(ṫ|ṭ|ṯ|ṱ)/t/g;
          $s =~ s/(ṳ|ṵ|ṷ|ṹ|ṻ|ụ|ủ|ứ|ừ|ử|ữ|ự)/u/g;
          $s =~ s/(ṽ|ṿ)/v/g;
          $s =~ s/(ẁ|ẃ|ẅ|ẇ|ẉ|ẘ)/w/g;
          $s =~ s/(ẋ|ẍ)/x/g;
          $s =~ s/(ẏ|ỳ|ỵ|ỷ|ỹ|ẙ)/y/g;
          $s =~ s/(ẑ|ẓ|ẕ)/z/g;
          $s =~ s/(Ḁ|Ạ|Ả|Ấ|Ầ|Ẩ|Ẫ|Ậ|Ắ|Ằ|Ẳ|Ẵ|Ặ)/A/g;
          $s =~ s/(Ḃ|Ḅ|Ḇ)/B/g;
          $s =~ s/(Ḉ)/C/g;
          $s =~ s/(Ḋ|Ḍ|Ḏ|Ḑ|Ḓ)/D/g;
          $s =~ s/(Ḕ|Ḗ|Ḙ|Ḛ|Ḝ|Ẹ|Ẻ|Ẽ|Ế|Ề|Ể|Ễ|Ệ)/E/g;
          $s =~ s/(Ḟ)/F/g;
          $s =~ s/(Ḡ)/G/g;
          $s =~ s/(Ḣ|Ḥ|Ḧ|Ḩ|Ḫ)/H/g;
          $s =~ s/(Ḭ|Ḯ|Ỉ|Ị)/I/g;
          $s =~ s/(Ḱ|Ḳ|Ḵ)/K/g;
          $s =~ s/(Ḷ|Ḹ|Ḻ|Ḽ)/L/g;
          $s =~ s/(Ḿ|Ṁ|Ṃ)/M/g;
          $s =~ s/(Ṅ|Ṇ|Ṉ|Ṋ)/N/g;
          $s =~ s/(Ṍ|Ṏ|Ṑ|Ṓ|Ọ|Ỏ|Ố|Ồ|Ổ|Ỗ|Ộ|Ớ|Ờ|Ở|Ỡ|Ợ)/O/g;
          $s =~ s/(Ṕ|Ṗ)/P/g;
          $s =~ s/(Ṙ|Ṛ|Ṝ|Ṟ)/R/g;
          $s =~ s/(Ṡ|Ṣ|Ṥ|Ṧ|Ṩ)/S/g;
          $s =~ s/(Ṫ|Ṭ|Ṯ|Ṱ)/T/g;
          $s =~ s/(Ṳ|Ṵ|Ṷ|Ṹ|Ṻ|Ụ|Ủ|Ứ|Ừ|Ử|Ữ|Ự)/U/g;
          $s =~ s/(Ṽ|Ṿ)/V/g;
          $s =~ s/(Ẁ|Ẃ|Ẅ|Ẇ|Ẉ)/W/g;
          $s =~ s/(Ẍ)/X/g;
          $s =~ s/(Ẏ|Ỳ|Ỵ|Ỷ|Ỹ)/Y/g; 
          $s =~ s/(Ẑ|Ẓ|Ẕ)/Z/g;
      }
      # Greek letters
      if ($s =~ /\xCE[\x86-\xAB]/) {
          $s =~ s/ά/α/g;
          $s =~ s/έ/ε/g;
          $s =~ s/ί/ι/g;
          $s =~ s/ϊ/ι/g;
          $s =~ s/ΐ/ι/g;
          $s =~ s/ό/ο/g;
          $s =~ s/ύ/υ/g;
          $s =~ s/ϋ/υ/g;
          $s =~ s/ΰ/υ/g;
          $s =~ s/ώ/ω/g;
          $s =~ s/Ά/Α/g;
          $s =~ s/Έ/Ε/g;
          $s =~ s/Ή/Η/g;
          $s =~ s/Ί/Ι/g;
          $s =~ s/Ϊ/Ι/g;
          $s =~ s/Ύ/Υ/g;
          $s =~ s/Ϋ/Υ/g;
          $s =~ s/Ώ/Ω/g;
      }
      # Cyrillic letters
      if ($s =~ /\xD0[\x80-\xAF]/) {
          $s =~ s/Ѐ/Е/g;
          $s =~ s/Ё/Е/g;
          $s =~ s/Ѓ/Г/g;
          $s =~ s/Ќ/К/g;
          $s =~ s/Ѝ/И/g;
          $s =~ s/Й/И/g;
          $s =~ s/ѐ/е/g;
          $s =~ s/ё/е/g;
          $s =~ s/ѓ/г/g;
          $s =~ s/ќ/к/g;
          $s =~ s/ѝ/и/g;
          $s =~ s/й/и/g;
      }
   }
   return $s;
}

sub round_to_n_decimal_places {
   local($this, $x, $n) = @_;

   return $x unless defined($x);
   return $x if $x =~ /^-?\d+$/;
   $factor = 1;
   foreach $i ((1 .. $n)) {
      $factor *= 10;
   }
   if ($x > 0) {
      return (int(($factor * $x) + 0.5) / $factor);
   } else {
      return (int(($factor * $x) - 0.5) / $factor);
   }
}

sub commify {
   local($caller,$number) = @_;

   my $text = reverse $number;
   $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
   return scalar reverse $text;
}

sub add_javascript_functions {
 local($caller,@function_names) = @_;

 $add_javascript_function_s = "";
 foreach $function_name (@function_names) {

  if ($function_name eq "highlight_elems") {
     $add_javascript_function_s .= "
    function highlight_elems(group_id, value) {
       if (group_id != '') {
          i = 1;
          id = group_id + '-' + i;
          while ((s = document.getElementById(id)) != null) {
             if (! s.origColor) {
                if (s.style.color) {
                   s.origColor = s.style.color;
                } else {
                   s.origColor = '#000000';
                }
             }
             if (value == '1') {
                s.style.color = '#0000FF';
                if (s.innerHTML == '-') {
                   s.style.innerHtml = s.innerHTML;
                   s.innerHTML = '- &nbsp; &#x2190; <i>here</i>';
                   s.style.fontWeight = 900;
                } else {
                   s.style.fontWeight = 'bold';
                }
             } else {
                s.style.fontWeight = 'normal';
                s.style.color = s.origColor;
                if (s.style.innerHtml != null) {
                   s.innerHTML = s.style.innerHtml;
                }
             }
             i = i + 1;
             id = group_id + '-' + i;
          }
       }
    }
";
  } elsif ($function_name eq "set_style_for_ids") {
   $add_javascript_function_s .= "
   function set_style_for_ids(style,id_list) {
      var ids = id_list.split(/\\s+/);
      var len = ids.length;
      var s;
      for (var i=0; i<len; i++) {
	 var id = ids[i];
	 if ((s = document.getElementById(id)) != null) {
	    s.setAttribute(\"style\", style);
	    s.style.cssText = style;
	 }
      }
   }
";
  } elsif ($function_name eq "reset_style_for_ids") {
   $add_javascript_function_s .= "
   function reset_style_for_ids(default_style,id_list) {
      var ids = id_list.split(/\\s+/);
      var len = ids.length;
      var s;
      for (var i=0; i<len; i++) {
	 var id = ids[i];
	 if ((s = document.getElementById(id)) != null) {
	    var ostyle = default_style;
	    if (s.hasAttribute(\"ostyle\")) {
	       ostyle = s.getAttribute(\"ostyle\");
	    }
	    s.setAttribute(\"style\", ostyle);
	    s.style.cssText = ostyle;
	 }
      }
   }
";
  } elsif ($function_name eq "underline_ids") {
   $add_javascript_function_s .= "
   function underline_ids(id_list) {
      var ids = id_list.split(/\\s+/);
      var len = ids.length;
      var s;
      for (var i=0; i<len; i++) {
	 var id = ids[i];
	 if ((s = document.getElementById(id)) != null) {
	    s.style.textDecoration = 'underline';
	 }
      }
   }
";
  } elsif ($function_name eq "bold_ids") {
   $add_javascript_function_s .= "
   function bold_ids(id_list) {
      var ids = id_list.split(/\\s+/);
      var len = ids.length;
      var s;
      for (var i=0; i<len; i++) {
	 var id = ids[i];
	 if ((s = document.getElementById(id)) != null) {
	    s.style.fontWeight = 'bold';
	 }
      }
   }
";
  } elsif ($function_name eq "no_textdeco_ids") {
   $add_javascript_function_s .= "
   function no_textdeco_ids(id_list) {
      var ids = id_list.split(/\\s+/);
      var len = ids.length;
      var s;
      for (var i=0; i<len; i++) {
	 var id = ids[i];
	 if ((s = document.getElementById(id)) != null) {
	    s.style.textDecoration = 'none';
	    if (s.hasAttribute(\"ostyle\")) {
	       ostyle = s.getAttribute(\"ostyle\");
	       s.setAttribute(\"style\", ostyle);
	       s.style.cssText = ostyle;
	    }
	 }
      }
   }
";
  } elsif ($function_name eq "no_fontweight_ids") {
   $add_javascript_function_s .= "
   function no_fontweight_ids(id_list) {
      var ids = id_list.split(/\\s+/);
      var len = ids.length;
      var s;
      for (var i=0; i<len; i++) {
	 var id = ids[i];
	 if ((s = document.getElementById(id)) != null) {
	    s.style.fontWeight = 'normal';
	    if (s.hasAttribute(\"ostyle\")) {
	       ostyle = s.getAttribute(\"ostyle\");
	       s.setAttribute(\"style\", ostyle);
	       s.style.cssText = ostyle;
	    }
	 }
      }
   }
";
  } elsif ($function_name eq "popUpBottom") {
   $add_javascript_function_s .= "
    function popUpBottom(URL,width,height) {
       day = new Date();
       id = day.getTime();
       eval(\"myWindow = window.open(URL, '\" + id + \"', 'toolbar=0,scrollbars=1,location=0,statusbar=0,menubar=0,resizable=1,width=\" + width + \",height=\" + height + \"');\");
    }
";
  }
 }
 return $add_javascript_function_s;
}

sub append_to_file {
   local($caller, $filename, $s, $mod) = @_;

   my $result = "";
   if (-e $filename) {
      if (open(OUT, ">>$filename")) {
	 print OUT $s;
	 close(OUT);
	 $result = "Appended";
      } else {
	 $result = "Can't append";
      }
   } else {
      if (open(OUT, ">$filename")) {
	 print OUT $s;
	 close(OUT);
	 $result = "Wrote";
      } else {
	 $result = "Can't write";
      }
   }
   chmod($mod, $filename) if defined($mod) && -e $filename;
   return $result;
}

sub square {
   local($caller, $x) = @_;

   return $x * $x;
}

sub mutual_info {
   local($caller, $ab_count, $a_count, $b_count, $total_count, $smoothing) = @_;

   $smoothing = 1 unless defined($smoothing);
   $ab_count = 0 unless defined($ab_count);
   return 0 unless $a_count && $b_count && $total_count;

   my $p_ab = $ab_count / $total_count;
   my $p_a  = $a_count / $total_count;
   my $p_b  = $b_count / $total_count;
   my $expected_ab = $p_a * $p_b * $total_count;

   return -99 unless $expected_ab || $smoothing;

   return CORE::log(($ab_count + $smoothing) / ($expected_ab + $smoothing));
}

sub mutual_info_multi {
   local($caller, $multi_count, $total_count, $smoothing, @counts) = @_;

   return 0 unless $total_count;
   my $p_indivuals = 1;
   foreach $count (@counts) {
      return 0 unless $count;
      $p_indivuals *= ($count / $total_count);
   }
   my $expected_multi_count = $p_indivuals * $total_count;
   # print STDERR "actual vs. expected multi_count($multi_count, $total_count, $smoothing, @counts) = $multi_count vs. $expected_multi_count\n";

   return -99 unless $expected_multi_count || $smoothing;

   return CORE::log(($multi_count + $smoothing) / ($expected_multi_count + $smoothing));
}

sub precision_recall_fmeasure {
   local($caller, $n_gold, $n_test, $n_shared, $pretty_print_p) = @_;
   
   unless (($n_gold =~ /^[1-9]\d*$/) && ($n_test =~ /^[1-9]\d*$/)) {
      $zero = ($pretty_print_p) ? "0%" : 0;
      if ($n_gold =~ /^[1-9]\d*$/) {
	 return ("n/a", $zero, $zero);
      } elsif ($n_test =~ /^[1-9]\d*$/) {
	 return ($zero, "n/a", $zero);
      } else {
         return ("n/a", "n/a", "n/a");
      }
   }
   my $precision = $n_shared / $n_test;
   my $recall    = $n_shared / $n_gold;
   my $f_measure = ($precision * $recall * 2) / ($precision + $recall);

   return ($precision, $recall, $f_measure) unless $pretty_print_p;

   my $pretty_precision = $caller->round_to_n_decimal_places(100*$precision, 1) . "%";
   my $pretty_recall    = $caller->round_to_n_decimal_places(100*$recall,    1) . "%";
   my $pretty_f_measure = $caller->round_to_n_decimal_places(100*$f_measure, 1) . "%";

   return ($pretty_precision, $pretty_recall, $pretty_f_measure);
}

sub recapitalize_named_entity {
   local($caller, $s) = @_;

   my @comps = ();
   foreach $comp (split(/\s+/, $s)) {
      if ($comp =~ /^(and|da|for|of|on|the|van|von)$/) {
	 push(@comps, $comp);
      } elsif ($comp =~ /^[a-z]/) {
	 push(@comps, ucfirst $comp);
      } else {
	 push(@comps, $comp);
      }
   }
   return join(" ", @comps);
}

sub slot_value_in_double_colon_del_list {
   local($this, $s, $slot, $default) = @_;

   $default = "" unless defined($default);
   if (($value) = ($s =~ /::$slot\s+(\S.*\S|\S)\s*$/)) {
      $value =~ s/\s*::\S.*\s*$//;
      return $value;
   } else {
      return $default;
   }
}

sub multi_slot_value_in_double_colon_del_list {
   # e.g. when there are multiple slot/value pairs in a line, e.g. ::eng ... :eng ...
   local($this, $s, $slot) = @_;

   @values = ();
   while (($value, $rest) = ($s =~ /::$slot\s+(\S.*?\S|\S)(\s+::\S.*|\s*)$/)) {
      push(@values, $value);
      $s = $rest;
   }
   return @values;
}

sub extract_split_info_from_split_dir {
   local($this, $dir, *ht) = @_;

   my $n_files = 0;
   my $n_snt_ids = 0;
   if (opendir(DIR, $dir)) {
      my @filenames = sort readdir(DIR);
      closedir(DIR);
      foreach $filename (@filenames) {
	 next unless $filename =~ /\.txt$/;
	 my $split_class;
	 if (($split_class) = ($filename =~ /-(dev|training|test)-/)) {
	    my $full_filename = "$dir/$filename";
	    if (open(IN, $full_filename)) {
	      my $old_n_snt_ids = $n_snt_ids;
	      while (<IN>) {
		 if (($snt_id) = ($_ =~ /^#\s*::id\s+(\S+)/)) {
		    if ($old_split_class = $ht{SPLIT_CLASS}->{$snt_id}) {
		       unless ($old_split_class eq $split_class) {
		          print STDERR "Conflicting split class for $snt_id: $old_split_class $split_class\n";
		       }
		    } else {
		       $ht{SPLIT_CLASS}->{$snt_id} = $split_class;
		       $ht{SPLIT_CLASS_COUNT}->{$split_class} = ($ht{SPLIT_CLASS_COUNT}->{$split_class} || 0) + 1;
		       $n_snt_ids++;
		    }
		 }
	      }
	      $n_files++ unless $n_snt_ids == $old_n_snt_ids;
	      close(IN);
	    } else {
	       print STDERR "Can't open file $full_filename";
	    }
	 } else {
	    print STDERR "Skipping file $filename when extracting split info from $dir\n"; 
	 }
      }
      print STDERR "Extracted $n_snt_ids split classes from $n_files files.\n";
   } else {
      print STDERR "Can't open directory $dir to extract split info.\n";
   }
}

sub extract_toks_for_split_class_from_dir {
   local($this, $dir, *ht, $split_class, $control) = @_;

   $control = "" unless defined($control);
   $print_snt_id_p = ($control =~ /\bwith-snt-id\b/);
   my $n_files = 0;
   my $n_snts = 0;
   if (opendir(DIR, $dir)) {
      my @filenames = sort readdir(DIR);
      closedir(DIR);
      foreach $filename (@filenames) {
	 next unless $filename =~ /^alignment-release-.*\.txt$/;
	 my $full_filename = "$dir/$filename";
	 if (open(IN, $full_filename)) {
	    my $old_n_snts = $n_snts;
	    my $snt_id = "";
	    while (<IN>) {
	       if (($s_value) = ($_ =~ /^#\s*::id\s+(\S+)/)) {
		  $snt_id = $s_value;
		  $proper_split_class_p
	              = ($this_split_class = $ht{SPLIT_CLASS}->{$snt_id})
		     && ($this_split_class eq $split_class);
	       } elsif (($tok) = ($_ =~ /^#\s*::tok\s+(\S|\S.*\S)\s*$/)) {
		  if ($proper_split_class_p) {
		     print "$snt_id " if $print_snt_id_p;
		     print "$tok\n";
		     $n_snts++;
		  }
	       }
	    }
	    $n_files++ unless $n_snts == $old_n_snts;
	    close(IN);
	 } else {
	    print STDERR "Can't open file $full_filename";
	 }
      }
      print STDERR "Extracted $n_snts tokenized sentences ($split_class) from $n_files files.\n";
   } else {
      print STDERR "Can't open directory $dir to extract tokens.\n";
   }
}

sub load_relevant_tok_ngram_corpus {
   local($this, $filename, *ht, $max_lex_rule_span, $ngram_count_min, $optional_ngram_output_filename) = @_;

   $ngram_count_min = 1 unless $ngram_count_min;
   $max_lex_rule_span = 10 unless $max_lex_rule_span;
   my $n_ngram_instances = 0;
   my $n_ngram_types = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
	 s/\s*$//;
	 @tokens = split(/\s+/, $_);
	 foreach $from_token_index ((0 .. $#tokens)) {
	    foreach $to_token_index (($from_token_index .. ($from_token_index + $max_lex_rule_span -1))) {
	       last if $to_token_index > $#tokens;
	       my $ngram = join(" ", @tokens[$from_token_index .. $to_token_index]);
	       $ht{RELEVANT_NGRAM}->{$ngram} = ($ht{RELEVANT_NGRAM}->{$ngram} || 0) + 1;
	    }
	 }
      }
      close(IN);
      if ($optional_ngram_output_filename && open(OUT, ">$optional_ngram_output_filename")) {
	 foreach $ngram (sort keys %{$ht{RELEVANT_NGRAM}}) {
	    $count = $ht{RELEVANT_NGRAM}->{$ngram};
	    next unless $count >= $ngram_count_min;
	    print OUT "($count) $ngram\n";
	    $n_ngram_types++;
	    $n_ngram_instances += $count;
	 }
	 close(OUT);
         print STDERR "Extracted $n_ngram_types ngram types, $n_ngram_instances ngram instances.\n";
         print STDERR "Wrote ngram stats to $optional_ngram_output_filename\n";
      }
   } else {
      print STDERR "Can't open relevant tok ngram corpus $filename\n";
   }
}

sub load_relevant_tok_ngrams {
   local($this, $filename, *ht) = @_;

   my $n_entries = 0;
   if (open(IN, $filename)) {
      while (<IN>) {
	 s/\s*$//;
	 if (($count, $ngram) = ($_ =~ /^\((\d+)\)\s+(\S|\S.*\S)\s*$/)) {
	    $lc_ngram = lc $ngram;
	    $ht{RELEVANT_NGRAM}->{$lc_ngram} = ($ht{RELEVANT_NGRAM}->{$lc_ngram} || 0) + $count;
	    $ht{RELEVANT_LC_NGRAM}->{$lc_ngram} = ($ht{RELEVANT_LC_NGRAM}->{$lc_ngram} || 0) + $count;
	    $n_entries++;
	 }
      }
      close(IN);
      print STDERR "Read in $n_entries entries from $filename\n";
   } else {
      print STDERR "Can't open relevant tok ngrams from $filename\n";
   }
}

sub snt_id_sort_function {
   local($this, $a, $b) = @_;

   if ((($core_a, $index_a) = ($a =~ /^(\S+)\.(\d+)$/))
    && (($core_b, $index_b) = ($b =~ /^(\S+)\.(\d+)$/))) {
      return ($core_a cmp $core_b) || ($index_a <=> $index_b);
   } else {
      return $a cmp $b;
   }
}

sub count_value_sort_function {
   local($this, $a_count, $b_count, $a_value, $b_value, $control) = @_;

   # normalize fractions such as "1/2"
   if ($a_count > $b_count) {
      return ($control eq "decreasing") ? -1 : 1;
   } elsif ($b_count > $a_count) {
      return ($control eq "decreasing") ? 1 : -1;
   }
   $a_value = $num / $den if ($num, $den) = ($a_value =~ /^([1-9]\d*)\/([1-9]\d*)$/);
   $b_value = $num / $den if ($num, $den) = ($b_value =~ /^([1-9]\d*)\/([1-9]\d*)$/);
   $a_value =~ s/:/\./ if $a_value =~ /^\d+:\d+$/;
   $b_value =~ s/:/\./ if $b_value =~ /^\d+:\d+$/;
   if (($a_value =~ /^-?\d+(\.\d+)?$/)
    && ($b_value =~ /^-?\d+(\.\d+)?$/)) {
      return $a_value <=> $b_value;
   } elsif ($a_value =~ /^-?\d+(\.\d+)?$/) {
      return 1;
   } elsif ($b_value =~ /^-?\d+(\.\d+)?$/) {
      return -1;
   } else {
      return $a_value cmp $b_value;
   }
}

sub undef_to_blank {
   local($this, $x) = @_;

   return (defined($x)) ? $x : "";
}

sub en_lex_amr_list {
   local($this, $s) = @_;

   $bpe = qr{ \( (?: (?> [^()]+ ) | (??{ $bpe }))* \) }x; # see Perl Cookbook 2nd ed. p. 218
   @en_lex_amr_list = ();
   my $amr_s;
   my $lex;
   my $test;
   while ($s =~ /\S/) {
      $s =~ s/^\s*//;
      if (($s =~ /^\([a-z]\d* .*\)/)
       && (($amr_s, $rest) = ($s =~ /^($bpe)(\s.*|)$/))) {
	 push(@en_lex_amr_list, $amr_s);
	 $s = $rest;
      } elsif (($lex, $rest) = ($s =~ /^\s*(\S+)(\s.*|)$/)) {
	 push(@en_lex_amr_list, $lex);
	 $s = $rest;
      } else {
	 print STDERR "en_lex_amr_list can't process: $s\n";
	 $s = "";
      }
   }
   return @en_lex_amr_list;
}

sub make_sure_dir_exists {
   local($this, $dir, $umask) = @_;

   mkdir($dir, $umask) unless -d $dir;
   chmod($umask, $dir);
}

sub pretty_percentage {
   local($this, $numerator, $denominator) = @_;

   return ($denominator == 0) ? "n/a" : ($this->round_to_n_decimal_places(100*$numerator/$denominator, 2) . "%");
}

sub html_color_nth_line {
   local($this, $s, $n, $color, $delimiter) = @_;

   $delimiter = "<br>" unless defined($delimiter);
   @lines = split($delimiter, $s);
   $lines[$n] = "<font color=\"$color\">" . $lines[$n] . "</font>" if ($n =~ /^\d+$/) && ($n <= $#lines);
   return join($delimiter, @lines);
}

sub likely_valid_url_format {
   local($this, $url) = @_;
    
   $url = lc $url;
   return 0 if $url =~ /\s/;
   return 0 if $url =~ /[@]/;
   return 1 if $url =~ /^https?:\/\/.+\.[a-z]+(\?.+)?$/;
   return 1 if $url =~ /[a-z].+\.(com|edu|gov|net|org)$/;
   return 0;
}

sub max {
   local($this, @list) = @_;

   my $max = "";
   foreach $item (@list) {
      $max = $item if ($item =~ /^-?\d+(?:\.\d*)?$/) && (($max eq "") || ($item > $max));
   }
   return $max;
}

sub split_tok_s_into_tokens {
   local($this, $tok_s) = @_;

   @token_list = ();
   while (($pre, $link_token, $post) = ($tok_s =~ /^(.*?)\s*(\@?<[^<>]+>\@?)\s*(.*)$/)) {
      # generate dummy token for leading blank(s)
      if (($tok_s =~ /^\s/) && ($pre eq "") && ($#token_list < 0)) {
	 push(@token_list, "");
      } else {
         push(@token_list, split(/\s+/, $pre));
      }
      push(@token_list, $link_token);
      $tok_s = $post;
   }
   push(@token_list, split(/\s+/, $tok_s));
   return @token_list;
}

sub shuffle {
   local($this, @list) = @_;

   @shuffle_list = ();
   while (@list) {
      $len = $#list + 1;
      $rand_position = int(rand($len));
      push(@shuffle_list, $list[$rand_position]);
      splice(@list, $rand_position, 1);
   }
   $s = join(" ", @shuffle_list);
   return @shuffle_list;
}

sub timestamp_to_seconds {
   local($this, $timestamp) = @_;

   my $epochtime;
   if (($year, $month, $day, $hour, $minute, $second) = ($timestamp =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/)) {
      $epochtime = timelocal($second, $minute, $hour, $day, $month-1, $year);
   } elsif (($year, $month, $day) = ($timestamp =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/)) {
      $epochtime = timelocal(0, 0, 0, $day, $month-1, $year);
   } elsif (($year, $month, $day, $hour, $minute, $second, $second_fraction) = ($timestamp =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)\.(\d+)$/)) {
      $epochtime = timelocal($second, $minute, $hour, $day, $month-1, $year) + ($second_fraction / (10 ** length($second_fraction)));
   } else {
      $epochtime = 0;
   }
   return $epochtime;
}

sub timestamp_diff_in_seconds {
   local($this, $timestamp1, $timestamp2) = @_;

   my $epochtime1 = $this->timestamp_to_seconds($timestamp1);
   my $epochtime2 = $this->timestamp_to_seconds($timestamp2);
   return $epochtime2 - $epochtime1;
}

sub dirhash {
   # maps string to hash of length 4 with characters [a-z2-8] (shorter acc. to $len)
   local($this, $s, $len) = @_;

   $hash = 9999;
   $mega = 2 ** 20;
   $mega1 = $mega - 1;
   $giga = 2 ** 26;
   foreach $c (split //, $s) {
      $hash = $hash*33 + ord($c);
      $hash = ($hash >> 20) ^ ($hash & $mega1) if $hash >= $giga;
   }
   while ($hash >= $mega) {
      $hash = ($hash >> 20) ^ ($hash & $mega1);
   }
   $result = "";
   while ($hash) {
      $c = $hash & 31;
      $result .= CORE::chr($c + (($c >= 26) ? 24 : 97));
      $hash = $hash >> 5;
   }
   while (length($result) < 4) {
      $result .= "8";
   }
   return substr($result, 0, $len) if $len;
   return $result;
}

sub full_path_python {

   foreach $bin_path (split(":", "/usr/sbin:/usr/bin:/bin:/usr/local/bin")) {
      return $python if -x ($python = "$bin_path/python");
   }
   return "python";
}

sub string_contains_unbalanced_paras {
   local($this, $s) = @_;

   return 0 unless $s =~ /[(){}\[\]]/;
   $rest = $s;
   while (($pre,$left,$right,$post) = ($rest =~ /^(.*)([({\[]).*?([\]})])(.*)$/)) {
      return 1 unless (($left eq "(") && ($right eq ")"))
                   || (($left eq "[") && ($right eq "]"))
                   || (($left eq "{") && ($right eq "}"));
      $rest = "$pre$post";
   } 
   return 1 if $rest =~ /[(){}\[\]]/;
   return 0;
}

sub dequote_string {
   local($this, $s) = @_;

   if ($s =~ /^".*"$/)  {
      $s = substr($s, 1, -1);
      $s =~ s/\\"/"/g;
      return $s;
   } elsif ($s =~ /^'.*'$/)  {
      $s = substr($s, 1, -1);
      $s =~ s/\\'/'/g;
      return $s;
   } else {
      return $s;
   }
}

sub defined_non_space {
   local($this, $s) = @_;

   return (defined($s) && ($s =~ /\S/));
}

sub default_if_undefined {
   local($this, $s, $default) = @_;

   return (defined($s) ? $s : $default);
}

sub remove_empties {
   local($this, @list) = @_;

   @filtered_list = ();
   foreach $elem (@list) {
      push(@filtered_list, $elem) if defined($elem) && (! ($elem =~ /^\s*$/)) && (! $this->member($elem, @filtered_list));
   }

   return @filtered_list;
}

# copied from AMRexp.pm
sub new_var_for_surf_amr {
   local($this, $amr_s, $s) = @_;

   my $letter = ($s =~ /^[a-z]/i) ? lc substr($s, 0, 1) : "x";
   return $letter unless ($amr_s =~ /:\S+\s+\($letter\s+\//)
                      || ($amr_s =~ /\s\($letter\s+\//)
                      || ($amr_s =~ /^\s*\($letter\s+\//); # )))
   my $i = 2;
   while (($amr_s =~ /:\S+\s+\($letter$i\s+\//)
       || ($amr_s =~ /\s+\($letter$i\s+\//)
       || ($amr_s =~ /^\s*\($letter$i\s+\//)) { # )))
      $i++;
   }
   return "$letter$i";
}

# copied from AMRexp.pm
sub new_vars_for_surf_amr {
   local($this, $amr_s, $ref_amr_s) = @_;

   my $new_amr_s = "";
   my %new_var_ht = ();
   my $remaining_amr_s = $amr_s;
   my $pre; my $var; my $concept; my $post;
   while (($pre, $var, $concept, $post) = ($remaining_amr_s =~ /^(.*?\()([a-z]\d*)\s+\/\s+([^ ()\s]+)(.*)$/s)) {
      $new_var = $this->new_var_for_surf_amr("$ref_amr_s $new_amr_s", $concept);
      $new_var_ht{$var} = $new_var;
      $new_amr_s .= "$pre$new_var / $concept";
      $remaining_amr_s = $post;
   }
   $new_amr_s .= $remaining_amr_s;

   # also update any reentrancy variables
   $remaining_amr_s = $new_amr_s;
   $new_amr_s2 = "";
   while (($pre, $var, $post) = ($remaining_amr_s =~ /^(.*?:\S+\s+)([a-z]\d*)([ ()\s].*)$/s)) {
      $new_var = $new_var_ht{$var} || $var;
      $new_amr_s2 .= "$pre$new_var";
      $remaining_amr_s = $post;
   }
   $new_amr_s2 .= $remaining_amr_s;

   return $new_amr_s2;
}

1;
