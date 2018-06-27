#!/usr/bin/perl -w

# uroman  Nov. 12, 2015 - Apr. 11, 2017
$version = "v1.2";
# Author: Ulf Hermjakob

# Usage: uroman.pl {-l [ara|fas|heb|tur|uig|ukr|yid]} {--chart} {--no-cache} < STDIN

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
$chart_output_p = 0;
$cache_rom_tokens_p = 1;

while (@ARGV) {
   $arg = shift @ARGV;
   if ($arg =~ /^-+(l|lc|lang-code)$/) {
      $lang_code = lc (shift @ARGV || "")
   } elsif ($arg =~ /^-+chart$/i) {
      $chart_output_p = 1;
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

print "{\n \"romanizer\":\"uroman $version (Ulf Hermjakob, USC/ISI)\",\n \"date\":\"$current_date\",\n$lang_code_clause \"romanization\": [\n" if $chart_output_p;
my $line_number = 0;
my $chart_result = "";
while (<>) {
   $line_number++;
   my $line = $_;
   if ($chinese_to_pinyin_not_yet_loaded_p && $chinesePM->string_contains_utf8_cjk_unified_ideograph_p($line)) {
      $chinesePM->read_chinese_tonal_pinyin_files(*pinyin_ht, $chinese_tonal_pinyin_filename);
      $chinese_to_pinyin_not_yet_loaded_p = 0;
   }
   if ($chart_output_p) {
      print $chart_result;
      *chart_ht = $romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "return chart", $line_number);
      $chart_result = $romanizer->chart_to_json_romanization_elements(0, $chart_ht{N_CHARS}, *chart_ht, $line_number);
   } elsif ($cache_rom_tokens_p) {
      print $romanizer->romanize_by_token_with_caching($line, $lang_code, "", *ht, *pinyin_ht, 0, "", $line_number) . "\n";
   } else {
      print $romanizer->romanize($line, $lang_code, "", *ht, *pinyin_ht, 0, "", $line_number) . "\n";
   }
}
$chart_result =~ s/,(\s*)$/$1/;
print $chart_result;
print " ]\n}\n" if $chart_output_p;

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

