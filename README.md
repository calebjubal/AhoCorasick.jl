# AhoCorasick.jl

[![Build Status](https://github.com/calebjubal/AhoCorasick.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/calebjubal/AhoCorasick.jl/actions/workflows/CI.yml?query=branch%3Amaster)

A Julia implementation of the [Aho-Corasick algorithm](https://en.wikipedia.org/wiki/Aho%E2%80%93Corasick_algorithm) for efficient multi-pattern string matching.

## Features

- **O(n + m + z)** time complexity where n = text length, m = total pattern length, z = number of matches
- Finds all occurrences of multiple patterns in a single pass through the text
- Supports Unicode patterns and text
- Memory-efficient iterator interface for streaming matches
- Type-stable implementation

## Installation

```julia
using Pkg
Pkg.add("AhoCorasick")
```

## Usage

### Basic Usage

```julia
using AhoCorasick

# Create an automaton from a list of patterns
automaton = ACAutomaton(["he", "she", "his", "hers"])

# Search for all patterns in text
matches = search(automaton, "ushers")

for m in matches
    println("Found '$(m.pattern)' at position $(m.start):$(m.stop)")
end
# Output:
# Found 'she' at position 2:4
# Found 'he' at position 3:4
# Found 'hers' at position 3:6
```

### Iterator Interface

For large texts, use the iterator interface to avoid allocating all matches at once:

```julia
automaton = ACAutomaton(["pattern1", "pattern2", "pattern3"])

for match in eachmatch(automaton, "some long text with pattern1 and pattern2...")
    println("Found: $(match.pattern)")
end
```

### ACMatch Properties

Each match object contains:
- `pattern`: The matched string
- `pattern_index`: Index of the pattern in the original pattern list
- `start`: Starting position in text (1-indexed)
- `stop`: Ending position in text (1-indexed)

```julia
automaton = ACAutomaton(["test"])
matches = search(automaton, "a test here")
m = matches[1]

m.pattern       # "test"
m.pattern_index # 1
m.start         # 3
m.stop          # 6
```

## Algorithm

The Aho-Corasick algorithm constructs a finite-state automaton from the patterns:

1. **Trie Construction**: Build a trie (prefix tree) from all patterns
2. **Failure Links**: Add failure links using BFS, similar to KMP's failure function
3. **Search**: Traverse the automaton character by character, following failure links on mismatches

This allows finding all occurrences of all patterns in a single linear scan of the text.

## License

MIT License
