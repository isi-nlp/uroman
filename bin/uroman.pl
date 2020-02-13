#!/usr/bin/perl -w

# uroman  Nov. 12, 2015 - Oct. 11, 2019
$version = "v1.2.6";
# Author: Ulf Hermjakob

# Usage: uroman.pl {-l [ara|bel|bul|deu|ell|eng|fas|grc|heb|kaz|kir|lav|lit|mkd|mkd2|oss|pnt|rus|srp|srp2|tur|uig|ukr|yid]} {--chart|--offset-mapping} {--no-cache} {--workset} < STDIN
# Example: cat workset.txt | uroman.pl --offset-mapping --workset

$|=1;

use FindBin;
use Cwd "abs_path";
use File::Basename qw(dirname);
use File::Spec;

my $bin_dir = abs_path(dirname($0));
my $root_dir = File::Spec->catfile($bin_dir, File::Spec->updir());
my $data_dir = File::Spec->catfile($root_dir, "data");
my $lib_dir = File::Spec->catfile($root_dir, "lib");

use lib "$FindBin::Bin/../lib";
use NLP::Chinese;
use NLP::Romanizer;
use NLP::UTF8;
use NLP::utilities;
use JSON;
$chinesePM = NLP::Chinese;
$romanizer = NLP::Romanizer;
$util = NLP::utilities;
%ht = ();
%pinyin_ht = ();
$lang_code = "";
$return_chart_p = 0;
$return_offset_mappings_p = 0;
$workset_p = 0;
$cache_rom_tokens_p = 1;

while (@ARGV) {
   $arg = shift @ARGV;
   if ($arg =~ /^-+(l|lc|lang-code)$/) {
      $lang_code = lc (shift @ARGV || "")
   } elsif ($arg =~ /^-+chart$/i) {
      $return_chart_p = 1;
   } elsif ($arg =~ /^-+workset$/i) {
      $workset_p = 1;
   } elsif ($arg =~ /^-+offset[-_]*map/i) {
      $return_offset_mappings_p = 1;
   } elsif ($arg =~ /^-+(no-tok-cach|no-cach)/i) {
      $cache_rom_tokens_p = 0;
   } else {
      print STDERR "Ignoring unrecognized arg $arg\n";
   }
}

$script_data_filename = File::Spec->catfile($data_dir, "Scripts.txt");
$unicode_data_filename = File::Spec->catfile($data_dir, "UnicodeData.txt");
$unicode_data_overwrite_filename = File::Spec->catfile($data_dir, "UnicodeDataOverwrite.txt");
$romanization_table_filename = File::Spec->catfile($data_dir, "romanization-table.txt");
$chinese_tonal_pinyin_filename = File::Spec->catfile($data_dir, "Chinese_to_Pinyin.txt");

$romanizer->load_script_data(*ht, $script_data_filename);
$romanizer->load_unicode_data(*ht, $unicode_data_filename);
$romanizer->load_unicode_overwrite_romanization(*ht, $unicode_data_overwrite_filename);
$romanizer->load_romanization_table(*ht, $romanization_table_filename);
$chinese_to_pinyin_not_yet_loaded_p = 1;
$current_date = $util->datetime("dateTtime");
$lang_code_clause = ($lang_code) ? " \"lang-code\":\"$lang_code\",\n" : "";

print "{\n \"romanizer\":\"uroman $version (Ulf Hermjakob, USC/ISI)\",\n \"date\":\"$current_date\",\n$lang_code_clause \"romanization\": [\n" if $return_chart_p;
my $line_number = 0;
my $chart_result = "";
while (<>) {
   $line_number++;
   my $line = $_;
   my $snt_id = "";
   if ($workset_p) {
      next if $line =~ /^#/;
      if (($i_value, $s_value) = ($line =~ /^(\S+\.\d+)\s(.*)$/)) {
	 $snt_id = $i_value;
	 $line = "$s_value\n";
      } else {
	 next;
      }
   }
   if ($chinese_to_pinyin_not_yet_loaded_p && $chinesePM->string_contains_utf8_cjk_unified_ideograph_p($line)) {
      $chinesePM->read_chinese_tonal_pinyin_files(*pinyin_ht, $chinese_tonal_pinyin_filename);
      $chinese_to_pinyin_not_yet_loaded_p = 0;
   }
   if ($return_chart_p) {
      print $chart_result;
      *chart_ht = $romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "return chart", $line_number);
      $chart_result = $romanizer->chart_to_json_romanization_elements(0, $chart_ht{N_CHARS}, *chart_ht, $line_number);
   } elsif ($return_offset_mappings_p) {
      ($best_romanization, $offset_mappings) = $romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "return offset mappings", $line_number, 0);
      print "::snt-id $snt_id\n" if $workset_p;
      print "::orig $line";
      print "::rom $best_romanization\n";
      print "::align $offset_mappings\n\n";
   } elsif ($cache_rom_tokens_p) {
      print $romanizer->romanize_by_token_with_caching($line, $lang_code, "", *ht, *pinyin_ht, 0, "", $line_number) . "\n";
   } else {
      print $romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "", $line_number) . "\n";
   }
}
$chart_result =~ s/,(\s*)$/$1/;
print $chart_result;
print " ]\n}\n" if $return_chart_p;

$dev_test_p = 0;
if ($dev_test_p) {
   foreach $char_name (sort keys %{$ht{SUSPICIOUS_ROMANIZATION}}) {
      foreach $romanization (sort keys %{$ht{SUSPICIOUS_ROMANIZATION}->{$char_name}}) {
         $count = $ht{SUSPICIOUS_ROMANIZATION}->{$char_name}->{$romanization};
	 $s = ($count == 1) ? "" : "s";
         print STDERR "  *** Suspiciously lengthy romanization: $char_name -> $romanization ($count instance$s)\n";
      }
   }
} 

exit 0;

