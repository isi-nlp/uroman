#!/usr/bin/env python

"""
Written by Ulf Hermjakob, USC/ISI  March 2024
uroman is a universal romanizer. It converts text in any script to the Latin alphabet.
This script is a Python reimplementation of an earlier Perl script.
This script is still newly under development and still under large-scale testing.
Compared to the original Perl version, this script does not offer full support for translating
numbers (e.g. 一万四千, ፲፱፻፸ and 𓆿𓍧𓎇𓏻) to ASCII numbers (e.g. 14000, 1970 and 4622).
It still needs a few language-specific adjustments for Tibetan, Gurmukhi, Khmer;
all-caps and multi-digit number handling for Braille.
It does not yet offer alternative romanizations for ambiguous sequences.
This script provides token-size caching (for faster runtimes).
Output formats include
  (1) best romanization string and
  (2) best romanization edges (incl. start and end positions with respect to the original string)
  (3) all edges (full lattice)
See below for 'sample calls' under main()
"""

from __future__ import annotations
import argparse
from collections import defaultdict
import cProfile
from memory_profiler import profile
import datetime
from enum import Enum
import gc
import json
import os
import pathlib
from pathlib import Path
import pstats
import regex
import sys
from typing import List, Optional, Tuple, Union
import unicodedata as ud

# UTILITIES


def timer(func):
    def wrapper(*args, **kwargs):
        start_time = datetime.datetime.now()
        print(f"Calling: {func.__name__}{args}")
        print(f"Start time: {start_time:%A, %B %d, %Y at %H:%M}")
        result = func(*args, **kwargs)
        end_time = datetime.datetime.now()
        time_diff = (end_time-start_time).total_seconds()
        print(f"End time: {end_time:%A, %B %d, %Y at %H:%M}")
        print(f"Duration: {time_diff} seconds")
        return result
    return wrapper


def slot_value_in_double_colon_del_list(line: str, slot: str, default: Optional = None) -> Optional[str]:
    """For a given slot, e.g. 'cost', get its value from a line such as '::s1 of course ::s2 ::cost 0.3' -> 0.3
    The value can be an empty string, as for ::s2 in the example above."""
    m = regex.match(fr'(?:.*\s)?::{slot}(|\s+\S.*?)(?:\s+::\S.*|\s*)$', line)
    return m.group(1).strip() if m else default


def has_value_in_double_colon_del_list(line: str, slot: str) -> bool:
    return isinstance(slot_value_in_double_colon_del_list(line, slot), str)


def dequote_string(s: str) -> str:
    if isinstance(s, str):
        m = regex.match(r'''\s*(['"“])(.*)(['"”])\s*$''', s)
        if m and ((m.group(1) + m.group(3)) in ("''", '""', '“”')):
            return m.group(2)
    return s


def last_chr(s: str) -> str:
    if len(s):
        return s[len(s)-1]
    else:
        ''


def ud_numeric(char: str) -> Union[int, float, None]:
    try:
        num_f = ud.numeric(char)
        return int(num_f) if num_f.is_integer() else num_f
    except (ValueError, TypeError):
        return None


def robust_str_to_num(num_s: str, filename: str = None, line_number: Optional[int] = None, silent: bool = False) \
        -> Union[int, float, None]:
    if isinstance(num_s, str):
        try:
            return float(num_s) if "." in num_s else int(num_s)
        except ValueError:
            if not silent:
                sys.stderr.write(f'Cannot convert "{num_s}" to a number')
                if line_number:
                    sys.stderr.write(f' line: {line_number}')
                if filename:
                    sys.stderr.write(f' file: {filename}')
                sys.stderr.write(f'\n')
    elif isinstance(num_s, float) or isinstance(num_s, int):
        return num_s
    return None


def args_get(key: str, args: Optional[argparse.Namespace] = None):
    return vars(args)[key] if args and (key in args) else None


class DictClass:
    def __init__(self, **kw_args):
        for kw_arg in kw_args:
            value = kw_args[kw_arg]
            if not (value in (None, [], False)):
                self.__dict__[kw_arg] = value

    def __repr__(self):
        return str(self.__dict__)

    def __getitem__(self, key, default=None):
        return self.__dict__[key] if key in self.__dict__ else default

    def __bool__(self):
        return len(self.__dict__) > 0


class RomRule(DictClass):
    # key: source string
    # typical attributes: s (source), t (target), prov (provenance), lcodes (language codes)
    # t_alts=t_alts (target alternatives), use_only_at_start_of_word, dont_use_at_start_of_word,
    # use_only_at_end_of_word, dont_use_at_end_of_word, use_only_for_whole_word
    pass


class Script(DictClass):
    # key: lower case script_name
    # typical attributes: script_name, direction, abugida_default_vowels, alt_script_names, languages
    pass


class RomFormat(Enum):
    """Output format of romanization"""
    STR = 'str'          # simple string
    EDGES = 'edges'      # list of edges (includes character offsets in original string)
    LATTICE = 'lattice'  # lattice including alternative edges

    def __str__(self):
        return self.value


class Uroman:
    """This class loads and maintains uroman data independent of any specific text corpus.
    Typically, only a single instance will be used. (In contrast to multiple lattice instances, one per text.)
    Methods include some testing. And finally methods to romanize a string (romanize_string()) or an entire file
    (romanize_file())."""
    def __init__(self, data_dir: Path, **args):  # args: load_log, rebuild_ud_props
        self.data_dir = data_dir
        self.rom_rules = defaultdict(list)
        self.scripts = defaultdict(Script)
        self.dict_bool = defaultdict(bool)
        self.dict_str = defaultdict(str)
        self.dict_int = defaultdict(int)
        self.dict_num = defaultdict(lambda: None)  # values are int (most common), float, or str ("1/2")
        self.dict_set = defaultdict(set)
        gc.disable()
        self.load_resource_files(data_dir, args.get('load_log', False), args.get('rebuild_ud_props', False))
        gc.enable()
        self.hangul_rom = {}
        self.rom_cache = {}   # key: (s, lcode) value: t
        self.stats = defaultdict(int)  # stats, e.g. for unprocessed numbers

    def second_rom_filter(self, c: str, rom: str, name: Optional[str]) -> Tuple[Optional[str], str]:
        """Much of this code will eventually move the old Perl code to generate cleaner primary data"""
        if rom and (' ' in rom):
            if name is None:
                name = self.chr_name(c)
            if "MYANMAR VOWEL SIGN KAYAH" in name:
                if m := regex.search(r'kayah\s+(\S+)\s*$', rom):
                    return m.group(1), name
            if "MENDE KIKAKUI SYLLABLE" in name:
                if m := regex.search(r'm\d+\s+(\S+)\s*$', rom):
                    return m.group(1), name
            if regex.search(r'\S\s+\S', rom):
                return c, name
        return None, name

    def load_rom_file(self, filename: str, provenance: str, file_format: str = None, load_log: bool = True):
        """Reads in and processes the 3 main romanization data files: (1) romanization-auto-table.txt
        which was automatically generated from UnicodeData.txt (2) UnicodeDataOverwrite.txt that "corrects"
        some entries in romanization-auto-table.txt and (3) romanization-table.txt which was largely manually
        created and allows complex romanization rules, some for specific languages, some for specific contexts."""
        n_entries = 0
        try:
            f = open(filename)
        except FileNotFoundError:
            sys.stderr.write(f'Cannot open file {filename}\n')
            return
        with f:
            for line_number, line in enumerate(f, 1):
                if line.startswith('#'):
                    continue
                if regex.match(r'^\s*$', line):  # blank line
                    continue
                line = regex.sub(r'\s{2,}#.*$', '', line)
                if file_format == 'u2r':
                    u = dequote_string(slot_value_in_double_colon_del_list(line, 'u'))
                    try:
                        cp = int(u, 16)
                        s = chr(cp)
                    except ValueError:
                        continue
                    t = dequote_string(slot_value_in_double_colon_del_list(line, 'r'))
                    if name := slot_value_in_double_colon_del_list(line, 'name'):
                        self.dict_str[('name', s)] = name
                    if pic := slot_value_in_double_colon_del_list(line, 'pic'):
                        self.dict_str[('pic', s)] = pic
                    if tone_mark := slot_value_in_double_colon_del_list(line, 'tone-mark'):
                        self.dict_str[('tone-mark', s)] = tone_mark
                    if syllable_info := slot_value_in_double_colon_del_list(line, 'syllable-info'):
                        self.dict_str[('syllable-info', s)] = syllable_info
                else:
                    s = dequote_string(slot_value_in_double_colon_del_list(line, 's'))
                    t = dequote_string(slot_value_in_double_colon_del_list(line, 't'))
                if (num_s := slot_value_in_double_colon_del_list(line, 'num')) is not None:
                    num = robust_str_to_num(num_s)
                    self.dict_num[s] = (num_s if (num is None) else num)
                lcode_s = slot_value_in_double_colon_del_list(line, 'lcode')
                lcodes = regex.split(r'[,;]\s*', lcode_s) if lcode_s else []
                use_only_at_start_of_word = has_value_in_double_colon_del_list(line, 'use-only-at-start-of-word')
                dont_use_at_start_of_word = has_value_in_double_colon_del_list(line, 'dont-use-at-start-of-word')
                use_only_at_end_of_word = has_value_in_double_colon_del_list(line, 'use-only-at-end-of-word')
                dont_use_at_end_of_word = has_value_in_double_colon_del_list(line, 'dont-use-at-end-of-word')
                use_only_for_whole_word = has_value_in_double_colon_del_list(line, 'use-only-for-whole-word')
                num_s = slot_value_in_double_colon_del_list(line, 'num')
                num = robust_str_to_num(num_s, filename, line_number, silent=False)
                t_alt_s = slot_value_in_double_colon_del_list(line, 't-alt')
                t_alts = regex.split(r'[,;]\s*', t_alt_s) if t_alt_s else []
                t_mod, name2 = self.second_rom_filter(s, t, None)
                if t_mod and (t_mod != t):
                    if t != s:
                        pass  # sys.stderr.write(f'UPDATE: {s} {name2} {t} -> {t_mod}\n')
                    t = t_mod
                if s is not None and ((t is not None) or (num is not None)):
                    for prefix_len in range(1, len(s)+1):
                        self.dict_bool[('s-prefix', s[:prefix_len])] = True
                    n_entries += 1
                    # if regex.match(r'[\u2800-\u28FF]', s): print("Braille", s, t)
                    restrictions = [lcodes, use_only_at_start_of_word, dont_use_at_start_of_word,
                                    use_only_at_end_of_word, dont_use_at_end_of_word, use_only_for_whole_word]
                    n_restrictions = len([restr for restr in restrictions if restr])
                    provenance2 = provenance
                    if (t is None) and (num is not None) and (provenance2 == "rom"):
                        provenance2 = "num"
                    new_rom_rule = RomRule(s=s, t=t, prov=provenance2, lcodes=lcodes, t_alts=t_alts, num=num,
                                           use_only_at_start_of_word=use_only_at_start_of_word,
                                           dont_use_at_start_of_word=dont_use_at_start_of_word,
                                           use_only_at_end_of_word=use_only_at_end_of_word,
                                           dont_use_at_end_of_word=dont_use_at_end_of_word,
                                           use_only_for_whole_word=use_only_for_whole_word,
                                           n_restr=n_restrictions)
                    old_rom_rules = self.rom_rules[s]
                    if ((len(old_rom_rules) == 1) and (old_rom_rules[0]['prov'] in ('ud', 'ow'))
                            and not (lcodes or use_only_at_start_of_word or dont_use_at_start_of_word
                                     or use_only_at_end_of_word or dont_use_at_end_of_word
                                     or use_only_for_whole_word)):
                        self.rom_rules[s] = [new_rom_rule]  # overwrite
                    else:
                        self.rom_rules[s].append(new_rom_rule)
        if load_log:
            sys.stderr.write(f'Loaded {n_entries} from {filename}\n')

    def load_script_file(self, filename: str, load_log: bool = True):
        """Reads in (typically from Scripts.txt) information about various scripts such as Devanagari,
        incl. information such as the default abugida vowel letter (e.g. "a")."""
        n_entries, max_n_script_name_components = 0, 0
        try:
            f = open(filename)
        except FileNotFoundError:
            sys.stderr.write(f'Cannot open file {filename}\n')
            return
        with f:
            for line_number, line in enumerate(f, 1):
                if line.startswith('#'):
                    continue
                if regex.match(r'^\s*$', line):  # blank line
                    continue
                line = regex.sub(r'\s{2,}#.*$', '', line)
                if script_name := slot_value_in_double_colon_del_list(line, 'script-name'):
                    lc_script_name = script_name.lower()
                    if lc_script_name in self.scripts:
                        sys.stderr.write(f'** Ignoring duplicate script "{script_name}" '
                                         f'in line {line_number} of {filename}\n')
                    else:
                        n_entries += 1
                        direction = slot_value_in_double_colon_del_list(line, 'direction')
                        abugida_default_vowel_s = slot_value_in_double_colon_del_list(line,
                                                                                      'abugida-default-vowel')
                        abugida_default_vowels = regex.split(r'[,;]\s*', abugida_default_vowel_s) \
                            if abugida_default_vowel_s else []
                        alt_script_name_s = slot_value_in_double_colon_del_list(line, 'alt-script-name')
                        alt_script_names = regex.split(r'[,;]\s*', alt_script_name_s) if alt_script_name_s else []
                        language_s = slot_value_in_double_colon_del_list(line, 'language')
                        languages = regex.split(r'[,;]\s*', language_s) if language_s else []
                        new_script = Script(script_name=script_name, alt_script_names=alt_script_names,
                                            languages=languages, direction=direction,
                                            abugida_default_vowels=abugida_default_vowels)
                        self.scripts[lc_script_name] = new_script
                        for language in languages:
                            self.dict_set[('scripts', language)].add(script_name)
                        for alt_script_name in alt_script_names:
                            lc_alt_script_name = alt_script_name.lower()
                            if lc_alt_script_name in self.scripts:
                                sys.stderr.write(f'** Ignoring duplicate alternative script name "{script_name}" '
                                                 f'in line {line_number} of {filename}\n')
                            else:
                                self.scripts[lc_alt_script_name] = new_script
                    n_script_name_components = len(script_name.split())
                    if n_script_name_components > max_n_script_name_components:
                        max_n_script_name_components = n_script_name_components
        if max_n_script_name_components:
            self.dict_int['max_n_script_name_components'] = max_n_script_name_components
        if load_log:
            sys.stderr.write(f'Loaded {n_entries} script descriptions from {filename}'
                             f' (max_n_scripts_name_components: {max_n_script_name_components})\n')

    def extract_script_name(self, script_name_plus: str, full_char_name: str = None) -> Optional[str]:
        """Using info from Scripts.txt, this script selects the script name from a Unicode,
        e.g. given "OLD HUNGARIAN CAPITAL LETTER A", extract "Old Hungarian"."""
        if full_char_name and script_name_plus == full_char_name:
            return None
        while script_name_plus:
            if script_name_plus.lower() in self.scripts:
                if script := self.scripts[script_name_plus.lower()]:
                    if script_name := script['script_name']:
                        return script_name
            script_name_plus = regex.sub(r'\s*\S*\s*$', '', script_name_plus)
        return None

    def load_unicode_data_props(self, filename: str, load_log: bool = True):
        """Loads Unicode derived data from (1) UnicodeDataProps.txt, (2) UnicodeDataPropsHangul.txt
        and UnicodeDataPropsCJK.txt with a list of valid script-specific characters."""
        n_script, n_script_char, n_script_vowel_sign, n_script_virama = 0, 0, 0, 0
        try:
            f = open(filename)
        except FileNotFoundError:
            sys.stderr.write(f'Cannot open file {filename}\n')
            return
        with f:
            for line_number, line in enumerate(f, 1):
                if line.startswith('#'):
                    continue
                if regex.match(r'^\s*$', line):  # blank line
                    continue
                line = regex.sub(r'\s{2,}#.*$', '', line)
                if script_name := slot_value_in_double_colon_del_list(line, 'script-name'):
                    n_script += 1
                    for char in slot_value_in_double_colon_del_list(line, 'char', []):
                        self.dict_str[('script', char)] = script_name
                        n_script_char += 1
                    for char in slot_value_in_double_colon_del_list(line, 'vowel-sign', []):
                        self.dict_bool[('is-vowel-sign', char)] = True
                        n_script_vowel_sign += 1
                    for char in slot_value_in_double_colon_del_list(line, 'sign-virama', []):
                        self.dict_bool[('is-virama', char)] = True
                        n_script_virama += 1
        if load_log:
            sys.stderr.write(f'Loaded from {filename} mappings of {n_script_char:,d} characters '
                             f'to {n_script} script{"" if n_script == 1 else "s"}')
            if n_script_vowel_sign or n_script_virama:
                sys.stderr.write(f', with a total of {n_script_vowel_sign} vowel signs '
                                 f'and {n_script_virama} viramas')
            sys.stderr.write('.\n')

    @staticmethod
    def de_accent_pinyin(s: str) -> str:
        """De-accents a string from "liú" to "liu" and "ü" to "u" (to help process file Chinese_to_Pinyin.txt)."""
        result = ''
        for char in s:
            if decomp := ud.decomposition(char).split():
                try:
                    decomp_chars = [chr(int(x, 16)) for x in decomp]
                    letters = [x for x in decomp_chars if ud.category(x).startswith('L')]
                except ValueError:
                    sys.stderr.write(f'Cannot decode {decomp}\n')
                    continue
                if len(letters) == 1:
                    result += letters[0]
                else:
                    sys.stderr.write(f'Cannot decode {decomp} (expected 1 letter)\n')
            else:
                result += char
        result = result.replace('ü', 'u')
        return result

    def load_chinese_pinyin_file(self, filename: str, load_log: bool = True):
        """Loads file Chinese_to_Pinyin.txt which maps Chinese characters to their Latin form."""
        n_entries = 0
        try:
            f = open(filename)
        except FileNotFoundError:
            sys.stderr.write(f'Cannot open file {filename}\n')
            return
        with f:
            for line_number, line in enumerate(f, 1):
                if line.startswith('#'):
                    continue
                if regex.match(r'^\s*$', line):  # blank line
                    continue
                try:
                    chinese, pinyin = line.rstrip().split()
                    rom = self.de_accent_pinyin(pinyin)
                except ValueError:
                    sys.stderr.write(f'Cannot process line {line_number} in file {filename}: {line}')
                else:
                    s = chinese
                    new_rom_rule = RomRule(s=s, t=rom, prov='rom pinyin', lcodes=[])
                    self.rom_rules[chinese].append(new_rom_rule)
                    for prefix_len in range(1, len(s)+1):
                        self.dict_bool[('s-prefix', s[:prefix_len])] = True
                    n_entries += 1
        if load_log:
            sys.stderr.write(f'Loaded {n_entries} script descriptions from {filename}\n')

    @staticmethod
    def add_char_to_rebuild_unicode_data_dict(d: dict, script_name: str, prop_class: str, char: str):
        d['script-names'].add(script_name)
        key = (script_name, prop_class)
        if key in d:
            d[key].append(char)
        else:
            d[key] = [char]

    def rebuild_unicode_data_props(self, out_filename: str, cjk: str = None, hangul: str = None):
        """This functions rebuilds UnicodeDataProps*.txt This might be useful when a new UnicodeData.txt
        version is released, or additional information is extracted from Unicode to UnicodeDataProps.txt
        Regular users normally never have to call this function."""
        d = {'script-names': set()}
        n_script_refs = 0
        codepoint = -1
        prop_classes = {'char'}
        while codepoint < 0xF0000:
            codepoint += 1
            c = chr(codepoint)
            if not (char_name := self.chr_name(c)):
                continue
            for prop_name_comp2 in ('VOWEL SIGN',
                                    ('SIGN VIRAMA', 'SIGN ASAT', 'AL-LAKUNA', 'SIGN COENG', 'SIGN PAMAAEH')):
                if prop_name_comp2 and isinstance(prop_name_comp2, tuple):
                    prop_list = prop_name_comp2
                else:
                    prop_list = (prop_name_comp2,)
                for prop_name_comp in prop_list:
                    prop_class = prop_list[0].lower().replace(' ', '-')
                    if prop_class not in prop_classes:
                        prop_classes.add(prop_class)
                    script_name_cand = regex.sub(fr'\s+{prop_name_comp}\b.*$', '', char_name)
                    if script_name := self.extract_script_name(script_name_cand, char_name):
                        self.add_char_to_rebuild_unicode_data_dict(d, script_name, prop_class, c)
            script_name_cand = regex.sub(r'\s+(CONSONANT|LETTER|LIGATURE|SIGN|SYLLABLE|SYLLABICS|VOWEL|'
                                         r'IDEOGRAPH|POINT|ACCENT|CHARACTER)\b.*$', '',
                                         char_name)
            if script_name := self.extract_script_name(script_name_cand, char_name):
                self.add_char_to_rebuild_unicode_data_dict(d, script_name, 'char', c)
                n_script_refs += 1
        # print(sorted(d['script-names']))
        prop_classes = sorted(prop_classes)
        out_filenames = [x for x in [out_filename, cjk, hangul] if x]
        cjk2 = cjk if cjk else out_filename
        hangul2 = hangul if hangul else out_filename
        for out_file in out_filenames:
            try:
                f_out = open(out_file, 'w')
            except OSError:
                sys.stderr.write(f'Cannot write to file {out_file}\n')
                continue
            with f_out:
                for script_name in sorted(d['script-names']):
                    if script_name == 'CJK':
                        if out_file != cjk2:
                            continue
                    elif script_name == 'Hangul':
                        if out_file != hangul2:
                            continue
                    else:
                        if out_file != out_filename:
                            continue
                    prop_components = [f"::script-name {script_name}"]
                    for prop_class in prop_classes:
                        key = (script_name, prop_class)
                        if key in d:
                            if chars := ''.join(d[key]):
                                if prop_class in ('char',):
                                    prop_components.append(f"::n-{prop_class} {len(chars)}")
                                prop_components.append(f"::{prop_class} {chars}")
                    f_out.write(f"{' '.join(prop_components)}\n")
        sys.stderr.write(f"Rebuilt {out_filenames} with {n_script_refs} characters "
                         f"for {len(d['script-names'])} scripts.\n")

    def load_resource_files(self, data_dir: Path, load_log: bool = False, rebuild_ud_props: bool = False):
        """Loads all resource files needed for romanization."""
        data_dir = data_dir
        if not isinstance(data_dir, pathlib.Path):
            sys.stderr.write(f'Error: data_dir is of {type(data_dir)}, not a Path.\n'
                             f'       Cannot load any resource files.\n')
            return
        self.load_rom_file(os.path.join(data_dir, "romanization-auto-table.txt"),
                           'ud', file_format='rom', load_log=load_log)
        self.load_rom_file(os.path.join(data_dir, "UnicodeDataOverwrite.txt"),
                           'ow', file_format='u2r', load_log=load_log)
        self.load_rom_file(os.path.join(data_dir, "romanization-table.txt"),
                           'man', file_format='rom', load_log=load_log)
        self.load_chinese_pinyin_file(os.path.join(data_dir, "Chinese_to_Pinyin.txt"), load_log=load_log)
        self.load_script_file(os.path.join(data_dir, "Scripts.txt"), load_log=load_log)
        if rebuild_ud_props:
            self.rebuild_unicode_data_props(os.path.join(data_dir, "UnicodeDataProps.txt"),
                                            cjk=os.path.join(data_dir, "UnicodeDataPropsCJK.txt"),
                                            hangul=os.path.join(data_dir, "UnicodeDataPropsHangul.txt"))
        for base_file in ("UnicodeDataProps.txt", "UnicodeDataPropsCJK.txt", "UnicodeDataPropsHangul.txt"):
            self.load_unicode_data_props(os.path.join(data_dir, base_file), load_log=load_log)

    def unicode_hangul_romanization(self, s: str, pass_through_p: bool = False):
        """Special algorithmic solution to convert (Korean) Hangul characters to the Latin alphabet."""
        if cached_rom := self.hangul_rom.get(s, None):
            return cached_rom
        leads = "g gg n d dd r m b bb s ss - j jj c k t p h".split()
        vowels = "a ae ya yae eo e yeo ye o wa wai oe yo u weo we wi yu eu yi i".split()
        tails = "- g gg gs n nj nh d l lg lm lb ls lt lp lh m b bs s ss ng j c k t p h".split()
        result = ""
        for c in s:
            cp = ord(c)
            if 0xAC00 <= cp <= 0xD7A3:
                code = cp - 0xAC00
                lead_index = int(code / (28 * 21))
                vowel_index = int(code / 28) % 21
                tail_index = code % 28
                rom = leads[lead_index] + vowels[vowel_index] + tails[tail_index]
                rom = rom.replace('-', '')
                self.hangul_rom[c] = rom
                result += rom
            elif pass_through_p:
                result += c
        return result

    @staticmethod
    def char_is_nonspacing_mark(s) -> bool:
        """ Checks whether a character is a nonspacing mark, e.g. combining accents, points, vowel signs"""
        return (len(s) == 1) and (ud.category(s) == 'Mn')

    @staticmethod
    def char_is_format_char(s) -> bool:
        """ Checks whether a character is a formatting character, e.g. a zero-with joiner/non-joiner"""
        return (len(s) == 1) and (ud.category(s) == 'Cf')

    @staticmethod
    def char_is_space_separator(s) -> bool:
        """ Checks whether a character is a space,
            e.g. ' ', non-breakable space, en space, ideographic (Chinese) space, Ogham space mark
            but excluding \t, \r, \n"""
        return (len(s) == 1) and (ud.category(s) == 'Zs')

    def chr_name(self, char: str) -> str:
        try:
            return ud.name(char)
        except (ValueError, TypeError):
            if name := self.dict_str[('name', char)]:
                return name
        return ''

    def chr_script_name(self, char: str) -> str:
        return self.dict_str[('script', char)]

    def test_output_of_selected_scripts_and_rom_rules(self):
        """Low level test function that checks and displays romanization information."""
        output = ''
        for s in ("Oriya", "Chinese"):
            d = self.scripts[s.lower()]
            output += f'SCRIPT {s} {d}\n'
        for s in ('ƿ', 'β', 'и', 'μπ', '⠹', '亿', 'ちょ', 'и', ):
            d = self.rom_rules[s]
            output += f'DICT {s} {d}\n'
        for s in ('ƿ', 'β', 'न', 'ु'):
            output += f'SCRIPT-NAME {s} {self.chr_script_name(s)}\n'
        for s in ('万', '\uF8F7', '\U00013368', '\U0001308B', '\u0E48', '\u0E40'):
            name = self.chr_name(s)
            num = self.dict_num[s]
            pic = self.dict_str[('pic', s)]
            tone_mark = self.dict_str[('tone-mark', s)]
            syllable_info = self.dict_str[('syllable-info', s)]
            output += f'PROPS {s}'
            if name:
                output += f'  name: {name}'
            if num:
                output += f'  num: {num} ({type(num).__name__})'
            if pic:
                output += f'  pic: {pic}'
            if tone_mark:
                output += f'  tone-mark: {tone_mark}'
            if syllable_info:
                output += f'  syllable-info: {syllable_info}'
            output += '\n'
        print(output)

    def test_romanization(self, **args):
        """A few full cases of romanization testing."""
        tests = [('ألاسكا', None), ('यह एक अच्छा अनुवाद है.', 'hin'), ('ちょっとまってください', 'kor'),
                 ('Μπανγκαλόρ', 'ell'), ('Зеленський', 'ukr'), ('കേരളം', 'mal')]
        for test in tests:
            s = test[0]
            lcode = test[1] if len(test) >= 2 else None
            rom = self.romanize_string(s, lcode=lcode, **args)
            sys.stderr.write(f'ROM {s} -> {rom}\n')
        n_alerts = 0
        codepoint = -1
        while codepoint < 0xF0000:
            codepoint += 1
            c = chr(codepoint)
            rom = self.romanize_string(c)
            if regex.search(r'\s', rom) and regex.search(r'\S', rom):
                name = self.chr_name(c)
                sys.stderr.write(f'U+{codepoint:04X} {c} {name}  {rom}\n')
                n_alerts += 1
        sys.stderr.write(f'{n_alerts} alerts for roms with spaces\n')

    def romanize_file(self, input_filename: Optional[str] = None, output_filename: Optional[str] = None,
                      lcode: Optional[str] = None, direct_input: List[str] = None, **args):
        """Script to apply romanization to an entire file. Input and output files needed.
        Language code (lcode) recommended."""
        f_in_to_be_closed, f_out_to_be_closed = False, False
        if direct_input and (input_filename is None):
            f_in = direct_input  # list of lines
        elif isinstance(input_filename, str):
            try:
                f_in = open(input_filename)
                f_in_to_be_closed = True
            except OSError:
                sys.stderr.write(f'Error in romanize_file: Cannot open file {input_filename}\n')
                f_in = None
        elif input_filename is None:
            f_in = sys.stdin
        else:
            sys.stderr.write(f"Error in romanize_file: argument 'input_filename' {input_filename} "
                             f"is of wrong type: {type(input_filename)} (should be str)\n")
            f_in = None
        if isinstance(output_filename, str):
            try:
                f_out = open(str(output_filename), 'w')
                f_out_to_be_closed = True
            except OSError:
                sys.stderr.write(f'Error in romanize_file: Cannot write to file {output_filename}\n')
                f_out = None
        elif output_filename is None:
            f_out = sys.stdout
        else:
            sys.stderr.write(f"Error in romanize_file: argument 'output_filename' {output_filename} "
                             f"is of wrong type: {type(output_filename)} (should be str)\n")
            f_out = None
        if f_in and f_out:
            max_lines = args.get('max_lines', None)
            progress_dots_output = False
            for line_number, line in enumerate(f_in, 1):
                if m := regex.match(r'(::lcode\s+)([a-z]{3})(\s+)(.*?)\s*$', line):
                    lcode_kw, lcode2, space, snt = m.group(1, 2, 3, 4)
                    rom_result = self.romanize_string(snt, lcode2 or lcode, **args)
                    if args.get('rom_format', None) == RomFormat.STR:
                        lcode_prefix = f"{lcode_kw}{lcode2}{space}"
                        f_out.write(lcode_prefix + rom_result + '\n')
                    else:
                        lcode_prefix = f'[0, 0, "", "lcode: {lcode2}"]'  # meta edge with lcode info
                        prefixed_edges = [lcode_prefix] + self.romanize_string(snt, lcode2 or lcode, **args)
                        f_out.write(Edge.json_str(prefixed_edges) + '\n')
                else:
                    f_out.write(Edge.json_str(self.romanize_string(line.rstrip(), lcode, **args)) + '\n')
                if line_number % 100 == 0:
                    if line_number % 1000 == 0:
                        sys.stderr.write(str(line_number))
                    else:
                        sys.stderr.write('.')
                    progress_dots_output = True
                    sys.stderr.flush()
                    gc.collect()
                if max_lines and line_number >= max_lines:
                    break
            if progress_dots_output:
                sys.stderr.write('\n')
                sys.stderr.flush()
        if f_in_to_be_closed:
            f_in.close()
        if f_out_to_be_closed:
            f_out.close()

    @staticmethod
    def apply_any_offset_to_cached_rom_result(cached_rom_result: Union[str, List[Edge]], offset: int = 0) \
            -> Union[str, List[Edge]]:
        if isinstance(cached_rom_result, str):
            return cached_rom_result
        elif offset == 0:
            return cached_rom_result
        else:
            return [Edge(edge.start + offset, edge.end + offset, edge.txt, edge.type) for edge in cached_rom_result]

    def romanize_string_core(self, s: str, lcode: Optional[str], rom_format: RomFormat, cache_p: bool,
                             offset: int = 0, **args) -> Union[str, List[Edge]]:
        """Script to support token-by-token romanization with caching for higher speed."""
        if cache_p:
            cached_rom = self.rom_cache.get((s, lcode, rom_format), None)
            if cached_rom is not None:
                return self.apply_any_offset_to_cached_rom_result(cached_rom, offset)
        lat = Lattice(s, uroman=self, lcode=lcode)
        lat.add_romanization(**args)
        lat.add_numbers(self)
        lat.add_rom_fall_back_singles(self)
        if rom_format == RomFormat.LATTICE:
            all_edges = lat.all_edges(0, len(s))
            if cache_p:
                self.rom_cache[(s, lcode, rom_format)] = all_edges
            result = self.apply_any_offset_to_cached_rom_result(all_edges, offset)
        else:
            best_edges = lat.best_rom_edge_path(0, len(s))
            if rom_format == RomFormat.EDGES:
                if cache_p:
                    self.rom_cache[(s, lcode, rom_format)] = best_edges
                result = self.apply_any_offset_to_cached_rom_result(best_edges, offset)
            else:
                rom = lat.edge_path_to_surf(best_edges)
                del lat
                if cache_p:
                    self.rom_cache[(s, lcode, rom_format)] = rom
                result = rom
        return result

    def romanize_string(self, s: str, lcode: Optional[str] = None, rom_format: RomFormat = RomFormat.STR, **args) \
            -> Union[str, List[Edge]]:
        """Main entry point for romanizing a string. Recommended argument: lcode (language code).
        recursive only used for development.
        Method returns a string or a list of edges (with start and end offsets)."""
        lcode = lcode or args.get('lcode', None)
        # print('rom::', s, 'lcode:', lcode, 'print-lattice:', print_lattice_p)

        # with caching (for string format output only for now)
        if cache_p := not args.get('no_caching', False):
            rest, offset = s, 0
            result = '' if rom_format == RomFormat.STR else []
            while m3 := regex.match(r'(.*?)([.,; ]*[ 。][.,; ]*)(.*)$', rest):
                pre, delimiter, rest = m3.group(1, 2, 3)
                result += self.romanize_string_core(pre, lcode, rom_format, cache_p, offset, **args)
                offset += len(pre)
                result += self.romanize_string_core(delimiter, lcode, rom_format, cache_p, offset, **args)
                offset += len(delimiter)
            result += self.romanize_string_core(rest, lcode, rom_format, cache_p, offset, **args)
            return result
        else:
            return self.romanize_string_core(s, lcode, rom_format, cache_p, 0, **args)


class Edge:
    """This class defines edges that span part of a sentence with a specific romanization.
    There might be multiple edges for a given span. The edges in turn are part of the
    romanization lattice."""
    def __init__(self, start: int, end: int, s: str, annotation: str = None):
        self.start = start
        self.end = end
        self.txt = s
        self.type = annotation

    def __str__(self):
        return f'[{self.start}-{self.end}] {self.txt} ({self.type})'

    def __repr__(self):
        return str(self)

    def json(self) -> str:  # start - end - text - annotation
        return json.dumps([self.start, self.end, self.txt, self.type])

    @staticmethod
    def json_str(rom_result: Union[List[Edge], str]) -> str:
        if isinstance(rom_result, str):
            return rom_result
        else:
            result = '['
            for edge in rom_result:
                if isinstance(edge, Edge):
                    result += edge.json()
                else:
                    result += str(edge)
            result += ']'
            return result


class Lattice:
    """Lattice for a specific romanization instance. Has edges."""
    def __init__(self, s: str, uroman: Uroman, lcode: str = None):
        self.s = s
        self.lcode = lcode
        self.lattice = defaultdict(set)
        self.max_vertex = len(s)
        self.uroman = uroman
        self.props = {}

    def add_edge(self, edge: Edge):
        self.lattice[(edge.start, edge.end)].add(edge)
        self.lattice[(edge.start, 'right')].add(edge.end)
        self.lattice[(edge.end, 'left')].add(edge.start)

    def __str__(self):
        edges = []
        for start in range(self.max_vertex):
            for end in self.lattice[(start, 'right')]:
                for edge in self.lattice[(start, end)]:
                    edges.append(f'[{start}-{end}] {edge.txt} ({edge.type})')
        return ' '.join(edges)

    def is_at_start_of_word(self, position: int) -> bool:
        # return not regex.match(r'(?:\pL|\pM)', self.s[position-1:position])
        end = position
        if (preceded_by_alpha := self.props.get(('preceded_by_alpha', end), None)) in (True, False):
            return not preceded_by_alpha
        for start in self.lattice[(end, 'left')]:
            for edge in self.lattice[(start, end)]:
                if len(edge.txt) and edge.txt[-1].isalpha():
                    self.props[('preceded_by_alpha', position)] = True
                    return False
        self.props[('preceded_by_alpha', position)] = False
        return True

    def is_at_end_of_word(self, position: int) -> bool:
        if (cached_followed_by_alpha := self.props.get(('followed_by_alpha', position), None)) in (True, False):
            return not cached_followed_by_alpha
        start = position
        while (start+1 < self.max_vertex) \
                and self.uroman.char_is_nonspacing_mark(self.s[start]) \
                and ('NUKTA' in self.uroman.chr_name(self.s[start])):
            start += 1
        for end in range(start + 1, self.max_vertex + 1):
            s = self.s[start:end]
            if not self.uroman.dict_bool[('s-prefix', s)]:
                break
            for rom_rule in self.uroman.rom_rules[s]:
                rom = rom_rule['t']
                if regex.search(r'\pL', rom):
                    self.props[('followed_by_alpha', position)] = True
                    return False
        self.props[('followed_by_alpha', position)] = False
        return True

    def romanization_by_first_rule(self, s) -> Optional[str]:
        try:
            return self.uroman.rom_rules[s][0]['t']
        except IndexError:
            return None

    def expand_rom_with_special_chars(self, rom: str, start: int, end: int, **_args) \
            -> Tuple[str, int, int, Optional[str]]:
        """This method contains a number of special romanization heuristics that typically modify
        an existing or preliminary edge based on context."""
        orig_start = start
        uroman = self.uroman
        full_string = self.s
        annot = None
        if rom == '':
            return rom, start, end, None
        prev_char = (full_string[start-1] if start >= 1 else '')
        first_char = full_string[start]
        last_char = full_string[end-1]
        next_char = (full_string[end] if end < len(full_string) else '')
        # \u2820 is the Braille character indicating that the next letter is upper case
        if (prev_char == '\u2820') and regex.match(r'[a-z]', rom):
            return rom[0].upper() + rom[1:], start-1, end, 'rom exp'
        # Normalize multi-upper case THessalonike -> Thessalonike, but don't change THESSALONIKE
        if start+1 == end and rom.isupper() and next_char.islower():
            rom = rom.capitalize()
        # Japanese small tsu used as consonant doubler:
        if (prev_char and prev_char in 'っッ') \
                and (uroman.chr_script_name(prev_char) == uroman.chr_script_name(prev_char)) \
                and (m_double_consonant := regex.match(r'(ch|[bcdfghjklmnpqrstwz])', rom)):
            # return m_double_consonant.group(1).replace('ch', 't') + rom, start-1, end, 'rom exp'
            # expansion might additional apply to the right
            rom = m_double_consonant.group(1).replace('ch', 't') + rom
            start = start-1
            first_char = full_string[start]
            prev_char = (full_string[start-1] if start >= 1 else '')
        # Thai
        if uroman.chr_script_name(first_char) == 'Thai':
            if (uroman.chr_script_name(prev_char) == 'Thai') \
                    and (uroman.dict_str[('syllable-info', prev_char)]
                         == 'written-pre-consonant-spoken-post-consonant') \
                    and regex.match(r'[bcdfghjklmnpqrstvwxyz]', rom) \
                    and (vowel_rom := self.romanization_by_first_rule(prev_char)):
                return rom + vowel_rom, start-1, end, 'rom exp'
            # THAI CHARACTER O ANG
            if (first_char == '\u0E2D') and (end - start == 1):
                prev_script = uroman.chr_script_name(prev_char)
                next_script = uroman.chr_script_name(next_char)
                prev_rom = self.find_rom_edge_path_backwards(0, start, 1, return_str=True)
                next_rom = self.romanization_by_first_rule(next_char)
                # if not recursive:
                #     lc = uroman.romanize_string(full_string[:start], lcode=self.lcode, recursive=True)
                #     rc = uroman.romanize_string(full_string[end:], lcode=self.lcode, recursive=True)
                #     print('PP', start, end, prev_script, next_script, prev_rom, next_rom, '  LC:', lc[-40:],
                #           '  RC:', rc[:40])
                # delete THAI CHARACTER O ANG unless it is surrounded on both sides by a Thai consonant
                if not ((prev_script == 'Thai') and (next_script == 'Thai')
                        and regex.match(r'[bcdfghjklmnpqrstvwxz]+$', prev_rom)
                        and regex.match(r'[bcdfghjklmnpqrstvwxz]+$', next_rom)):
                    # if not recursive:
                    #     print(f'* DELETE O ANG {first_char} {start}-{end}   LC: {lc[-40:]}  RC: {rc[:40]}')
                    return '', start, end, 'rom del'
        # Coptic: consonant + grace-accent = e + consonant
        if next_char and (next_char == "\u0300") and (uroman.chr_script_name(last_char) == "Coptic")\
                and (not self.simple_top_romanization_candidate_for_span(orig_start, end+1)):
            rom = 'e' + rom
            end = end+1
            last_char = full_string[end - 1]
            next_char = (full_string[end] if end < len(full_string) else '')
            annot = 'rom exp'
        # Japanese small y: ki + small ya = kya etc.
        if (next_char and next_char in 'ゃゅょャュョ') \
                and (uroman.chr_script_name(last_char) == uroman.chr_script_name(next_char)) \
                and regex.search(r'([bcdfghjklmnpqrstvwxyz]i$)', rom) \
                and (y_rom := self.romanization_by_first_rule(next_char)) \
                and (not self.simple_top_romanization_candidate_for_span(orig_start, end+1)) \
                and (not self.simple_top_romanization_candidate_for_span(start, end+1)):
            rom = rom[:-1] + y_rom
            end = end+1
            last_char = full_string[end - 1]
            next_char = (full_string[end] if end < len(full_string) else '')
            annot = 'rom exp'
        # Japanese vowel lengthener (U+30FC)
        last_rom_char = last_chr(rom)
        if (next_char == 'ー') \
                and (uroman.chr_script_name(last_char) in ('Hiragana', 'Katakana')) \
                and (last_rom_char in 'aeiou'):
            return rom + last_rom_char, start, end+1, 'rom exp'
        # Virama (in Indian languages)
        if self.uroman.dict_bool[('is-virama', next_char)]:
            return rom, start, end + 1, "rom exp"
        if rom.startswith(' ') and ((start == 0) or (prev_char == ' ')):
            rom = rom[1:]
        if rom.endswith(' ') and ((end == len(full_string)+1) or (next_char == ' ')):
            rom = rom[:-1]
        return rom, start, end, annot

    def add_default_abugida_vowel(self, rom: str, start: int, end: int, annotation: str = '') -> str:
        """Adds an abugida vowel (e.g. "a") where needed. Important for many languages in South Asia."""
        uroman = self.uroman
        s = self.s
        try:
            first_s_char = s[start]
            last_s_char = s[end-1]
            script_name = uroman.chr_script_name(first_s_char)
            script = self.uroman.scripts[script_name.lower()]
            abugida_default_vowel = script['abugida_default_vowels'][0]
            base_rom = m.group(1) if (m := regex.match(r'([cfghkmnqrstxy]?y)(a+)$', rom)) else rom
            if not regex.match(r'[bcdfghjklmnpqrstvwxyz]+$', base_rom):
                return rom
            prev_s_char = s[start-1] if start >= 1 else ''
            next_s_char = s[end] if len(s) > end else ''
            next2_s_char = s[end+1] if len(s) > end+1 else ''
            if 'tail' in annotation:
                return rom
            if self.uroman.dict_bool[('is-vowel-sign', next_s_char)]:
                return base_rom
            if self.uroman.char_is_nonspacing_mark(next_s_char) \
                    and self.uroman.dict_bool[('is-vowel-sign', next2_s_char)]:
                return base_rom
            if self.uroman.dict_bool[('is-virama', next_s_char)]:
                return base_rom
            if self.uroman.char_is_nonspacing_mark(next_s_char) \
                    and self.uroman.dict_bool[('is-virama', next2_s_char)]:
                return base_rom
            if self.uroman.dict_bool[('is-virama', prev_s_char)]:
                return base_rom + abugida_default_vowel
            if self.is_at_start_of_word(start) and not regex.search('r[aeiou]', rom):
                return base_rom + abugida_default_vowel
            # print('G', start, end, rom)
            # delete many final schwas from most Devanagari languages (except: Sanskrit)
            if self.is_at_end_of_word(end):
                if (script_name in ("Devanagari",)) and (self.lcode not in ('san',)):  # Sanskrit
                    return rom
                else:
                    return base_rom + abugida_default_vowel
            # print('H', start, end, rom)
            if uroman.chr_script_name(prev_s_char) != script_name:
                return base_rom + abugida_default_vowel
            if 'VOCALIC' in self.uroman.chr_name(last_s_char):
                return base_rom
            if uroman.chr_script_name(next_s_char) == script_name:
                return base_rom + abugida_default_vowel
        except Exception:
            return rom
        else:
            pass
            # print('ABUGIDA', rom, start, script_name, script, abugida_default_vowel, prev_s_char, next_s_char)
        return rom

    def cand_is_valid(self, rom_rule: RomRule, start: int, end: int, rom: str) -> bool:
        if rom is None:
            return False
        if rom_rule['dont_use_at_start_of_word'] and self.is_at_start_of_word(start):
            return False
        if rom_rule['use_only_at_start_of_word'] and not self.is_at_start_of_word(start):
            return False
        if rom_rule['dont_use_at_end_of_word'] and self.is_at_end_of_word(end):
            return False
        if rom_rule['use_only_at_end_of_word'] and not self.is_at_end_of_word(end):
            return False
        if rom_rule['use_only_for_whole_word'] \
                and not (self.is_at_start_of_word(start) and self.is_at_end_of_word(end)):
            return False
        if (lcodes := rom_rule['lcodes']) and (self.lcode not in lcodes):
            return False
        return True

    # @profile
    def simple_sorted_romanization_candidates_for_span(self, start, end) -> List[str]:
        s = self.s[start:end]
        if not self.uroman.dict_bool[('s-prefix', s)]:
            return []
        rom_rule_candidates = []
        for rom_rule in self.uroman.rom_rules[s]:
            rom = rom_rule['t']
            if self.cand_is_valid(rom_rule, start, end, rom):
                rom_rule_candidates.append((rom_rule['n_restr'] or 0, rom_rule['t']))
        rom_rule_candidates.sort(reverse=True)
        return [x[1] for x in rom_rule_candidates]

    def simple_top_romanization_candidate_for_span(self, start, end) -> Optional[str]:
        best_cand, best_n_restr = None, None
        for rom_rule in self.uroman.rom_rules[self.s[start:end]]:
            if self.cand_is_valid(rom_rule, start, end, rom_rule['t']):
                n_restr = rom_rule['n_restr'] or 0
                if best_n_restr is None or (n_restr > best_n_restr):
                    best_cand, best_n_restr = rom_rule['t'], n_restr
        return best_cand

    def decomp_rom(self, char_position: int) -> Optional[str]:
        """Input: decomposable character such as ﻼ or ½
        Output: la or 1/2"""
        full_string = self.s
        char = full_string[char_position]
        rom = None
        if ud_decomp_s := ud.decomposition(char):
            format_comps = []
            other_comps = []
            decomp_s = ''
            name = self.uroman.chr_name(char)
            for ud_decomp_elem in ud_decomp_s.split():
                if ud_decomp_elem.startswith("<"):
                    format_comps.append(ud_decomp_elem)
                else:
                    try:
                        norm_char = chr(int(ud_decomp_elem, 16))
                    except ValueError:
                        other_comps.append(ud_decomp_elem)
                    else:
                        decomp_s += norm_char
            if (format_comps and (format_comps[0] not in ('<super>', '<sub>', '<noBreak>', '<compat>'))
                    # and (char not in '')
                    and (not other_comps) and decomp_s):
                rom = self.uroman.romanize_string(decomp_s, self.lcode)
                # make sure to add a space for 23½ -> 23 1/2
            if rom and ud.numeric(char, None):
                if char_position >= 1 and ud.numeric(full_string[char_position-1], None):
                    rom = ' ' + rom
                if (char_position+1 < len(full_string)) and ud.numeric(full_string[char_position+1], None):
                    rom += ' '
        return rom

    def add_romanization(self, **args):
        """Adds a romanization edge to the romanization lattice."""
        for start in range(self.max_vertex):
            for end in range(start+1, self.max_vertex+1):
                if not self.uroman.dict_bool[('s-prefix', self.s[start:end])]:
                    break
                if (rom := self.simple_top_romanization_candidate_for_span(start, end)) is not None:
                    edge_annotation = 'rom'
                    if regex.match(r'\+(m|ng|n|h|r)', rom):
                        rom, edge_annotation = rom[1:], 'rom tail'
                    rom = self.add_default_abugida_vowel(rom, start, end, annotation=edge_annotation)
                    # orig_rom, orig_start, orig_end = rom, start, end
                    rom, start2, end2, exp_edge_annotation \
                        = self.expand_rom_with_special_chars(rom, start, end, annotation=edge_annotation,
                                                             recursive=args.get('recursive', False))
                    edge_annotation = exp_edge_annotation or edge_annotation
                    # if (orig_rom, orig_start, orig_end) != (rom, start, end):
                    #     print(f'EXP {s} {orig_rom} {orig_start}-{orig_end} -> {rom} {start}-{end}')
                    # if rom != rom_orig: print('** Add ABUGIDA', rom, start, end, rom2)
                    self.add_edge(Edge(start2, end2, rom, edge_annotation))
            if start < len(self.s):
                char = self.s[start]
                cp = ord(char)
                # Korean Hangul characters
                if 0xAC00 <= cp <= 0xD7A3:
                    if rom := self.uroman.unicode_hangul_romanization(char):
                        self.add_edge(Edge(start, start+1, rom, 'rom'))
                # character decomposition
                if rom_decomp := self.decomp_rom(start):
                    self.add_edge(Edge(start, start + 1, rom_decomp, 'rom decomp'))

    def add_numbers(self, uroman):
        """Adds a numerical romanization edge to the romanization lattice, currently just for digits.
        To be significantly expanded to cover complex Chinese, Egyptian, Amharic numbers."""
        s = self.s
        for start in range(len(s)):
            start_char = s[start]
            if (num := ud_numeric(start_char)) is not None:
                name = self.uroman.chr_name(start_char)
                if ("DIGIT" in name) and isinstance(num, int) and (0 <= num <= 9):
                    # if start_char not in '0123456789': print('DIGIT', s[start], num, name)
                    self.add_edge(Edge(start, start + 1, str(num), 'num'))
                else:
                    uroman.stats[('*NUM', start_char, num)] += 1

    def add_rom_fall_back_singles(self, _uroman):
        """For characters in the original string not covered by romanizations and numbers,
        add a fallback edge based on type, romanization of single char, or original char."""
        for start in range(self.max_vertex):
            end = start+1
            orig_char = self.s[start]
            if not self.lattice[(start, end)]:
                rom, edge_annotation = orig_char, 'orig'
                if self.uroman.char_is_nonspacing_mark(rom):
                    rom, edge_annotation = '', 'Mn'
                elif self.uroman.char_is_format_char(rom):  # e.g. zero-width non-joiner, zero-width joiner
                    rom, edge_annotation = '', 'Cf'
                elif rom == ' ':
                    edge_annotation = 'orig'
                # elif self.uroman.char_is_space_separator(rom):
                #     rom, edge_annotation = ' ', 'Zs'
                elif (rom2 := self.simple_top_romanization_candidate_for_span(start, end)) is not None:
                    rom = rom2
                    if regex.match(r'\+(m|ng|n|h|r)', rom):
                        rom = rom[1:]
                    edge_annotation = 'rom single'
                # else the original values still hold: rom, edge_annotation = orig_char, 'orig'
                self.add_edge(Edge(start, end, rom, edge_annotation))

    def all_edges(self, start: int, end: int) -> List[Edge]:
        result = []
        for start2 in range(start, end):
            for end2 in sorted(list(self.lattice[(start2, 'right')]), reverse=True):
                if end2 <= end:
                    result.extend(self.lattice[(start2, end2)])
                else:
                    break
        return result

    def best_edge_in_span(self, start: int, end: int) -> Optional[Edge]:
        edges = self.lattice[(start, end)]
        # if len(edges) >= 2: print('Multi edge', start2, end2, self.s[start2:end2], edges)
        decomp_edge, other_edge = None, None
        for edge in edges:
            if edge.type.startswith('rom decomp'):
                if decomp_edge is None:
                    decomp_edge = edge  # plan B
            elif regex.match(r'(?:rom|num)', edge.type):
                return edge
            elif other_edge is None:
                other_edge = edge  # plan C
        return decomp_edge or other_edge

    def best_rom_edge_path(self, start: int, end: int) -> List[Edge]:
        """Finds the best romanization edge path through the romanization lattice, including
        non-romanized pieces such as ASCII and non-ASCII punctuation."""
        result = []
        start2 = start
        while start2 < end:
            best_edge = None
            for end2 in sorted(list(self.lattice[(start2, 'right')]), reverse=True):
                if best_edge := self.best_edge_in_span(start2, end2):
                    break
            if best_edge:
                result.append(best_edge)
                start2 = best_edge.end
            else:  # should not happen
                start2 += 1
        return result

    def find_rom_edge_path_backwards(self, start: int, end: int, min_char: Optional[int] = None,
                                     return_str: bool = False) -> Union[List[Edge], str]:
        """Finds a partial best path on the left from a start position to provide left contexts for
        romanization rules. Can return a string or a list of edges. Is typically used for a short context,
        as specified by min_char."""
        result_edges = []
        rom = ''
        end2 = end
        while start < end2:
            old_end2 = end2
            new_edge = None
            for start2 in sorted(list(self.lattice[(end2, 'left')])):
                edges = self.lattice[(start2, end2)]
                other_edge = None
                for edge in edges:
                    if regex.match(r'(?:rom|num)', edge.type):
                        new_edge = edge
                        break
                    elif other_edge is None:
                        other_edge = edge
                if new_edge:
                    break
                new_edge = other_edge
            if new_edge:
                result_edges = [new_edge] + result_edges
                rom = new_edge.txt + rom
                end2 = new_edge.start
            if min_char and len(rom) >= min_char:
                break
            if old_end2 >= end2:
                end2 -= 1
        if return_str:
            return rom
        else:
            return result_edges

    @staticmethod
    def edge_path_to_surf(edges) -> str:
        result = ''
        for edge in edges:
            result += edge.txt
        return result


# @timer
def main():
    """This function provides a user interface, either using argparse for a command line interface,
    or providing direct function calls.
    First, a uroman object will have to created, loading uroman data (directory must be provided,
    listed as default). This only needs to be done once.
    After that you can romanize from file to file, or just romanize a string."""

    # Compute data_dir based on the location of this executable script.
    src_dir = os.path.dirname(os.path.realpath(__file__))
    root_dir = os.path.dirname(src_dir)
    data_dir = os.path.join(root_dir, "data")
    # print(src_dir, root_dir, data)

    parser = argparse.ArgumentParser()
    parser.add_argument('direct_input', nargs='*', type=str)
    parser.add_argument('--data_dir', type=Path, default=data_dir, help='uroman resource dir')
    parser.add_argument('-i', '--input_filename', type=str, help='default: sys.stdin')
    parser.add_argument('-o', '--output_filename', type=str, help='default: sys.stdout')
    parser.add_argument('-l', '--lcode', type=str, default=None,
                        help='ISO 639-3 language code, e.g. eng')
    # parser.add_argument('-f', '--rom_format', type=RomFormat, default=RomFormat.STR, help:'alt: RomFormat.EDGES')
    parser.add_argument('-f', '--rom_format', type=RomFormat, default=RomFormat.STR,
                        choices=list(RomFormat), help="Output format of romanization. 'edges' provides offsets")
    # The remaining arguments are mostly for development and test
    parser.add_argument('--max_lines', type=int, default=None, help='limit uroman to first n lines')
    parser.add_argument('--load_log', action='count', default=0, help='report load stats')
    parser.add_argument('--test', action='count', default=0, help='perform/display a few tests')
    parser.add_argument('--rebuild_ud_props', action='count', default=0,
                        help='rebuild UnicodeDataProps files (for development mode only)')
    parser.add_argument('--no_caching', action='count', default=0, help='for development mode: speed')
    parser.add_argument('--stats', action='count', default=0, help='for development mode: numbers')
    parser.add_argument('--ignore_args', action='count', default=0, help='for usage illustration only')
    parser.add_argument('--profile', type=argparse.FileType('w', encoding='utf-8', errors='ignore'),
                        default=None, metavar='PROFILE-FILENAME', help='(optional output for performance analysis)')
    args = parser.parse_args()
    # copy selected (minor) args from argparse.Namespace to dict
    args_dict = {'rom_format': args.rom_format, 'load_log': args.load_log, 'test': args.test, 'stats': args.stats,
                 'no_caching': args.no_caching, 'rebuild_ud_props': args.rebuild_ud_props, 'max_lines': args.max_lines}
    pr = None
    if args.profile:
        gc.enable()
        gc.set_debug(gc.DEBUG_STATS)
        gc.set_debug(gc.DEBUG_LEAK)
        pr = cProfile.Profile()
        pr.enable()
    '''Sample calls:
uroman.py --help
uroman.py -i ../test/multi-script.txt -o ../test/multi-script-out2.txt
uroman.py  < ../test/multi-script.txt  > ../test/multi-script-out2.txt
uroman.py Игорь
uroman.py Игорь --lcode ukr
uroman.py ألاسكا 서울 Καλιφόρνια
uroman.py ちょっとまってください -f edges
uroman.py "महात्मा गांधी" -f lattice
uroman.py สวัสดี --load_log
uroman.py --test
uroman.py --ignore_args
uroman.py Բարեւ -o ../test/tmp-out.txt -f edges
# In double input cases such as in the line below,
# the input-file's romanization is sent to stdout, while the direct-input romanization is sent to stderr
uroman.py ⴰⵣⵓⵍ -i ../test/multi-script.txt > ../test/multi-script-out2.txt
    '''

    if args.ignore_args:
        # minimal calls
        uroman = Uroman(args.data_dir)
        s, s2, s3, s4 = 'Игорь', 'ちょっとまってください', 'ka‍n‍ne', 'महात्मा गांधी'
        print(s, uroman.romanize_string(s))
        print(s, uroman.romanize_string(s, lcode='ukr'))
        print(s2, Edge.json_str(uroman.romanize_string(s2, rom_format=RomFormat.EDGES)))
        print(s3, Edge.json_str(uroman.romanize_string(s3, rom_format=RomFormat.EDGES)))
        print(s4, Edge.json_str(uroman.romanize_string(s4, rom_format=RomFormat.LATTICE)))
        # Note that ../test/multi-script.txt has several lines starting with ::lcode eng etc.
        # This allows users to select specific language codes to specific lines, overwriting the overall --lcodes
        uroman.romanize_file(input_filename='../test/multi-script.txt',
                             output_filename='../test/multi-script-out3.txt')
    else:
        # build a Uroman object (once for many applications and different scripts and languages)
        uroman = Uroman(args.data_dir, load_log=args.load_log, rebuild_ud_props=args.rebuild_ud_props)
        romanize_file_p = (args.input_filename or args.output_filename
                           or not (args.direct_input or args.test or args.ignore_args or args.rebuild_ud_props))
        # Romanize any positional arguments, interpreted as strings to be romanized.
        for s in args.direct_input:
            result = uroman.romanize_string(s.rstrip(), lcode=args.lcode, **args_dict)
            result_json = Edge.json_str(result)
            if romanize_file_p:
                # input from both file/stdin (to file/stdout) and direct-input (to stderr)
                if args.input_filename:
                    sys.stderr.write(result_json + '\n')
                # input from direct-input (but not from file/stdin) to stdout
                # else pass
            # no file/stdin or file/stdout, so we write romanization of direct-input to stdout
            else:
                print(result_json)
        # If provided, apply romanization to an entire file.
        if (args.input_filename or args.output_filename
                or not (args.direct_input or args.test or args.ignore_args or args.rebuild_ud_props)):
            uroman.romanize_file(args.input_filename, args.output_filename, lcode=args.lcode,
                                 direct_input=args.direct_input, **args_dict)
        if args.test:
            uroman.test_output_of_selected_scripts_and_rom_rules()
            uroman.test_romanization()
        if uroman.stats and args.stats:
            stats100 = {k: uroman.stats[k] for k in list(dict(uroman.stats))[:100]}
            sys.stderr.write(f'Stats: {stats100} ...\n')
    if args.profile:
        if pr:
            pr.disable()
            ps = pstats.Stats(pr, stream=args.profile).sort_stats(pstats.SortKey.TIME)
            ps.print_stats()
        print(gc.get_stats())


if __name__ == "__main__":
    main()
