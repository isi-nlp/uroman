# Uroman for Ruby

*uroman* is a *universal romanizer*. It converts text in any script to the standard Latin alphabet.
- Example (Greek): Νεπάλ → Nepal
- Example (Hindi): नेपाल → nepaal
- Example (Urdu): نیپال → nypal
- Example (Chinese): 三万一 → 31000

This Ruby library is a port of the Python implementation of uroman: https://github.com/isi-nlp/uroman

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'uroman'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install uroman
```

## Usage

### Basic Usage

```ruby
require 'uroman'

# Create a new Uroman instance
uroman = Uroman::Uroman.new

# Romanize a string
puts uroman.romanize_string('Νεπάλ')    # => "Nepal"
puts uroman.romanize_string('नेपाल')    # => "nepaal"
puts uroman.romanize_string('三万一')    # => "31000"

# Romanize with language code for better results
puts uroman.romanize_string('Игорь', lcode: 'rus')  # => "Igor"
puts uroman.romanize_string('Игорь', lcode: 'ukr')  # => "Ihor"
```

### Different Output Formats

The library supports different output formats:

```ruby
# Default: string format
result = uroman.romanize_string('ایران', lcode: 'fas')
puts result  # => "iran"

# Edges format (provides character positions)
edges = uroman.romanize_string('ایران', lcode: 'fas', rom_format: 'edges')
edges.each do |edge|
  puts "#{edge.start}-#{edge.finish}: #{edge.txt}"
end

# Alternative romanizations
uroman.romanize_string('ایران', lcode: 'fas', rom_format: 'alts')

# Full lattice with all possible edges
uroman.romanize_string('ایران', lcode: 'fas', rom_format: 'lattice')
```

### File Processing

```ruby
# Romanize an entire file
uroman.romanize_file(
  input_filename: 'input.txt',
  output_filename: 'output.txt',
  lcode: 'fas'
)

# Process from stdin to stdout
uroman.romanize_file
```

### Command Line Usage

After installing the gem, you can use the `uroman` command:

```bash
# Basic usage
uroman "Игорь Стравинский"

# With language code
uroman -l ukr "Игорь"

# File input/output
uroman -i input.txt -o output.txt

# Specify output format
uroman -f edges "ちょっとまってください"

# Decode Unicode escape sequences
uroman -d "\u03C0\u03B9"

# Help
uroman -h
```

## Development

Run `rake init` to copy data files into the `/ruby/` subdirectory.

```bash
rake init
```

## Testing

```bash
rake spec
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

- Original Python version by Ulf Hermjakob, USC Information Sciences Institute
- Ruby port by Johnny Shields, 2025

## Bibliography

Ulf Hermjakob, Jonathan May, and Kevin Knight. 2018. Out-of-the-box universal romanization tool uroman. In Proceedings of the 56th Annual Meeting of Association for Computational Linguistics, Demo Track. ACL-2018 Best Demo Paper Award.
