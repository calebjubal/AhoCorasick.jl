module AhoCorasick

export ACAutomaton, search, eachmatch

"""
    ACNode

Internal node structure for the Aho-Corasick automaton trie.

# Fields
- `children::Dict{Char, Int}`: Map from character to child node index
- `fail::Int`: Failure link pointing to the longest proper suffix that is also a prefix
- `output::Vector{Int}`: Indices of patterns that end at this node
- `depth::Int`: Depth of this node in the trie (length of the string represented)
"""
mutable struct ACNode
    children::Dict{Char, Int}
    fail::Int
    output::Vector{Int}
    depth::Int
end

ACNode() = ACNode(Dict{Char, Int}(), 0, Int[], 0)

"""
    ACAutomaton{T<:AbstractString}

Aho-Corasick automaton for multi-pattern string matching.

# Fields
- `nodes::Vector{ACNode}`: Array of trie nodes (index 1 is root)
- `patterns::Vector{T}`: The original patterns stored for reference

# Example
```julia
automaton = ACAutomaton(["he", "she", "his", "hers"])
for match in eachmatch(automaton, "ushers")
    println("Found '\$(match.pattern)' at position \$(match.start)")
end
```
"""
struct ACAutomaton{T<:AbstractString}
    nodes::Vector{ACNode}
    patterns::Vector{T}
end

"""
    ACMatch

Represents a match found during search.

# Fields
- `pattern::String`: The matched pattern
- `pattern_index::Int`: Index of the pattern in the original pattern list
- `start::Int`: Starting position of the match in the text (1-indexed)
- `stop::Int`: Ending position of the match in the text (1-indexed)
"""
struct ACMatch
    pattern::String
    pattern_index::Int
    start::Int
    stop::Int
end

Base.show(io::IO, m::ACMatch) = print(io, "ACMatch(\"$(m.pattern)\", $(m.start):$(m.stop))")

"""
    ACAutomaton(patterns::AbstractVector{<:AbstractString})

Construct an Aho-Corasick automaton from a collection of patterns.

The automaton is built in two phases:
1. Build a trie from all patterns
2. Compute failure links using BFS

# Arguments
- `patterns`: A vector of string patterns to search for

# Returns
- `ACAutomaton`: The constructed automaton ready for searching

# Example
```julia
automaton = ACAutomaton(["he", "she", "his", "hers"])
```
"""
function ACAutomaton(patterns::AbstractVector{T}) where T<:AbstractString
    nodes = [ACNode()]  # Root node at index 1
    
    # Phase 1: Build the trie
    for (pattern_idx, pattern) in enumerate(patterns)
        current = 1  # Start at root
        depth = 0
        for char in pattern
            depth += 1
            if haskey(nodes[current].children, char)
                current = nodes[current].children[char]
            else
                # Create new node
                push!(nodes, ACNode())
                new_idx = length(nodes)
                nodes[new_idx].depth = depth
                nodes[current].children[char] = new_idx
                current = new_idx
            end
        end
        # Mark this node as end of pattern
        push!(nodes[current].output, pattern_idx)
    end
    
    # Phase 2: Build failure links using BFS
    queue = Int[]
    
    # Initialize: children of root have fail link to root
    for child_idx in values(nodes[1].children)
        nodes[child_idx].fail = 1
        push!(queue, child_idx)
    end
    
    while !isempty(queue)
        current = popfirst!(queue)
        
        for (char, child_idx) in nodes[current].children
            push!(queue, child_idx)
            
            # Find failure link for child
            fail = nodes[current].fail
            while fail != 0 && !haskey(nodes[fail].children, char)
                fail = nodes[fail].fail
            end
            
            if fail == 0
                nodes[child_idx].fail = 1  # Go to root
            else
                nodes[child_idx].fail = nodes[fail].children[char]
            end
            
            # Merge output from failure link (suffix links)
            if nodes[child_idx].fail != child_idx
                append!(nodes[child_idx].output, nodes[nodes[child_idx].fail].output)
            end
        end
    end
    
    return ACAutomaton{T}(nodes, collect(patterns))
end

"""
    search(automaton::ACAutomaton, text::AbstractString) -> Vector{ACMatch}

Search for all occurrences of patterns in the text.

# Arguments
- `automaton`: The Aho-Corasick automaton containing the patterns
- `text`: The text to search in

# Returns
- `Vector{ACMatch}`: All matches found, sorted by start position

# Example
```julia
automaton = ACAutomaton(["he", "she", "his", "hers"])
matches = search(automaton, "ushers")
# Returns matches for "she", "he", "hers"
```
"""
function search(automaton::ACAutomaton, text::AbstractString)
    matches = ACMatch[]
    nodes = automaton.nodes
    patterns = automaton.patterns
    
    current = 1  # Start at root
    
    for (pos, char) in enumerate(text)
        # Follow failure links until we find a match or reach root
        while current != 1 && !haskey(nodes[current].children, char)
            current = nodes[current].fail
        end
        
        if haskey(nodes[current].children, char)
            current = nodes[current].children[char]
        end
        
        # Collect all pattern matches at this node
        for pattern_idx in nodes[current].output
            pattern = patterns[pattern_idx]
            start_pos = pos - length(pattern) + 1
            push!(matches, ACMatch(String(pattern), pattern_idx, start_pos, pos))
        end
    end
    
    # Sort by start position, then by pattern index for consistent ordering
    sort!(matches, by = m -> (m.start, m.pattern_index))
    return matches
end

"""
    eachmatch(automaton::ACAutomaton, text::AbstractString)

Return an iterator over all matches of patterns in the text.

This is more memory-efficient than `search` for large texts as it yields
matches one at a time instead of collecting them all.

# Arguments
- `automaton`: The Aho-Corasick automaton containing the patterns
- `text`: The text to search in

# Returns
- Iterator yielding `ACMatch` objects

# Example
```julia
automaton = ACAutomaton(["he", "she", "his", "hers"])
for match in eachmatch(automaton, "ushers")
    println("Found '\$(match.pattern)' at position \$(match.start)")
end
```
"""
function Base.eachmatch(automaton::ACAutomaton, text::AbstractString)
    return ACMatchIterator(automaton, text)
end

struct ACMatchIterator{T<:AbstractString, S<:AbstractString}
    automaton::ACAutomaton{T}
    text::S
end

struct ACMatchState
    text_pos::Int
    current_node::Int
    pending_outputs::Vector{Int}
    pending_idx::Int
end

function Base.iterate(iter::ACMatchIterator)
    state = ACMatchState(1, 1, Int[], 1)
    return _next_match(iter, state)
end

function Base.iterate(iter::ACMatchIterator, state::ACMatchState)
    return _next_match(iter, state)
end

function _next_match(iter::ACMatchIterator, state::ACMatchState)
    nodes = iter.automaton.nodes
    patterns = iter.automaton.patterns
    text = iter.text
    
    text_pos = state.text_pos
    current = state.current_node
    pending = state.pending_outputs
    pending_idx = state.pending_idx
    
    # First check if we have pending outputs from previous position
    if pending_idx <= length(pending)
        pattern_idx = pending[pending_idx]
        pattern = patterns[pattern_idx]
        match_end = text_pos - 1
        start_pos = match_end - length(pattern) + 1
        new_state = ACMatchState(text_pos, current, pending, pending_idx + 1)
        return (ACMatch(String(pattern), pattern_idx, start_pos, match_end), new_state)
    end
    
    # Continue scanning text
    while text_pos <= length(text)
        char = text[text_pos]
        
        # Follow failure links until we find a match or reach root
        while current != 1 && !haskey(nodes[current].children, char)
            current = nodes[current].fail
        end
        
        if haskey(nodes[current].children, char)
            current = nodes[current].children[char]
        end
        
        text_pos += 1
        
        # Check for pattern matches
        outputs = nodes[current].output
        if !isempty(outputs)
            pattern_idx = outputs[1]
            pattern = patterns[pattern_idx]
            match_end = text_pos - 1
            start_pos = match_end - length(pattern) + 1
            new_state = ACMatchState(text_pos, current, outputs, 2)
            return (ACMatch(String(pattern), pattern_idx, start_pos, match_end), new_state)
        end
    end
    
    return nothing
end

Base.IteratorSize(::Type{<:ACMatchIterator}) = Base.SizeUnknown()
Base.eltype(::Type{<:ACMatchIterator}) = ACMatch

end
