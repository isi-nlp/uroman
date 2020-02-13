################################################################
#                                                              #
# stringDistance                                               #
#                                                              #
################################################################

package NLP::stringDistance;

use List::Util qw(min max);
$utf8 = NLP::UTF8;
$util = NLP::utilities;
$romanizer = NLP::Romanizer;

%dummy_ht = ();

sub rule_string_expansion {
   local($this, *ht, $s, $lang_code) = @_;
   
   my @characters = $utf8->split_into_utf8_characters($s, "return only chars, return trailing whitespaces", *dummy_ht);
   foreach $sub_len ((0 .. ($#characters-1))) {
      my $sub = join("", @characters[0 .. $sub_len]);
      foreach $super_len ((($sub_len + 1) .. $#characters)) {
         my $super = join("", @characters[0 .. $super_len]);
	 # print STDERR "  $sub -> $super\n" unless $ht{RULE_STRING_EXPANSION}->{$lang_code}->{$sub}->{$super};
	 $ht{RULE_STRING_EXPANSION}->{$lang_code}->{$sub}->{$super} = 1;
	 $ht{RULE_STRING_HAS_EXPANSION}->{$lang_code}->{$sub} = 1;
	 # print STDERR "  RULE_STRING_HAS_EXPANSION $lang_code $sub\n";
      }
   }
}

sub load_string_distance_data {
   local($this, $filename, *ht, $verbose) = @_;

   $verbose = 0 unless defined($verbose);
   open(IN,$filename) || die "Could not open $filename";
   my $line_number = 0;
   my $n_cost_rules = 0;
   while (<IN>) {
      $line_number++;
      my $line = $_;
      $line =~ s/^\xEF\xBB\xBF//;
      $line =~ s/\s*$//;
      next if $line =~ /^\s*(\#.*)?$/;
      print STDERR "** Warning: line $line_number contains suspicious control character: $line\n" if $line =~ /[\x00-\x1F]/;
      my $s1 = $util->slot_value_in_double_colon_del_list($line, "s1");
      my $s2 = $util->slot_value_in_double_colon_del_list($line, "s2");
      $s1 = $util->dequote_string($s1); # 'can\'t' => can't
      $s2 = $util->dequote_string($s2);
      my $cost = $util->slot_value_in_double_colon_del_list($line, "cost");
      if (($s1 eq "") && ($s2 eq "")) {
	 print STDERR "Ignoring bad line $line_number in $filename, because both s1 and s2 are empty strings\n";
         next;
      }
      unless ($cost =~ /^\d+(\.\d+)?$/) {
	 if ($cost eq "") {
	    print STDERR "Ignoring bad line $line_number in $filename, because of missing cost\n";
	 } else {
	    print STDERR "Ignoring bad line $line_number in $filename, because of ill-formed cost $cost\n";
	 }
         next;
      }
      my $lang_code1_s = $util->slot_value_in_double_colon_del_list($line, "lc1");
      my $lang_code2_s = $util->slot_value_in_double_colon_del_list($line, "lc2");
      my @lang_codes_1 = ($lang_code1_s eq "") ? ("") : split(/,\s*/, $lang_code1_s);
      my @lang_codes_2 = ($lang_code2_s eq "") ? ("") : split(/,\s*/, $lang_code2_s);
      my $left_context1 = $util->slot_value_in_double_colon_del_list($line, "left1");
      my $left_context2 = $util->slot_value_in_double_colon_del_list($line, "left2");
      my $right_context1 = $util->slot_value_in_double_colon_del_list($line, "right1");
      my $right_context2 = $util->slot_value_in_double_colon_del_list($line, "right2");
      my $bad_left = $util->slot_value_in_double_colon_del_list($line, "left");
      if ($bad_left) {
	 print STDERR "** Warning: slot '::left $bad_left' in line $line_number\n";
         next;
      }
      my $bad_right = $util->slot_value_in_double_colon_del_list($line, "right");
      if ($bad_right) {
	 print STDERR "** Warning: slot '::right $bad_right' in line $line_number\n";
         next;
      }
      my $in_lang_codes1 = $util->slot_value_in_double_colon_del_list($line, "in-lc1");
      my $in_lang_codes2 = $util->slot_value_in_double_colon_del_list($line, "in-lc2");
      my $out_lang_codes1 = $util->slot_value_in_double_colon_del_list($line, "out-lc1");
      my $out_lang_codes2 = $util->slot_value_in_double_colon_del_list($line, "out-lc2");
      if ($left_context1) {
         if ($left_context1 =~ /^\/.*\/$/) {
            $left_context1 =~ s/^\///;
            $left_context1 =~ s/\/$//;
         } else {
            print STDERR "Ignoring unrecognized non-regular-express ::left1 $left_context1 in $line_number of $filename\n";
            $left_context1 = "";
         }
      }
      if ($left_context2) {
         if ($left_context2 =~ /^\/.*\/$/) {
            $left_context2 =~ s/^\///;
            $left_context2 =~ s/\/$//;
         } else {
            $left_context2 = "";
            print STDERR "Ignoring unrecognized non-regular-express ::left2 $left_context2 in $line_number of $filename\n";
         }
      }
      if ($right_context1) {
         unless ($right_context1 =~ /^(\[[^\[\]]*\])+$/) {
	    $right_context1 = "";
	    print STDERR "Ignoring unrecognized right-context ::right1 $right_context1 in $line_number of $filename\n";
	 }
      }
      if ($right_context2) {
         unless ($right_context2 =~ /^(\[[^\[\]]*\])+$/) {
	    $right_context2 = "";
	    print STDERR "Ignoring unrecognized right-context ::right2 $right_context2 in $line_number of $filename\n";
	 }
      }
      foreach $lang_code1 (@lang_codes_1) {
         foreach $lang_code2 (@lang_codes_2) {
            $n_cost_rules++;
            my $cost_rule_id = $n_cost_rules;
            $ht{COST}->{$lang_code1}->{$lang_code2}->{$s1}->{$s2}->{$cost_rule_id} = $cost;
            $ht{RULE_STRING}->{$lang_code1}->{$s1} = 1;
            $ht{RULE_STRING}->{$lang_code2}->{$s2} = 1;
            $ht{LEFT1}->{$cost_rule_id} = $left_context1;
            $ht{LEFT2}->{$cost_rule_id} = $left_context2;
            $ht{RIGHT1}->{$cost_rule_id} = $right_context1;
            $ht{RIGHT2}->{$cost_rule_id} = $right_context2;
            $ht{INLC1}->{$cost_rule_id} = $in_lang_codes1;
            $ht{INLC2}->{$cost_rule_id} = $in_lang_codes2;
            $ht{OUTLC1}->{$cost_rule_id} = $out_lang_codes1;
            $ht{OUTLC2}->{$cost_rule_id} = $out_lang_codes2;
            unless (($s1 eq $s2)
	         && ($lang_code1 eq $lang_code2)
	         && ($left_context1 eq $left_context2)
	         && ($right_context1 eq $right_context2)
	         && ($in_lang_codes1 eq $in_lang_codes2)
	         && ($out_lang_codes1 eq $out_lang_codes2)) {
               $n_cost_rules++;
               $cost_rule_id = $n_cost_rules;
               $ht{COST}->{$lang_code2}->{$lang_code1}->{$s2}->{$s1}->{$cost_rule_id} = $cost;
               $ht{LEFT1}->{$cost_rule_id} = $left_context2;
               $ht{LEFT2}->{$cost_rule_id} = $left_context1;
               $ht{RIGHT1}->{$cost_rule_id} = $right_context2;
               $ht{RIGHT2}->{$cost_rule_id} = $right_context1;
               $ht{INLC1}->{$cost_rule_id} = $in_lang_codes2;
               $ht{INLC2}->{$cost_rule_id} = $in_lang_codes1;
               $ht{OUTLC1}->{$cost_rule_id} = $out_lang_codes2;
               $ht{OUTLC2}->{$cost_rule_id} = $out_lang_codes1;
	       # print STDERR "  Flip rule in line $line: $line\n";
            }
            $this->rule_string_expansion(*ht, $s1, $lang_code1);
            $this->rule_string_expansion(*ht, $s2, $lang_code2);
	 }
      }
   }
   close(IN);
   print STDERR "Read in $n_cost_rules rules from $line_number lines in $filename\n" if $verbose;
}

sub romanized_string_to_simple_chart {
   local($this, $s, *chart_ht) = @_;

   my @characters = $utf8->split_into_utf8_characters($s, "return only chars, return trailing whitespaces", *dummy_ht);
   $chart_ht{N_CHARS} = $#characters + 1;
   $chart_ht{N_NODES} = 0;
   foreach $i ((0 .. $#characters)) {
      $romanizer->add_node($characters[$i], $i, ($i+1), *chart_ht, "", "");
   }
}

sub linearize_chart_points {
   local($this, *chart_ht, $chart_id, *sd_ht, $verbose) = @_;

   $verbose = 0 unless defined($verbose);
   print STDERR "Linearize $chart_id\n" if $verbose;
   my $current_chart_pos = 0;
   my $current_linear_chart_pos = 0;
   $sd_ht{POS2LINPOS}->{$chart_id}->{$current_chart_pos} = $current_linear_chart_pos;
   $sd_ht{LINPOS2POS}->{$chart_id}->{$current_linear_chart_pos} = $current_chart_pos;
   print STDERR "  LINPOS2POS.$chart_id LIN: $current_linear_chart_pos POS: $current_chart_pos\n" if $verbose;
   my @end_chart_positions = keys %{$chart_ht{NODES_ENDING_AT}};
   my $end_chart_pos = (@end_chart_positions) ? max(@end_chart_positions) : 0;
   $sd_ht{MAXPOS}->{$chart_id} = $end_chart_pos;
   print STDERR "  Chart span: $current_chart_pos-$end_chart_pos\n" if $verbose;
   while ($current_chart_pos < $end_chart_pos) {
      my @node_ids = keys %{$chart_ht{NODES_STARTING_AT}->{$current_chart_pos}};
      foreach $node_id (@node_ids) {
	 my $roman_s = $chart_ht{NODE_ROMAN}->{$node_id};
         my @roman_chars = $utf8->split_into_utf8_characters($roman_s, "return only chars, return trailing whitespaces", *dummy_ht);
         print STDERR "  $current_chart_pos/$current_linear_chart_pos node: $node_id $roman_s (@roman_chars)\n" if $verbose;
	 if ($#roman_chars >= 1) {
	    foreach $i ((1 .. $#roman_chars)) {
	       $current_linear_chart_pos++;
	       $sd_ht{SPLITPOS2LINPOS}->{$chart_id}->{$current_chart_pos}->{$node_id}->{$i} = $current_linear_chart_pos;
	       $sd_ht{LINPOS2SPLITPOS}->{$chart_id}->{$current_linear_chart_pos}->{$current_chart_pos}->{$node_id}->{$i} = 1;
	       print STDERR "  LINPOS2SPLITPOS.$chart_id LIN: $current_linear_chart_pos POS: $current_chart_pos NODE: $node_id I: $i\n" if $verbose;
	    }
	 }
      }
      $current_chart_pos++;
      if ($util->member($current_chart_pos, @end_chart_positions)) {
         $current_linear_chart_pos++;
         $sd_ht{POS2LINPOS}->{$chart_id}->{$current_chart_pos} = $current_linear_chart_pos;
         $sd_ht{LINPOS2POS}->{$chart_id}->{$current_linear_chart_pos} = $current_chart_pos;
         print STDERR "  LINPOS2POS.$chart_id LIN: $current_linear_chart_pos POS: $current_chart_pos\n" if $verbose;
      }
   }
   $current_chart_pos = 0;
   while ($current_chart_pos <= $end_chart_pos) {
      my $current_linear_chart_pos = $sd_ht{POS2LINPOS}->{$chart_id}->{$current_chart_pos};
      $current_linear_chart_pos = "?" unless defined($current_linear_chart_pos);
      my @node_ids = keys %{$chart_ht{NODES_STARTING_AT}->{$current_chart_pos}};
      # print STDERR "  LINROM.$chart_id LIN: $current_linear_chart_pos POS: $current_chart_pos NODES: @node_ids\n" if $verbose;
      foreach $node_id (@node_ids) {
	 my $end_pos = $chart_ht{NODE_END}->{$node_id};
	 my $end_linpos = $sd_ht{POS2LINPOS}->{$chart_id}->{$end_pos};
	 my $roman_s = $chart_ht{NODE_ROMAN}->{$node_id};
         my @roman_chars = $utf8->split_into_utf8_characters($roman_s, "return only chars, return trailing whitespaces", *dummy_ht);
         print STDERR "  LINROM.$chart_id LIN: $current_linear_chart_pos POS: $current_chart_pos NODE: $node_id CHARS: @roman_chars\n" if $verbose;
	 if (@roman_chars) {
            foreach $i ((0 .. $#roman_chars)) {
	       my $from_linear_chart_pos 
		  = (($i == 0) 
		     ? $sd_ht{POS2LINPOS}->{$chart_id}->{$current_chart_pos}
	             : $sd_ht{SPLITPOS2LINPOS}->{$chart_id}->{$current_chart_pos}->{$node_id}->{$i});
	       print STDERR "  FROM.$chart_id I: $i POS: $current_chart_pos NODE: $node_id FROM: $from_linear_chart_pos\n" if $verbose;
	       my $to_linear_chart_pos
		  = (($i == $#roman_chars)
		     ? $end_linpos
		     : $sd_ht{SPLITPOS2LINPOS}->{$chart_id}->{$current_chart_pos}->{$node_id}->{($i+1)});
	       print STDERR "  TO.$chart_id I: $i POS: $current_chart_pos NODE: $node_id FROM: $to_linear_chart_pos\n" if $verbose;
	       my $roman_char = $roman_chars[$i];
	       $sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$from_linear_chart_pos}->{$to_linear_chart_pos}->{$roman_char} = 1;
	    }
	 } else {
	    my $from_linear_chart_pos = $sd_ht{POS2LINPOS}->{$chart_id}->{$current_chart_pos};
	    my $to_linear_chart_pos = $sd_ht{POS2LINPOS}->{$chart_id}->{($current_chart_pos+1)};
	    # HHERE check this out
	    my $i = 1;
	    while (! (defined($to_linear_chart_pos))) {
	       $i++;
	       $to_linear_chart_pos = $sd_ht{POS2LINPOS}->{$chart_id}->{($current_chart_pos+$i)};
	    }
	    if (defined($from_linear_chart_pos) && defined($to_linear_chart_pos)) {
	       $sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$from_linear_chart_pos}->{$to_linear_chart_pos}->{""} = 1
	    } else {
	       print STDERR "  UNDEF.$chart_id from: " 
	                  . ((defined($from_linear_chart_pos)) ? $from_linear_chart_pos : "?")
			  . " to: "
	                  . ((defined($to_linear_chart_pos))   ? $to_linear_chart_pos   : "?")
			  . "\n";
	    }
	 }
      }
      $current_chart_pos++;
   }
   $sd_ht{MAXLINPOS}->{$chart_id} = $sd_ht{POS2LINPOS}->{$chart_id}->{$end_chart_pos};
}

sub expand_lin_ij_roman {
   local($this, *sd_ht, $chart_id, $lang_code, *ht) = @_;

   foreach $start (sort { $a <=> $b } keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}}) {
      foreach $end (sort { $a <=> $b } keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$start}}) {
	 foreach $roman (sort keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$start}->{$end}}) {
	    if ($ht{RULE_STRING_HAS_EXPANSION}->{$lang_code}->{$roman}
	     || $ht{RULE_STRING_HAS_EXPANSION}->{""}->{$roman}) {
	       $this->expand_lin_ij_roman_rec(*sd_ht, $chart_id, $start, $end, $roman, $lang_code, *ht);
	    }
	 }
      }
   }
}

sub expand_lin_ij_roman_rec {
   local($this, *sd_ht, $chart_id, $start, $end, $roman, $lang_code, *ht) = @_;

   # print STDERR "  expand_lin_ij_roman_rec.$chart_id $start-$end $lang_code $roman\n";
   return unless $ht{RULE_STRING_HAS_EXPANSION}->{$lang_code}->{$roman}
              || $ht{RULE_STRING_HAS_EXPANSION}->{""}->{$roman};
   foreach $new_end (keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$end}}) {
      foreach $next_roman (sort keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$end}->{$new_end}}) {
         my $exp_roman = join("", $roman, $next_roman);
         if ($ht{RULE_STRING}->{$lang_code}->{$exp_roman}
          || $ht{RULE_STRING}->{""}->{$exp_roman}) {
            $sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$start}->{$new_end}->{$exp_roman} = 1;
	    # print STDERR "  Expansion ($start-$new_end) $exp_roman\n";
         }
         if ($ht{RULE_STRING_HAS_EXPANSION}->{$lang_code}->{$exp_roman}
          || $ht{RULE_STRING_HAS_EXPANSION}->{""}->{$exp_roman}) {
	    $this->expand_lin_ij_roman_rec(*sd_ht, $chart_id, $start, $new_end, $exp_roman, $lang_code, *ht);
         }
      }
   }
}

sub trace_string_distance {
   local($this, *sd_ht, $chart1_id, $chart2_id, $control, $line_number, $cost) = @_;

   my $chart_comb_id = join("/", $chart1_id, $chart2_id);
   return "mismatch" if $sd_ht{MISMATCH}->{$chart_comb_id};
   my $chart1_end = $sd_ht{MAXLINPOS}->{$chart1_id};
   my $chart2_end = $sd_ht{MAXLINPOS}->{$chart2_id};
   my $verbose = ($control =~ /verbose/);
   my $chunks_p = ($control =~ /chunks/);
   my @traces = ();
   my @s1_s = ();
   my @s2_s = ();
   my @e1_s = ();
   my @e2_s = ();
   my @r1_s = ();
   my @r2_s = ();
   my @ic_s = ();

   # print STDERR "trace_string_distance $chart1_id $chart2_id $line_number\n";
   while ($chart1_end || $chart2_end) {
      my $incr_cost = $sd_ht{INCR_COST_IJ}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
      my $prec_i = $sd_ht{PREC_I}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
      my $prec_j = $sd_ht{PREC_J}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
      if ($incr_cost || $verbose || $chunks_p) {
         my $roman1 = $sd_ht{ROMAN1}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
         my $roman2 = $sd_ht{ROMAN2}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
         if ($verbose) {
	    push(@traces, "$prec_i-$chart1_end/$prec_j-$chart2_end:$roman1/$roman2:$incr_cost");
	 } else {
	    if (defined($roman1)) {
	       push(@traces, "$roman1/$roman2:$incr_cost");
	    } else {
	       $print_prec_i = (defined($prec_i)) ? $prec_i : "?";
	       $print_prec_j = (defined($prec_j)) ? $prec_j : "?";
	       print STDERR "  $prec_i-$chart1_end, $prec_j-$chart2_end\n";
	    }
	 }
         if ($chunks_p) {
            push(@s1_s, $prec_i);
            push(@s2_s, $prec_j);
            push(@e1_s, $chart1_end);
            push(@e2_s, $chart2_end);
            push(@r1_s, $roman1);
            push(@r2_s, $roman2);
            push(@ic_s, $incr_cost);
         }
      }
      $chart1_end = $prec_i;
      $chart2_end = $prec_j;
   }
   if ($chunks_p) {
      my $r1 = "";
      my $r2 = "";
      my $tc = 0;
      my $in_chunk = 0;
      foreach $i ((0 .. $#ic_s)) {
	 if ($ic_s[$i]) {
	    $r1 = $r1_s[$i] . $r1;
	    $r2 = $r2_s[$i] . $r2;
	    $tc += $ic_s[$i];
	    $in_chunk = 1;
	 } elsif ($in_chunk) {
	    $chunk = "$r1/$r2/$tc";
	    $chunk .= "*" if $cost > 5;
	    $sd_ht{N_COST_CHUNK}->{$chunk} = ($sd_ht{N_COST_CHUNK}->{$chunk} || 0) + 1;
	    $sd_ht{EX_COST_CHUNK}->{$chunk}->{$line_number} = 1;
            $r1 = "";
            $r2 = "";
            $tc = 0;
	    $in_chunk = 0;
	 }
      }
      if ($in_chunk) {
	 $chunk = "$r1/$r2/$tc";
	 $chunk .= "*" if $cost > 5;
	 $sd_ht{N_COST_CHUNK}->{$chunk} = ($sd_ht{N_COST_CHUNK}->{$chunk} || 0) + 1;
	 $sd_ht{EX_COST_CHUNK}->{$chunk}->{$line_number} = 1;
      }
   } else {
      return join(" ", reverse @traces);
   }
}

sub right_context_match {
   local($this, $right_context_rule, *sd_ht, $chart_id, $start_pos) = @_;
   
   return 1 if $right_context_rule eq "";
   if (($right_context_item, $right_context_rest) = ($right_context_rule =~ /^\[([^\[\]]*)\]*(.*)$/)) {
      my $guarded_right_context_item = $right_context_item;
      $guarded_right_context_item =~ s/\$/\\\$/g;
      my @end_positions = keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$start_pos}};
      return 1 if ($#end_positions == -1)
               && (($right_context_item eq "") 
	        || ($right_context_item =~ /\$/));
      foreach $end_pos (@end_positions) {
	 my @romans = keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$start_pos}->{$end_pos}};
         foreach $roman (@romans) {
	    if ($roman =~ /^[$guarded_right_context_item]/) {
	       return $this->right_context_match($right_context_rest, *sd_ht, $chart_id, $end_pos);
	    }
	 }
      }
   }
   return 0;
}

sub string_distance {
   local($this, *sd_ht, $chart1_id, $chart2_id, $lang_code1, $lang_code2, *ht, $control) = @_;

   my $verbose = ($control =~ /verbose/i);
   my $chart_comb_id = join("/", $chart1_id, $chart2_id);

   my $chart1_end_pos = $sd_ht{MAXLINPOS}->{$chart1_id};
   my $chart2_end_pos = $sd_ht{MAXLINPOS}->{$chart2_id};
   print STDERR "string_distance.$chart_comb_id $chart1_end_pos/$chart2_end_pos\n" if $verbose;
   $sd_ht{COST_IJ}->{$chart_comb_id}->{0}->{0} = 0;
   $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{0}->{0} = "";
   $sd_ht{COMB_LEFT_ROMAN2}->{$chart_comb_id}->{0}->{0} = "";
   # HHERE
   foreach $chart1_start ((0 .. $chart1_end_pos)) {
      # print STDERR "  C1 $chart1_start- ($chart1_start .. $chart1_end_pos)\n";
      my $prev_further_expansion_possible = 0;
      my @chart1_ends = sort { $a <=> $b } keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart1_id}->{$chart1_start}};
      my $max_chart1_ends = (@chart1_ends) ? $chart1_ends[$#chart1_ends] : -1;
      foreach $chart1_end (($chart1_start .. $chart1_end_pos)) {
	 my $further_expansion_possible = ($chart1_start == $chart1_end)
				       || defined($sd_ht{LINPOS2SPLITPOS}->{$chart1_id}->{$chart1_start})
				       || ($chart1_end < $max_chart1_ends);
	 my @romans1 = (($chart1_start == $chart1_end)
			? ("")
			: (sort keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart1_id}->{$chart1_start}->{$chart1_end}}));
	 if ($#romans1 == -1) {
	    $further_expansion_possible = 1 if $prev_further_expansion_possible;
	 } else {
	    $prev_further_expansion_possible = 0;
	 }
         # print STDERR "  C1 $chart1_start-$chart1_end romans1: @romans1 {$further_expansion_possible} *l*\n";
	 foreach $roman1 (@romans1) {
            # print STDERR "  C1 $chart1_start-$chart1_end $roman1 {$further_expansion_possible} *?*\n";
	    next unless $ht{RULE_STRING}->{$lang_code1}->{$roman1}
		     || $ht{RULE_STRING}->{""}->{$roman1};
            # print STDERR "  C1 $chart1_start-$chart1_end $roman1 {$further_expansion_possible} ***\n";
	    foreach $lang_code1o (($lang_code1, "")) {
	       foreach $lang_code2o (($lang_code2, "")) {
		  my @chart2_starts = (sort { $a <=> $b } keys %{$sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_start}});
	          foreach $chart2_start (@chart2_starts) {
                     # print STDERR "  C1 $chart1_start-$chart1_end $roman1 C2 $chart2_start- (@chart2_starts)\n";
		     foreach $chart2_end (($chart2_start .. $chart2_end_pos)) {
                        print STDERR "  C1 $chart1_start-$chart1_end $roman1 C2 $chart2_start-$chart2_end\n";
			my @romans2 = (($chart2_start == $chart2_end)
				      ? ("")
				      : (sort keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart2_id}->{$chart2_start}->{$chart2_end}}));
			foreach $roman2 (@romans2) {
			   if ($roman1 eq $roman2) {
                              print STDERR "  C1 $chart1_start-$chart1_end $roman1 C2 $chart2_start-$chart2_end $roman2 (IDENTITY)\n";
			      my $cost = 0;
			      my $preceding_cost = $sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_start}->{$chart2_start};
			      my $combined_cost = $preceding_cost + $cost;
			      my $old_cost = $sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
			      if ((! defined($old_cost)) || ($combined_cost < $old_cost)) {
			         $sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $combined_cost;
			         push(@chart2_starts, $chart2_end) unless $util->member($chart2_end, @chart2_starts);
			         $sd_ht{PREC_I}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $chart1_start;
			         $sd_ht{PREC_J}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $chart2_start;
			         $sd_ht{ROMAN1}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $roman1;
			         $sd_ht{ROMAN2}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $roman2;
			         $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{$chart1_end}->{$chart2_end}
			            = $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{$chart1_start}->{$chart2_start} . $roman1;
			         $sd_ht{COMB_LEFT_ROMAN2}->{$chart_comb_id}->{$chart1_end}->{$chart2_end}
			            = $sd_ht{COMB_LEFT_ROMAN2}->{$chart_comb_id}->{$chart1_start}->{$chart2_start} . $roman2;
				 $comb_left_roman1 = $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
			         $sd_ht{INCR_COST_IJ}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $cost;
			         $sd_ht{COST_RULE}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = "IDENTITY";
			         print STDERR "  New cost $chart1_end/$chart2_end: $combined_cost (+$cost from $chart1_start/$chart2_start $roman1/$roman2)\n" if $verbose;
			      }
			   } else {
	                      next unless $ht{RULE_STRING}->{$lang_code2o}->{$roman2};
                              print STDERR "  C1 $chart1_start-$chart1_end $roman1 C2 $chart2_start-$chart2_end $roman2\n";
			      next unless defined($ht{COST}->{$lang_code1o}->{$lang_code2o}->{$roman1}->{$roman2});
		              my @cost_rule_ids = keys %{$ht{COST}->{$lang_code1o}->{$lang_code2o}->{$roman1}->{$roman2}};
		              foreach $cost_rule_id (@cost_rule_ids) {
			         ## check whether any context requirements are satisfied
			         # left context rules are regular expressions
                                 my $left_context_rule1 = $ht{LEFT1}->{$cost_rule_id};
			         if ($left_context_rule1) {
				    my $comb_left_roman1 = $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{$chart1_start}->{$chart2_start};
				    if (defined($comb_left_roman1)) {
				       next unless $comb_left_roman1 =~ /$left_context_rule1/;
			            } else {
				       print STDERR "  No comb_left_roman1 value for $chart_comb_id $chart1_start,$chart2_start\n";
				    }
			         }
                                 my $left_context_rule2 = $ht{LEFT2}->{$cost_rule_id};
			         if ($left_context_rule2) {
				    my $comb_left_roman2 = $sd_ht{COMB_LEFT_ROMAN2}->{$chart_comb_id}->{$chart1_start}->{$chart2_start};
				    if (defined($comb_left_roman2)) {
				       next unless $comb_left_roman2 =~ /$left_context_rule2/;
				    } else {
				       print STDERR "  No comb_left_roman2 value for $chart_comb_id $chart1_start,$chart2_start\n";
				    }
			         }
                                 my $right_context_rule1 = $ht{RIGHT1}->{$cost_rule_id};
			         if ($right_context_rule1) {
			            my $match_p = $this->right_context_match($right_context_rule1, *sd_ht, $chart1_id, $chart1_end);
				    # print STDERR "  Match?($right_context_rule1, 1, $chart1_end) = $match_p\n";
			            next unless $match_p;
			         }
                                 my $right_context_rule2 = $ht{RIGHT2}->{$cost_rule_id};
			         if ($right_context_rule2) {
			            my $match_p = $this->right_context_match($right_context_rule2, *sd_ht, $chart2_id, $chart2_end);
				    # print STDERR "  Match?($right_context_rule2, 2, $chart2_end) = $match_p\n";
			            next unless $match_p;
			         }
			         my $cost = $ht{COST}->{$lang_code1o}->{$lang_code2o}->{$roman1}->{$roman2}->{$cost_rule_id};
			         my $preceding_cost = $sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_start}->{$chart2_start};
			         my $combined_cost = $preceding_cost + $cost;
			         my $old_cost = $sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
			         if ((! defined($old_cost)) || ($combined_cost < $old_cost)) {
			            $sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $combined_cost;
				    push(@chart2_starts, $chart2_end) unless $util->member($chart2_end, @chart2_starts);
			            $sd_ht{PREC_I}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $chart1_start;
			            $sd_ht{PREC_J}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $chart2_start;
			            $sd_ht{ROMAN1}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $roman1;
			            $sd_ht{ROMAN2}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $roman2;
			            $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{$chart1_end}->{$chart2_end}
			               = $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{$chart1_start}->{$chart2_start} . $roman1;
			            $sd_ht{COMB_LEFT_ROMAN2}->{$chart_comb_id}->{$chart1_end}->{$chart2_end}
			               = $sd_ht{COMB_LEFT_ROMAN2}->{$chart_comb_id}->{$chart1_start}->{$chart2_start} . $roman2;
				    $comb_left_roman1 = $sd_ht{COMB_LEFT_ROMAN1}->{$chart_comb_id}->{$chart1_end}->{$chart2_end};
				    # print STDERR "  Comb-left-roman1($chart_comb_id,$chart1_end,$chart2_end) = $comb_left_roman1\n";
			            $sd_ht{INCR_COST_IJ}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $cost;
			            $sd_ht{COST_RULE}->{$chart_comb_id}->{$chart1_end}->{$chart2_end} = $cost_rule_id;
			            print STDERR "  New cost $chart1_end/$chart2_end: $combined_cost (+$cost from $chart1_start/$chart2_start $roman1/$roman2)\n" if $verbose;
			         }
			      }
			   }
			}
		     }
		  }
	       }
	    }
	    $further_expansion_possible = 1
	       if $ht{RULE_STRING_HAS_EXPANSION}->{$lang_code1}->{$roman1}
	       || $ht{RULE_STRING_HAS_EXPANSION}->{""}->{$roman1};
	    # print STDERR "  further_expansion_possible: $further_expansion_possible (lc: $lang_code1 r1: $roman1) ***\n";
	 }
         # print STDERR "  last C1 $chart1_start-$chart1_end (@romans1)\n" unless $further_expansion_possible;
	 last unless $further_expansion_possible;
         $prev_further_expansion_possible = 1 if $further_expansion_possible;
      }
   }
   my $total_cost = $sd_ht{COST_IJ}->{$chart_comb_id}->{$chart1_end_pos}->{$chart2_end_pos};
   unless (defined($total_cost)) {
      $total_cost = 99.9999;
      $sd_ht{MISMATCH}->{$chart_comb_id} = 1;
   }
   return $total_cost;
}

sub print_sd_ht {
   local($this, *sd_ht, $chart1_id, $chart2_id, *OUT) = @_;

   print OUT "string-distance chart:\n";
   foreach $chart_id (($chart1_id, $chart2_id)) {
      print OUT "SD chart $chart_id:\n";
      foreach $from_linear_chart_pos (sort { $a <=> $b } keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}}) {
	 foreach $to_linear_chart_pos (sort { $a <=> $b } keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$from_linear_chart_pos}}) {
	    foreach $roman_char (sort keys %{$sd_ht{LIN_IJ_ROMAN}->{$chart_id}->{$from_linear_chart_pos}->{$to_linear_chart_pos}}) {
	       print OUT "  Lnode($from_linear_chart_pos-$to_linear_chart_pos): $roman_char\n";
	    }
	 }
      }
   }
}

sub print_chart_ht {
   local($this, *chart_ht, *OUT) = @_;

   print OUT "uroman chart:\n";
   foreach $start (sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AT}}) {
      foreach $end (sort { $a <=> $b } keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}}) {
	 foreach $node_id (keys %{$chart_ht{NODES_STARTING_AND_ENDING_AT}->{$start}->{$end}}) {
	    $roman_s = $chart_ht{NODE_ROMAN}->{$node_id};
	    print OUT "  Node $node_id ($start-$end): $roman_s\n";
	 }
      }
   }
}

sub normalize_string {
   local($this, $s) = @_;

#  $s =~ s/(\xE2\x80\x8C)//g; # delete zero width non-joiner
   $s =~ s/(\xE2\x80[\x93-\x94])/-/g; # en-dash, em-dash
   $s =~ s/([\x00-\x7F\xC0-\xFE][\x80-\xBF]*)\1+/$1$1/g; # shorten 3 or more occurrences of same character in a row to 2
   $s =~ s/[ \t]+/ /g;

   return $s;
}

my $string_distance_chart_id = 0;
sub string_distance_by_chart {
   local($this, $s1, $s2, $lang_code1, $lang_code2, *ht, *pinyin_ht, $control) = @_;

   $control = "" unless defined($control);
   %sd_ht = ();

   $s1 = $this->normalize_string($s1);
   my $lc_s1 = $utf8->extended_lower_case($s1);
   $string_distance_chart_id++;
   my $chart1_id = $string_distance_chart_id;
   *chart_ht = $romanizer->romanize($lc_s1, $lang_code1, "", *ht, *pinyin_ht, 0, "return chart", $chart1_id);
   $this->linearize_chart_points(*chart_ht, $chart1_id, *sd_ht);
   $this->expand_lin_ij_roman(*sd_ht, $chart1_id, $lang_code1, *ht);

   $s2 = $this->normalize_string($s2);
   my $lc_s2 = $utf8->extended_lower_case($s2);
   $string_distance_chart_id++;
   my $chart2_id = $string_distance_chart_id;
   *chart_ht = $romanizer->romanize($lc_s2, $lang_code2, "", *ht, *pinyin_ht, 0, "return chart", $chart2_id);
   $this->linearize_chart_points(*chart_ht, $chart2_id, *sd_ht);
   $this->expand_lin_ij_roman(*sd_ht, $chart2_id, $lang_code2, *ht);

   my $cost = $this->string_distance(*sd_ht, $chart1_id, $chart2_id, $lang_code1, $lang_code2, *ht, $control);
   return $cost;
}

my $n_quick_romanized_string_distance = 0;
sub quick_romanized_string_distance_by_chart {
   local($this, $s1, $s2, *ht, $control, $lang_code1, $lang_code2) = @_;

   # my $verbose = ($s1 eq "apit") && ($s2 eq "apet");
   # print STDERR "Start quick_romanized_string_distance_by_chart\n";
   $s1 = lc $s1;
   $s2 = lc $s2;
   $control = "" unless defined($control);
   $lang_code1 = "" unless defined($lang_code1);
   $lang_code2 = "" unless defined($lang_code2);
   my $cache_p = ($control =~ /cache/);
   my $total_cost;
   if ($cache_p) {
      $total_cost = $ht{CACHED_QRSD}->{$s1}->{$s2};
      if (defined($total_cost)) {
         return $total_cost;
      }
   }
   my @lang_codes1 = ($lang_code1 eq "") ? ("") : ($lang_code1, "");
   my @lang_codes2 = ($lang_code2 eq "") ? ("") : ($lang_code2, "");
   my $chart1_end_pos = length($s1);
   my $chart2_end_pos = length($s2);
   my %sd_ht = ();
   $sd_ht{COST_IJ}->{0}->{0} = 0;
   foreach $chart1_start ((0 .. $chart1_end_pos)) {
      foreach $chart1_end (($chart1_start .. $chart1_end_pos)) {
	 my $substr1 = substr($s1, $chart1_start, ($chart1_end-$chart1_start));
	 foreach $lang_code1o (@lang_codes1) {
	    foreach $lang_code2o (@lang_codes2) {
	       # next unless defined($ht{COST}->{$lang_code1o}->{$lang_code2o}->{$substr1});
            }
	 }
	 my @chart2_starts = (sort { $a <=> $b } keys %{$sd_ht{COST_IJ}->{$chart1_start}});
	 foreach $chart2_start (@chart2_starts) {
	    foreach $chart2_end (($chart2_start .. $chart2_end_pos)) {
	       my $substr2 = substr($s2, $chart2_start, ($chart2_end-$chart2_start));
	       foreach $lang_code1o (@lang_codes1) {
	          foreach $lang_code2o (@lang_codes2) {
		     if ($substr1 eq $substr2) {
			my $cost = 0;
	                my $preceding_cost = $sd_ht{COST_IJ}->{$chart1_start}->{$chart2_start};
			if (defined($preceding_cost)) {
		           my $combined_cost = $preceding_cost + $cost;
	                   my $old_cost = $sd_ht{COST_IJ}->{$chart1_end}->{$chart2_end};
	                   if ((! defined($old_cost)) || ($combined_cost < $old_cost)) {
		              $sd_ht{COST_IJ}->{$chart1_end}->{$chart2_end} = $combined_cost;
		              push(@chart2_starts, $chart2_end) unless $util->member($chart2_end, @chart2_starts);
		           }
			}
		     } else {
	                next unless defined($ht{COST}->{$lang_code1o}->{$lang_code2o}->{$substr1}->{$substr2});
	                my @cost_rule_ids = keys %{$ht{COST}->{$lang_code1o}->{$lang_code2o}->{$substr1}->{$substr2}};
	                my $best_cost = 99.99;
	                foreach $cost_rule_id (@cost_rule_ids) {
		           my $cost = $ht{COST}->{$lang_code1o}->{$lang_code2o}->{$substr1}->{$substr2}->{$cost_rule_id};
                           my $left_context_rule1 = $ht{LEFT1}->{$cost_rule_id};
			   next if $left_context_rule1
			        && (! (substr($s1, 0, $chart1_start) =~ /$left_context_rule1/));
                           my $left_context_rule2 = $ht{LEFT2}->{$cost_rule_id};
			   next if $left_context_rule2
			        && (! (substr($s2, 0, $chart2_start) =~ /$left_context_rule2/));
                           my $right_context_rule1 = $ht{RIGHT1}->{$cost_rule_id};
			   my $right_context1 = substr($s1, $chart1_end);
			   next if $right_context_rule1
			        && (! (($right_context1 =~ /^$right_context_rule1/)
			            || (($right_context_rule1 =~ /^\[[^\[\]]*\$/)
			             && ($right_context1 eq ""))));
                           my $right_context_rule2 = $ht{RIGHT2}->{$cost_rule_id};
			   my $right_context2 = substr($s2, $chart2_end);
			   next if $right_context_rule2
			        && (! (($right_context2 =~ /^$right_context_rule2/)
			            || (($right_context_rule2 =~ /^\[[^\[\]]*\$/)
			             && ($right_context2 eq ""))));
		           $best_cost = $cost if $cost < $best_cost;
	                   my $preceding_cost = $sd_ht{COST_IJ}->{$chart1_start}->{$chart2_start};
		           my $combined_cost = $preceding_cost + $cost;
	                   my $old_cost = $sd_ht{COST_IJ}->{$chart1_end}->{$chart2_end};
	                   if ((! defined($old_cost)) || ($combined_cost < $old_cost)) {
		              $sd_ht{COST_IJ}->{$chart1_end}->{$chart2_end} = $combined_cost;
		              push(@chart2_starts, $chart2_end) unless $util->member($chart2_end, @chart2_starts);
		           }
		        }
		     }
		  }
	       }
	    }
	 }
      }
   }
   $total_cost = $sd_ht{COST_IJ}->{$chart1_end_pos}->{$chart2_end_pos};
   $total_cost = 99.99 unless defined($total_cost);
   $ht{CACHED_QRSD}->{$s1}->{$s2} = $total_cost if $cache_p;
   $n_quick_romanized_string_distance++;
   return $total_cost;
}

sub get_n_quick_romanized_string_distance {
   return $n_quick_romanized_string_distance;
}

1;

