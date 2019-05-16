# URoman

*uroman* is a *universal romanizer*. It converts text in any script to the Latin alphabet.

Version: 1.2  
Release date: April 11, 2017  
Author: Ulf Hermjakob, USC Information Sciences Institute  


### Usage: 
```bash
$ uroman.pl [-l <lang-code>] [--chart] [--no-cache] < STDIN
       where the optional <lang-code> is a 3-letter languages code, e.g. ara, fas, heb, tur, uig, ukr, yid.
       --chart specifies chart output (in JSON format) to represent alternative romanizations.
       --no-cache disables caching.
```
### Examples: 
```bash
$ bin/uroman.pl < text/zho.txt
$ bin/uroman.pl -l tur < text/tur.txt
$ bin/uroman.pl -l heb --chart < text/heb.txt
```

Identifying the input as Arabic, Farsi, Hebrew, Turkish, Ukrainian, Uyghur or 
Yiddish will improve romanization for those languages as some letters in those 
languages have different sound values from other languages using the same script 
(French, Russian, Hebrew respectively).
No effect for other languages in this version.

Changes in version 1.2.4
  * Bug-fix that generated two emtpy lines for each empty line in cache mode.
Changes in version 1.2
 * Run-time improvement based on (1) token-based caching and (2) shortcut 
   romanization (identity) of ASCII strings for default 1-best (non-chart) 
   output. Speed-up by a factor of 10 for Bengali and Uyghur on medium and 
   large size texts.
 * Incremental improvements for Farsi, Amharic, Russian, Hebrew and related
   languages.
 * Richer lattice structure (more alternatives) for "Romanization" of English
   to support better matching to romanizations of other languages.
   Changes output only when --chart option is specified. No change in output for
   default 1-best output, which for ASCII characters is always the input string.
Changes in version 1.1 (major upgrade)
 * Offers chart output (in JSON format) to represent alternative romanizations.
   -- Location of first character is defined to be "line: 1, start:0, end:0".
 * Incremental improvements of Hebrew and Greek romanization; Chinese numbers.
 * Improved web-interface at http://www.isi.edu/~ulf/uroman.html
   -- Shows corresponding original and romanization text in red
      when hovering over a text segment.
   -- Shows alternative romanizations when hovering over romanized text
      marked by dotted underline.
   -- Added right-to-left script detection and improved display for right-to-left
      script text (as determined line by line).
   -- On-page support for some scripts that are often not pre-installed on users'
      computers (Burmese, Egyptian, Klingon).
Changes in version 1.0 (major upgrade)
 * Upgraded principal internal data structure from string to lattice.
 * Improvements mostly in vowelization of South and Southeast Asian languages.
 * Vocalic 'r' more consistently treated as vowel (no additional vowel added).
 * Repetition signs (Japanese/Chinese/Thai/Khmer/Lao) are mapped to superscript 2.
 * Japanese Katakana middle dots now mapped to ASCII space.
 * Tibetan intersyllabic mark now mapped to middle dot (U+00B7).
 * Some corrections regarding analysis of Chinese numbers.
 * Many more foreign diacritics and punctuation marks dropped or mapped to ASCII.
 * Zero-width characters dropped, except line/sentence-initial byte order marks.
 * Spaces normalized to ASCII space.
 * Fixed bug that in some cases mapped signs (such as dagger or bullet) to their verbal descriptions.
 * Tested against previous version of uroman with a new uroman visual diff tool.
 * Almost an order of magnitude faster.
Changes in version 0.7 (minor upgrade)
 * Added script uroman-quick.pl for Arabic script languages, incl. Uyghur.
   Much faster, pre-caching mapping of Arabic to Latin characters, simple greedy processing.
   Will not convert material from non-Arabic blocks such as any (somewhat unusual) Cyrillic
   or Chinese characters in Uyghur texts.
Changes in version 0.6 (minor upgrade)
 * Added support for two letter characters used in Uzbek:
   (1) character "ʻ" ("modifier letter turned comma", which modifies preceding "g" and "u" letters)
   (2) character "ʼ" ("modifier letter apostrophe", which Uzbek uses to mark a glottal stop).
   Both are now mapped to "'" (plain ASCII apostrophe).
 * Added support for Uyghur vowel characters such as "ې" (Arabic e) and "ۆ" (Arabic oe)
   even when they are not preceded by "ئ" (yeh with hamza above).
 * Added support for Arabic semicolon "؛", Arabic ligature forms for phrases such as "ﷺ"
   ("sallallahou alayhe wasallam" = "prayer of God be upon him and his family and peace")
 * Added robustness for Arabic letter presentation forms (initial/medial/final/isolated).
   However, it is strongly recommended to normalize any presentation form Arabic letters
   to their non-presentation form before calling uroman.
 * Added force flush directive ($|=1;).
Changes in version 0.5 (minor upgrade)
 * Improvements for Uyghur (make sure to use language option: -l uig)
Changes in version 0.4 (minor upgrade)
 * Improvements for Thai (special cases for vowel/consonant reordering, e.g. for "sara o"; dropped some aspiration 'h's)
 * Minor change for Arabic (added "alef+fathatan" = "an")
New features in version 0.3
 * Covers Mandarin (Chinese)
 * Improved romanization for numerous languages
 * Preserves capitalization (e.g. from Latin, Cyrillic, Greek scripts)
 * Maps from native digits to Western numbers
 * Faster for South Asian languages

Other features
 * Web interface: http://www.isi.edu/~ulf/uroman.html
 * Vowelization is provided when locally computable, e.g. for many South Asian
   languages and Tibetan.

Limitations
 * This version of uroman assumes all CJK ideographs to be Mandarin (Chinese).
   This means that Japanese kanji are incorrectly romanized; however, Japanese
   hiragana and katakana are properly romanized.
 * A romanizer is not a full transliterator. For example, this version of
   uroman does not vowelize text that lacks explicit vowelization such as
   normal text in Arabic and Hebrew (without diacritics/points).

