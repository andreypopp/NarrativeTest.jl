#
# Doctest-like library for functional testing.
#

module NarrativeTest

export
    runtests

using Test

# Public interface.

"""
    runtests(files; subs=common_subs(), mod=nothing, quiet=false) :: Bool

Load the specified Markdown files to extract and run the embedded test cases.
When a directory is passed, load all `*.md` files in the directory.  This
function returns `true` if the testing is successful, `false` otherwise.

Specify `subs` to customize substitutions applied to the expected output in
order to convert it to a regular expression.

Specify `mod` to execute tests in the context of the given module.

Set `quiet=true` to suppress all output except for error reports.

    runtests(; default=common_args(), subs=common_subs(), mod=nothing, quiet=false)

In this form, test files are specified as command-line parameters.  When
invoked without parameters, tests are loaded from `*.md` files in the program
directory, which can be overriden using `default` parameter.  This function
terminates the program with code `0` if the testing is successful, `1`
otherwise.

Use this form in `test/runtests.jl`:

```julia
using NarrativeTest
NarrativeTest.runtests()
```
"""
function runtests end

"""
    testset(files = nothing;
            default=common_args(), subs=common_subs(), mod=nothing, quiet=false)

Run NarrativeTest-based tests as a nested test set.  For example, invoke it in
`test/runtests.jl`:

```julia
using Test, NarrativeTest

@testset "MyPackage" begin
    …
    NarrativeTest.testset()
    …
end
```

The given Markdown `files` are analyized to extract and run the embedded test
cases.  When a directory is passed, all nested `*.md` files are loaded.  When
invoked without arguments, all `*.md` files in the program directory are
loaded, which can be overridden using the `default` parameter.

Specify `subs` to customize substitutions applied to the expected output
in order to convert it to a regular expression.

Specify `mod` to execute tests in the context of the given module.

Set `quiet=true` to suppress all output except for error reports.

"""
function testset end

# Position in a file.

struct Location
    file::String
    line::Int
end

Location(file::String) = Location(file, 0)

Base.convert(::Type{Location}, file::String) = Location(file, 0)

function Base.print(io::IO, loc::Location)
    print(io, relpath(loc.file))
    if loc.line > 0
        print(io, ":$(loc.line)")
    end
end

function Base.show(io::IO, ::MIME"text/plain", loc::Location)
    print(io, Base.contractuser(abspath(loc.file)))
    if loc.line > 0
        print(io, ":$(loc.line)")
    end
end

Base.convert(::Type{LineNumberNode}, loc::Location) =
    LineNumberNode(loc.line, Symbol(loc.file))

# Text block with position in a file.

struct TextBlock
    loc::Location
    val::String
end

asexpr(code::TextBlock) =
    Base.parse_input_line("\n" ^ max(0, code.loc.line-1) * code.val,
                          filename=abspath(code.loc.file))

collapse(lines::Vector{TextBlock}) =
    !isempty(lines) ? TextBlock(lines[1].loc, join([line.val for line in lines])) : nothing

# Test case.

abstract type AbstractTestCase end

struct TestCase <: AbstractTestCase
    loc::Location
    code::TextBlock
    pre::Union{TextBlock,Nothing}
    expect::Union{TextBlock,Nothing}
    repl::Bool
end

location(test::TestCase) = test.loc

function Base.show(io::IO, mime::MIME"text/plain", test::TestCase)
    print(io, "Test case at ")
    show(io, mime, test.loc)
    println(io)
    println(io, indented(test.code))
    if test.pre !== nothing
        println(io, "Precondition:")
        println(io, indented(test.pre))
    end
    if test.expect !== nothing
        println(io, "Expected output:")
        println(io, indented(test.expect))
    end
end

Base.convert(::Type{LineNumberNode}, test::TestCase) =
    convert(LineNumberNode, test.loc)

# Test case that failed to parse.

struct BrokenTestCase <: AbstractTestCase
    loc::Location
    msg::String
end

BrokenTestCase(loc, exc::Exception) =
    BrokenTestCase(loc, sprint(showerror, exc))

location(err::BrokenTestCase) = err.loc

function Base.show(io::IO, mime::MIME"text/plain", err::BrokenTestCase)
    print(io, "Error at ")
    show(io, mime, err.loc)
    println(io)
    println(io, indented(err.msg))
end

Base.convert(::Type{LineNumberNode}, err::BrokenTestCase) =
    convert(LineNumberNode, err.loc)

# Test result types.

abstract type AbstractResult end

# Passed test.

struct Pass <: AbstractResult
    test::TestCase
    output::String
end

function Base.show(io::IO, mime::MIME"text/plain", pass::Pass)
    print(io, "Test passed at ")
    show(io, mime, pass.test.loc)
    println(io)
    println(io, indented(pass.test.code))
    println(io, "Expected output:")
    if pass.test.expect !== nothing
        println(io, indented(pass.test.expect))
    end
    println(io, "Actual output:")
    println(io, indented(pass.output))
end

Base.convert(::Type{Test.Result}, pass::Pass) =
    Test.Pass(:test, asexpr(pass.test.code), nothing, nothing)

# Failed test.

struct Fail <: AbstractResult
    test::TestCase
    output::String
    trace::StackTraces.StackTrace
end

function Base.show(io::IO, mime::MIME"text/plain", fail::Fail)
    print(io, "Test failed at ")
    show(io, mime, fail.test.loc)
    println(io)
    println(io, indented(fail.test.code))
    println(io, "Expected output:")
    if fail.test.expect !== nothing
        println(io, indented(fail.test.expect))
    end
    println(io, "Actual output:")
    println(io, indented(fail.output))
    if !isempty(fail.trace)
        println(io, indented(lstrip(sprint(Base.show_backtrace, fail.trace))))
    end
end

Base.convert(::Type{Test.Result}, fail::Fail) =
    Test.Fail(:test, asexpr(fail.test.code), nothing, false,
              convert(LineNumberNode, fail.test))

# Skipped test.

struct Skip <: AbstractResult
    test::TestCase
end

function Base.show(io::IO, mime::MIME"text/plain", skip::Skip)
    print(io, "Test skipped at ")
    show(io, mime, skip.test.loc)
    println(io)
    println(io, indented(skip.test.code))
    println(io, "Failed precondition:")
    if skip.test.pre !== nothing
        println(io, indented(skip.test.pre))
    end
end

# Ill-formed test.

struct Error <: AbstractResult
    test::BrokenTestCase
end

Base.show(io::IO, mime::MIME"text/plain", error::Error) =
    show(io, mime, error.test)

Base.convert(::Type{Test.Result}, error::Error) =
    Test.Error(:test, error.test.msg, nothing, false,
               convert(LineNumberNode, error.test))

# Summary of the testing results.

struct Summary
    passed::Int
    failed::Int
    skipped::Int
    errors::Int
end

function Base.show(io::IO, mime::MIME"text/plain", sum::Summary)
    if sum.passed > 0
        println(io, "Tests passed: ", sum.passed)
    end
    if sum.failed > 0
        println(io, "Tests failed: ", sum.failed)
    end
    if sum.skipped > 0
        println(io, "Tests skipped: ", sum.skipped)
    end
    if sum.errors > 0
        println(io, "Errors: ", sum.errors)
    end
end

# Output formatting.

struct Esc
    val::String
end

Esc(name::Symbol) = Esc(Base.text_colors[name])

Base.show(io::IO, esc::Esc) = nothing
Base.show(io::Base.TTY, esc::Esc) = print(io, esc.val)

const GOOD = Esc(:green)
const INFO = Esc(:cyan)
const WARN = Esc(:light_red)
const BOLD = Esc(:bold)
const NORM = Esc(:normal)
const CLRL = Esc("\r\e[K")

struct Msg
    args::Tuple
end

Msg(args...) = Msg(args)

Base.show(io::IO, msg::Msg) = print(io, msg.args...)

indicator(loc) =
    Msg(CLRL, BOLD, INFO, Esc("Testing " * string(loc)), NORM)
const MORE =
    Msg(BOLD, INFO, Esc("."), NORM)
const SUCCESS =
    Msg(BOLD, GOOD, "TESTING SUCCESSFUL!", NORM)
const FAILURE =
    Msg(BOLD, WARN, "TESTING UNSUCCESSFUL!", NORM)

const SEPARATOR = "~"^72 * "\n"

const INDENT = " "^4

function indented(str::AbstractString)
    inp = IOBuffer(str)
    out = IOBuffer()
    first = true
    for line in eachline(inp)
        if !first
            println(out)
        end
        first = false
        if !isempty(line)
            print(out, INDENT, line)
        end
    end
    return String(take!(out))
end

indented(text::TextBlock) =
    indented(text.val)

# Implementation of `test/runtests.jl`.

function runtests(; default=common_args(), subs=common_subs(), mod=nothing, quiet=false)
    program_file = !isempty(PROGRAM_FILE) ? PROGRAM_FILE : "runtests.jl"
    files = String[]
    for (i, arg) in enumerate(ARGS)
        if startswith(arg, '-')
            if arg == "--"
                append!(files, ARGS[i+1:end])
                break
            elseif arg == "-h" || arg == "--help"
                println("Usage: $program_file [-q|--quiet] [FILE]...")
                exit(0)
            elseif arg == "-q" || arg == "--quiet"
                quiet = true
            else
                println(stderr, """$program_file: unrecognized option '$arg'
                                   Try '$program_file --help' for more information.""")
                exit(2)
            end
        else
            push!(files, arg)
        end
    end
    if isempty(files)
        files = default
    end
    exit(!runtests(files, subs=subs, mod=mod, quiet=quiet))
end

function runtests(files; subs=common_subs(), mod=nothing, quiet=false)
    files = vcat(String[], findmd.(files)...)
    passed = failed = skipped = errors = 0
    for file in files
        suite = parsemd(file)
        for test in suite
            quiet || print(stderr, indicator(location(test)))
            res = runtest(test, subs=subs, mod=mod)
            if res isa Union{Fail, Error}
                quiet || print(stderr, CLRL)
                print(SEPARATOR)
                show(stdout, MIME"text/plain"(), res)
            end
            passed += res isa Pass
            failed += res isa Fail
            skipped += res isa Skip
            errors += res isa Error
        end
        quiet || print(stderr, CLRL)
    end
    summary = Summary(passed, failed, skipped, errors)
    success = failed == 0 && errors == 0
    if !success
        print(SEPARATOR)
    end
    quiet || show(stdout, MIME"text/plain"(), summary)
    quiet || println(stderr, success ? SUCCESS : FAILURE)
    return success
end

# Compatibility with the Test package.

function testset(files = nothing; default=common_args(), subs=common_subs(), mod=nothing, quiet=false)
    files = vcat(String[], findmd.(something(files, default))...)
    ts = Test.DefaultTestSet("NarrativeTest")
    pass = fail = error = 0
    for file in files
        file_ts = Test.DefaultTestSet(relpath(file))
        push!(ts.results, file_ts)
        suite = parsemd(file)
        for test in suite
            quiet || print(stderr, indicator(location(test)))
            res = runtest(test, subs=subs, mod=mod)
            pass += res isa Pass
            fail += res isa Fail
            error += res isa Error
            if res isa Pass
                file_ts.n_passed += 1
            elseif res isa Union{Fail, Error}
                push!(file_ts.results, convert(Test.Result, res))
                file_ts.anynonpass = true
                ts.anynonpass = true
                quiet || print(stderr, CLRL)
                print(SEPARATOR)
                show(stdout, MIME"text/plain"(), res)
            end
        end
        quiet || print(stderr, CLRL)
    end
    if ts.anynonpass
        print(SEPARATOR)
    end
    if Test.get_testset_depth() > 0
        Test.record(Test.get_testset(), ts)
    elseif ts.anynonpass
        throw(Test.TestSetException(pass, fail, error, 0, []))
    end
    ts
end

# Default parameters.

"""
    common_args() :: Vector{String}

Default test files for use when the test runner has no arguments.
"""
common_args() =
    [relpath(dirname(abspath(PROGRAM_FILE)))]

"""
    common_subs() :: Vector{Pair{Regex,SubstitutionString{String}}}

Substitutions applied to the expected output in order to convert
it to a regular expression.
"""
common_subs() = [
    r"[\\^$.[|()?*+{]" => s"\\\0",
    r"[\t ]*…[\t ]*" => s".+",
    r"[\t ]*⋮[\t ]*\r?\n?" => s"(.*(\\n|$))+",
    r"\A" => s"\\A",
    r"\z" => s"\\z",
]

# Find `*.md` files in the given directory.

function findmd(base)
    isdir(base) || return [base]
    mdfiles = String[]
    for (root, dirs, files) in walkdir(base, follow_symlinks=true)
        for file in files
            if splitext(file)[2] == ".md"
                push!(mdfiles, joinpath(root, file))
            end
        end
    end
    sort!(mdfiles)
    return mdfiles
end

# Load a file and extract the embedded tests.

"""
    parsemd(file) :: Vector{AbstractTestCase}
    parsemd(name, io) :: Vector{AbstractTestCase}

Parse the specified Markdown file to extract the embedded test suite; return a
list of test cases.
"""
parsemd(args...) =
    loadfile(parsemd!, args...)

"""
    parsejl(file) :: Vector{AbstractTestCase}
    parsejl(name, io) :: Vector{AbstractTestCase}

Load the specified Julia source file and extract the embedded test suite;
return a list of test cases.
"""
parsejl(args...) =
    loadfile(parsejl!, args...)

loadfile(parsefile!::Function, file::String) =
    loadfile(parsefile!, file, file)

function loadfile(parsefile!::Function, name::String, file::Union{String,IO})
    lines =
        try
            readlines(file)
        catch exc
            return AbstractTestCase[BrokenTestCase(Location(name), exc)]
        end
    stack = [TextBlock(Location(name, i), val * "\n") for (i, val) in enumerate(lines)]
    reverse!(stack)
    return parsefile!(stack)
end

# Extract the test suite from Markdown source.

isblank(line) =
    isempty(strip(line.val))
isfence(line) =
    startswith(line.val, "```") || startswith(line.val, "~~~")
isindent(line) =
    startswith(line.val, " "^4)
isadmonition(line) =
    startswith(line.val, "!!!")

function unindent(line)
    val = line.val[5:end]
    TextBlock(line.loc, !isempty(val) ? val : "\n")
end

function parsemd!(stack::Vector{TextBlock})
    # Accumulated test cases.
    suite = AbstractTestCase[]
    # Extract code snippets, either indented or fenced, and pass them to `parsejl!()`.
    while !isempty(stack)
        line = pop!(stack)
        if isfence(line)
            # Extract a fenced block.
            isrepl = false
            fenceloc = line.loc
            lang = strip(line.val[4:end])
            jlstack = TextBlock[]
            while !isempty(stack) && !isfence(stack[end])
                block = pop!(stack)
                isrepl = isrepl || startswith(block.val, "julia>")
                push!(jlstack, block)
            end
            if isempty(stack)
                push!(suite, BrokenTestCase(fenceloc, "incomplete fenced code block"))
            else
                pop!(stack)
                if isempty(lang)
                    reverse!(jlstack)
                    append!(suite, isrepl ? parsejlrepl!(jlstack) : parsejl!(jlstack))
                end
            end
        elseif isindent(line) && !isblank(line)
            # Extract an indented block.
            block = unindent(line)
            isrepl = startswith(block.val, "julia>")
            jlstack = TextBlock[block]
            while !isempty(stack) && (isindent(stack[end]) || isblank(stack[end]))
                block = unindent(pop!(stack))
                isrepl = isrepl || startswith(block.val, "julia>")
                push!(jlstack, block)
            end
            reverse!(jlstack)
            append!(suite, isrepl ? parsejlrepl!(jlstack) : parsejl!(jlstack))
        elseif isadmonition(line)
            # Skip an indented admonition block.
            while !isempty(stack) && (isindent(stack[end]) || isblank(stack[end]))
                pop!(stack)
            end
        end
    end
    return suite
end

# Extract the test suite from Julia source.

function parsejl!(stack::Vector{TextBlock})
    # Accumulated test cases.
    suite = AbstractTestCase[]
    # Find and parse test cases.
    while !isempty(stack)
        if isblank(stack[end])
            pop!(stack)
        else
            l = length(stack)
            push!(suite, parsecase!(stack))
            l != length(stack) || pop!(stack)
        end
    end
    return suite
end

const PROMPT_REGEX = r"^julia>(?: (.*))?$"
const SOURCE_REGEX = r"^       (.*)$"

function parsejlrepl!(stack::Vector{TextBlock})
    reverse!(stack)
    suite = AbstractTestCase[]
    code, buf = nothing, IOBuffer()
    function addcase!(expect)
        case = !isempty(code.val) ?
            TestCase(code.loc, code, nothing, expect, true) :
            BrokenTestCase(code.loc, "missing test code")
        push!(suite, case)
        code = nothing
    end
    while true
        line = popfirst!(stack)
        prompt = match(PROMPT_REGEX, line.val)
        if prompt !== nothing
            prompt[1] !== nothing && println(buf, prompt[1])
            while !isempty(stack)
                source = match(SOURCE_REGEX, stack[1].val)
                source !== nothing || break
                println(buf, source[1])
                popfirst!(stack)
            end
            code !== nothing && addcase!(TextBlock(code.loc, ""))
            code = TextBlock(line.loc, consumebuf!(buf))
        else
            println(buf, rstrip(line.val))
            while !isempty(stack) && !occursin(PROMPT_REGEX, stack[1].val)
                println(buf, rstrip(popfirst!(stack).val))
            end
            expect = TextBlock(line.loc, rstrip(consumebuf!(buf)))
            code !== nothing && addcase!(expect)
        end
        if isempty(stack)
            code !== nothing && addcase!(TextBlock(code.loc, ""))
            break
        end
    end
    suite
end

function consumebuf!(buf)
    n = bytesavailable(seekstart(buf))
    n > 0 ? String(take!(buf)) : ""
end

# Extract a test case from Julia source.

function parsecase!(stack::Vector{TextBlock})
    loc = stack[end].loc
    pre = TextBlock[]
    code = TextBlock[]
    expect = TextBlock[]
    # Parse precondition.
    if occursin(r"^\s*#\?\s+", stack[end].val)
        m = match(r"^\s*#\?\s+(.*)$", stack[end].val)
        push!(pre, TextBlock(stack[end].loc, rstrip(m[1])))
        pop!(stack)
        while !isempty(stack) && isblank(stack[end])
            pop!(stack)
        end
    end
    # Parse the code block.
    while !isempty(stack) && !occursin(r"^\s*#(\?|->|=>)\s+", stack[end].val)
        line = pop!(stack)
        if occursin(r"\s*#->\s+", line.val)
            # Code and output on the same line.
            m = match(r"^(.+)\s#->\s+(.*)$", line.val)
            push!(code, TextBlock(line.loc, rstrip(m[1])*"\n"))
            push!(expect, TextBlock(line.loc, rstrip(m[2])*"\n"))
            break
        end
        push!(code, line)
    end
    # Skip trailing empty lines.
    while !isempty(code) && isblank(code[end])
        pop!(code)
    end
    if isempty(expect) && !isempty(stack)
        if occursin(r"^\s*#->\s+", stack[end].val)
            # Standalone output line.
            line = pop!(stack)
            m = match(r"^\s*#->\s+(.*)$", line.val)
            push!(expect, TextBlock(line.loc, rstrip(m[1])*"\n"))
        elseif occursin(r"^\s*#=>\s+$", stack[end].val)
            # Multiline output block.
            commentline = pop!(stack)
            while !isempty(stack) && !occursin(r"^\s*=#\s+$", stack[end].val)
                line = pop!(stack)
                push!(expect, line)
            end
            !isempty(stack) || return BrokenTestCase(commentline.loc, "incomplete multiline comment block")
            pop!(stack)
        end
    end
    !isempty(code) || return BrokenTestCase(loc, "missing test code")
    return TestCase(loc, collapse(code), collapse(pre), collapse(expect), false)
end

# Run a single test case.

"""
    runtest(test::TestCase; subs=common_subs(), mod=nothing) :: AbstractResult
    runtest(loc, code; pre=nothing, expect=nothing, subs=common_subs(), mod=nothing) :: AbstractResult

Run the given test case, return the result.
"""
function runtest(test::TestCase; subs=common_subs(), mod=nothing)
    # Suppress printing of the output value?
    no_output = endswith(test.code.val, ";\n") || test.expect === nothing
    # Generate a module object for running the test code.
    if mod === nothing
        modid = Base.PkgId(module_name(test.loc.file))
        if Base.root_module_exists(modid)
            mod = Base.root_module(modid)
        else
            mod = Module(Symbol(modid.name))
            @eval mod begin
                eval(x) = Core.eval($mod, x)
                include(p) = Base.include($mod, p)
            end
            Base.register_root_module(mod)
        end
    end
    # Replace the standard output/error with a pipe.
    orig_have_color = Base.have_color
    Core.eval(Base, :(have_color = false))
    orig_stdout = stdout
    orig_stderr = stderr
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async=true, writer_supports_async=false)
    io = IOContext(pipe.in, :limit=>true, :module=>mod)
    redirect_stdout(pipe.in)
    redirect_stderr(pipe.in)
    pushdisplay(TextDisplay(io))
    trace = StackTraces.StackTrace()
    skipped = false
    output = ""
    @sync begin
        @async begin
            # Run the test code and print the result.
            stacktop = length(stacktrace())
            try
                filename = abspath(test.loc.file)
                tls = task_local_storage()
                has_source_path = haskey(tls, :SOURCE_PATH)
                source_path = get(tls, :SOURCE_PATH, nothing)
                tls[:SOURCE_PATH] = filename
                try
                    if test.pre !== nothing
                        pre_body = asexpr(test.pre)
                        pre = Core.eval(mod, pre_body)
                        pre::Bool
                        if !pre
                            skipped = true
                        end
                    end
                    if !skipped
                        body = asexpr(test.code)
                        ans = Core.eval(mod, body)
                        if ans !== nothing && !no_output
                            if test.repl
                              Base.invokelatest(show, io, "text/plain", ans)
                            else
                              Base.invokelatest(show, io, ans)
                            end
                        end
                    end
                catch exc
                    trace = stacktrace(catch_backtrace())[1:end-stacktop]
                    print(stderr, "ERROR: ")
                    Base.invokelatest(showerror, stderr, exc, trace; backtrace=false)
                end
                println(io)
                if has_source_path
                    tls[:SOURCE_PATH] = source_path
                else
                    delete!(tls, :SOURCE_PATH)
                end
            finally
                # Restore the standard output/error.
                popdisplay()
                redirect_stderr(orig_stderr)
                redirect_stdout(orig_stdout)
                Core.eval(Base, :(have_color = $orig_have_color))
                close(pipe.in)
            end
        end
        @async begin
            # Read the output of the test.
            output = read(pipe.out, String)
            close(pipe.out)
        end
    end
    if skipped
        return Skip(test)
    end
    # Compare the actual output with the expected output and generate the result.
    expect = test.expect !== nothing ? rstrip(test.expect.val) : ""
    actual = rstrip(join(map(rstrip, eachline(IOBuffer(output))), "\n"))
    return expect == actual || occursin(expect2regex(expect, subs), actual) ?
        Pass(test, actual) :
        Fail(test, actual, trace)
end

runtest(test::BrokenTestCase; subs=common_subs(), mod=nothing) =
    Error(test)

runtest(loc, code; pre=nothing, expect=nothing, subs=common_subs(), mod=nothing, repl=false) =
    runtest(TestCase(loc, TextBlock(loc, code),
                     pre !== nothing ? TextBlock(loc, pre) : nothing,
                     expect !== nothing ? TextBlock(loc, expect) : nothing,
                     repl),
            subs=subs, mod=mod)

# Convert expected output block to a regex.

function expect2regex(pattern, subs)
    for (regex, repl) in subs
        pattern = replace(pattern, regex => repl)
    end
    return Regex(pattern)
end

# Generate a module name from the filename.

function module_name(file)
    file = relpath(abspath(file), abspath(dirname(PROGRAM_FILE)))
    return join(titlecase.(split(file, r"[^0-9A-Za-z]+")))
end

end
