# Test Suite

This is the test suite for NarrativeTest.jl.  We start with importing its
public API.

    using NarrativeTest


## Running the tests

The main entry point of NarrativeTest is the function `runtests()`, which takes
a filename or a vector of filenames.  Each filename must refer to a Markdown
document or a directory containing `*.md` files.  The files are parsed to
extract and run the embedded test suite.

    ans = runtests([joinpath(@__DIR__, "sample_good.md_")]);
    #=>
    Tests passed: 4
    TESTING SUCCESSFUL!
    =#

If all tests pass, `runtests()` returns `true`.

    ans
    #-> true

If any of the tests fail or an ill-formed test case is detected, `runtests()`
reports the problem and returns `false`.

    ans = runtests([joinpath(@__DIR__, "sample_bad.md_")]);
    #=>
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Test failed at …/sample_bad.md_:9
        2+2
    Expected output:
        5
    Actual output:
        4
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Test failed at …/sample_bad.md_:13
        sqrt(-1)
    Expected output:
        0.0 + 1.0im
    Actual output:
        ERROR: DomainError …
        sqrt will only return a complex result if called with a complex argument. …
        Stacktrace:
         ⋮
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Error at …/sample_bad.md_:17
        missing test code
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Test failed at …/sample_bad.md_:21
        42
    Expected output:
        43
    Actual output:
        42
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Error at …/sample_bad.md_:26
        missing test code
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Tests passed: 1
    Tests failed: 3
    Errors: 2
    TESTING UNSUCCESSFUL!
    =#

    ans
    #-> false

To suppress any output except for error reports, specify parameter
`quiet=true`.

    runtests(joinpath(@__DIR__, "sample_good.md_"), quiet=true)
    #-> true

    runtests(joinpath(@__DIR__, "sample_bad.md_"), quiet=true)
    #=>
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Test failed at …/sample_bad.md_:9
    ⋮
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Test failed at …/sample_bad.md_:13
    ⋮
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Error at …/sample_bad.md_:17
        missing test code
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Test failed at …/sample_bad.md_:21
        42
    Expected output:
        43
    Actual output:
        42
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Error at …/sample_bad.md_:26
        missing test code
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    false
    =#

To implement the `runtests.jl` script, invoke `runtests()` without arguments.
In this form, `runtests()` gets the list of files from command-line parameters
and, after testing is done, terminates the process with an appropriate exit
code.

    julia = Base.julia_cmd()
    pwd = @__DIR__

    run(`$julia -e 'using NarrativeTest; runtests()' $pwd/sample_good.md_`);
    #=>
    ⋮
    TESTING SUCCESSFUL!
    =#

    run(`$julia -e 'using NarrativeTest; runtests()' $pwd/sample_bad.md_`);
    #=>
    ⋮
    TESTING UNSUCCESSFUL!
    ERROR: failed process: Process(` … `, ProcessExited(1)) [1]
    =#

Invoke the script with `--help` to get a brief help on available options.

    run(`$julia -e 'using NarrativeTest; runtests()' -- --help`);
    #=>
    Usage: runtests.jl [-q|--quiet] [FILE]...
    =#

Add `--quiet` to suppress extra output.

    run(`$julia -e 'using NarrativeTest; runtests()' -- --quiet $pwd/sample_good.md_`);

Use `--` to separate options from regular parameters.

    run(`$julia -e 'using NarrativeTest; runtests()' -- --quiet -- --quiet`);
    #=>
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Error at …/--quiet
        SystemError: …
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ERROR: failed process: Process(` … `, ProcessExited(1)) [1]
    =#

Any other option will result in an error.

    run(`$julia -e 'using NarrativeTest; runtests()' -- --error`);
    #=>
    runtests.jl: unrecognized option '--error'
    Try 'runtests.jl --help' for more information.
    ERROR: failed process: Process(` … `, ProcessExited(2)) [2]
    =#


## Using with `Test` library

Function `testset()` makes NarrativeTest compatible with the standard Test
library.

    using Test

    NarrativeTest.testset([joinpath(@__DIR__, "sample_good.md_"),
                           joinpath(@__DIR__, "sample_bad.md_")])
    #=>
    ⋮
    ERROR: Some tests did not pass: 5 passed, 3 failed, 2 errored, 0 broken.
    =#

Normally, it should be invoked from a test set.

    @testset begin
        @test true == false
        NarrativeTest.testset([joinpath(@__DIR__, "sample_good.md_"),
                               joinpath(@__DIR__, "sample_bad.md_")])
        @test 2 + 2 == 5
    end
    #=>
    ⋮
    ERROR: Some tests did not pass: 5 passed, 5 failed, 2 errored, 0 broken.
    =#


## Extracting test cases

We can extract individual test cases from Markdown and Julia files.  Let us
import the respective API.

    using NarrativeTest:
        parsejl,
        parsemd

Function `parsemd()` parses the given Markdown file and returns an array of the
extracted test cases.

    suite = parsemd(joinpath(@__DIR__, "sample_bad.md_"))
    foreach(display, suite)
    #=>
    Test case at …/sample_bad.md_:5
        (3+4)*6
    Expected output:
        42
    Test case at …/sample_bad.md_:9
        2+2
    Expected output:
        5
    Test case at …/sample_bad.md_:13
        sqrt(-1)
    Expected output:
        0.0 + 1.0im
    Error at …/sample_bad.md_:17
        missing test code
    Test case at …/sample_bad.md_:21
        42
    Expected output:
        43
    Error at …/sample_bad.md_:26
        missing test code
    =#

    suite = parsemd("sample_missing.md_")
    foreach(display, suite)
    #=>
    Error at …/sample_missing.md_
        SystemError: …
    =#

Function `parsemd()` recognizes two types of Markdown code blocks: indented and
fenced.

    suite = parsemd(
        @__FILE__,
        IOBuffer("""
            These test cases are embedded in an indented code block.

                (3+4)*6
                $("#->") 42

                2+2
                $("#->") 5

            The following test cases are embedded in a fenced code block.
            ```
            print(2^16)
            $("#->") 65526

            sqrt(-1)
            $("#->") 0.0 + 1.0im
            ```
            """))
    foreach(display, suite)
    #=>
    Test case at …/index.md:3
        (3+4)*6
    Expected output:
        42
    Test case at …/index.md:6
        2+2
    Expected output:
        5
    Test case at …/index.md:11
        print(2^16)
    Expected output:
        65526
    Test case at …/index.md:14
        sqrt(-1)
    Expected output:
        0.0 + 1.0im
    =#

A fenced code block with an explicit language indicator is ignored.

    parsemd(
        @__FILE__,
        IOBuffer("""
            The following code will not be tested.
            ```julia
            2 + 2   $("#->") 5
            ```
            """))
    #-> NarrativeTest.AbstractTestCase[]

An indented admonition block will be ignored.

    parsemd(
        @__FILE__,
        IOBuffer("""
            !!! warning

                This is an admonition block,
                not a Julia code.
            """))
    #-> NarrativeTest.AbstractTestCase[]

It is an error if a fenced code block is not closed.

    suite = parsemd(
        @__FILE__,
        IOBuffer("""
            Incomplete fenced code block is an error.
            ```
            (3+4)*6
            $("#->") 42
            """))
    foreach(display, suite)
    #=>
    Error at …/index.md:2
        incomplete fenced code block
    =#

Function `parsejl()` parses a Julia file and returns an array of the extracted
test cases.  It recognizes `#?` as a precondition and `#-> …` and `#=> ⋮ =#` as
single-line and multi-line expected output.

    suite = parsejl(
        @__FILE__,
        IOBuffer("""
            2+2     $("#->") 4

            print(2^16)
            $("#->") 65526

            display(collect('A':'Z'))
            $("#=>")
            26-element Array{Char,1}:
             'A'
             'B'
             ⋮
             'Z'
            =#

            $("#?") Sys.WORD_SIZE == 64

            Int     $("#->") Int64
            """))
    foreach(display, suite)
    #=>
    Test case at …/index.md:1
        2+2
    Expected output:
        4
    Test case at …/index.md:3
        print(2^16)
    Expected output:
        65526
    Test case at …/index.md:6
        display(collect('A':'Z'))
    Expected output:
        26-element Array{Char,1}:
         'A'
         'B'
         ⋮
         'Z'
    Test case at …/index.md:15
        Int
    Precondition:
        Sys.WORD_SIZE == 64
    Expected output:
        Int64
    =#

A test case may have no expected output.

    suite = parsejl(
        @__FILE__,
        IOBuffer("""
            x = pi/6
            y = sin(x)

            @assert y ≈ 0.5
            """))
    foreach(display, suite)
    #=>
    Test case at …/index.md:1
        x = pi/6
        y = sin(x)

        @assert y ≈ 0.5
    =#

However, it is an error to have an expected output block without any test code.

    suite = parsejl(
        @__FILE__,
        IOBuffer("""
            $("#->") 42
            """))
    foreach(display, suite)
    #=>
    Error at …/index.md:1
        missing test code
    =#

It is also an error if a multi-line output block is not closed.

    suite = parsejl(
        @__FILE__,
        IOBuffer("""
            display(collect('A':'Z'))
            $("#=>")
            26-element Array{Char,1}:
             'A'
             'B'
             ⋮
             'Z'
            """))
    foreach(display, suite)
    #=>
    Error at …/index.md:2
        incomplete multiline comment block
    =#

It is possible to define tests using syntax simulating REPL session (in fact
REPL session can be copy pasted as-is to become test cases), just prefix a line
in a code block with `julia> `:

    suite = parsemd(
        @__FILE__,
        IOBuffer("""
            These test cases are embedded in an indented code block.

                julia> (3+4)*6
                42

                julia> 2+2
                5

            The following test cases are embedded in a fenced code block.
            ```
            julia> print(2^16)
            65526

            julia> sqrt(-1)
            0.0 + 1.0im
            ```
            """))
    foreach(display, suite)
    #=>
    Test case at …/index.md:3
        (3+4)*6
    Expected output:
        42
    Test case at …/index.md:6
        2+2
    Expected output:
        5
    Test case at …/index.md:11
        print(2^16)
    Expected output:
        65526
    Test case at …/index.md:14
        sqrt(-1)
    Expected output:
        0.0 + 1.0im
    =#

Expected output can be missing:

    suite = parsemd(
        @__FILE__,
        IOBuffer("""
            The indented code block below is missing few expected outputs:

                julia> 1

                julia> 2
                2

                julia> 3

            Now fenced code block with missing few expected outputs:

            ```
            julia> 1

            julia> 2
            2

            julia> 3
            ```
            """))
    foreach(display, suite)
    #=>
    Test case at …/index.md:3
        1
    Expected output:

    Test case at …/index.md:5
        2
    Expected output:
        2
    Test case at …/index.md:8
        3
    Expected output:

    Test case at …/index.md:13
        1
    Expected output:

    Test case at …/index.md:15
        2
    Expected output:
        2
    Test case at …/index.md:18
        3
    Expected output:

    =#

REPL-like test cases can span multiple lines as in real REPL if we keep
indentation:

    suite = parsemd(
        @__FILE__,
        IOBuffer("""
            Multiline code blocks:

                julia> [1 2;
                        3 4]
                2×2 Matrix{Int64}:
                 1  2
                 3  4

                julia> 1
                       2
                2

                julia> "no
                        output?"

            """))
    foreach(display, suite)
    #=>
    Test case at …/index.md:3
        [1 2;
         3 4]
    Expected output:
        2×2 Matrix{Int64}:
         1  2
         3  4
    Test case at …/index.md:9
        1
        2
    Expected output:
        2
    Test case at …/index.md:13
        "no
         output?"
    Expected output:
    =#

Empty prompt with REPL-like test cases is considered as invalid:

    suite = parsemd(
        @__FILE__,
        IOBuffer("""
            Some test cases are invalid below as they are missing code
            to execute:

                julia> 1

                julia>

                julia> 3
                3

                julia> 4;
                julia> 5
                5

                julia>

            """))
    foreach(display, suite)
    #=>
    Test case at …/index.md:4
        1
    Expected output:

    Error at …/index.md:6
        missing test code
    Test case at …/index.md:8
        3
    Expected output:
        3
    Test case at …/index.md:11
        4;
    Expected output:

    Test case at …/index.md:12
        5
    Expected output:
        5
    Error at …/index.md:15
        missing test code
    =#

## Running one test

We can run individual tests using the function `runtest()`.

    using NarrativeTest:
        runtest

Function `runtest()` takes a test case object and returns the test result.

    suite = parsemd(joinpath(@__DIR__, "sample_bad.md_"))
    suite = filter(t -> t isa NarrativeTest.TestCase, suite)
    results = map(runtest, suite)
    foreach(display, results)
    #=>
    Test passed at …/sample_bad.md_:5
        (3+4)*6
    Expected output:
        42
    Actual output:
        42
    Test failed at …/sample_bad.md_:9
        2+2
    Expected output:
        5
    Actual output:
        4
    Test failed at …/sample_bad.md_:13
        sqrt(-1)
    Expected output:
        0.0 + 1.0im
    Actual output:
        ERROR: DomainError …:
        …
        Stacktrace:
        ⋮
    =#

`runtest()` captures the content of the standard output and error streams and
matches it against the expected test result.

    result = runtest(@__FILE__, """println("Hello World!")\n""", expect="Hello World!\n")
    display(result)
    #=>
    Test passed at …/index.md
        println("Hello World!")
    Expected output:
        Hello World!
    Actual output:
        Hello World!
    =#

`runtest()` shows the value produced by the last statement of the test code.

    result = runtest(@__FILE__, "(3+4)*6\n", expect="42\n")
    display(result)
    #=>
    Test passed at …/index.md
        (3+4)*6
    Expected output:
        42
    Actual output:
        42
    =#

    result = runtest(@__FILE__, "2+2\n", expect="5\n")
    display(result)
    #=>
    Test failed at …/index.md
        2+2
    Expected output:
        5
    Actual output:
        4
    =#

However, if this value is equal to `nothing`, it is not displayed.

    result = runtest(@__FILE__, "nothing\n", expect="\n")
    display(result)
    #=>
    Test passed at …/index.md
        ⋮
    =#

This value is also concealed if the test code ends with `;` or if the test case
has no expected output.

    result = runtest(@__FILE__, "(3+4)*6;\n", expect="\n")
    display(result)
    #=>
    Test passed at …/index.md
        ⋮
    =#

    result = runtest(@__FILE__, "(3+4)*6\n", expect=nothing)
    display(result)
    #=>
    Test passed at …/index.md
        ⋮
    =#

A test case may include a precondition.  When the precondition is evaluated to
`false`, the test case is skipped.

    result = runtest(@__FILE__, "2+2\n", pre="0 < 1\n", expect="4\n")
    display(result)
    #=>
    Test passed at …/index.md
        2+2
    Expected output:
        4
    Actual output:
        4
    =#

    result = runtest(@__FILE__, "2+2\n", pre="0 >= 1\n", expect="5\n")
    display(result)
    #=>
    Test skipped at …/index.md
        2+2
    Failed precondition:
        0 >= 1
    =#

The precondition must always produce a Boolean value.

    result = runtest(@__FILE__, "2+2\n", pre="missing\n", expect="4\n")
    display(result)
    #=>
    Test failed at …/index.md
        2+2
    Expected output:
        4
    Actual output:
        ERROR: TypeError: non-boolean (Missing) used in boolean context
    =#

Functions `include` and `eval` are available in the test code.

    result = runtest(@__FILE__, "include(\"included.jl\")", expect="Hello from included.jl!\n")
    display(result)
    #=>
    Test passed at …/index.md
        include("included.jl")
    Expected output:
        Hello from included.jl!
    Actual output:
        Hello from included.jl!
    =#

    result = runtest(@__FILE__, "eval(:(print(\"Hello from eval!\")))", expect="Hello from eval!\n")
    display(result)
    #=>
    Test passed at …/index.md
        eval(:(print("Hello from eval!")))
    Expected output:
        Hello from eval!
    Actual output:
        Hello from eval!
    =#

Macros `@__MODULE__`, `@__DIR__`, `@__FILE__`, `@__LINE__` properly report the
location of the test code.

    result = runtest(@__FILE__, "println(@__MODULE__)", expect=string(@__MODULE__))
    display(result)
    #=>
    Test passed at …/index.md
        println(@__MODULE__)
    Expected output:
        IndexMd
    Actual output:
        IndexMd
    =#

    result = runtest(@__FILE__, "println(@__DIR__)", expect=@__DIR__)
    display(result)
    #=>
    Test passed at …/index.md
        println(@__DIR__)
    Expected output:
        /…/test
    Actual output:
        /…/test
    =#

    result = runtest(@__FILE__, "println(@__FILE__)", expect=@__FILE__)
    display(result)
    #=>
    Test passed at …/index.md
        println(@__FILE__)
    Expected output:
        /…/index.md
    Actual output:
        /…/index.md
    =#

    result = runtest(@__FILE__, "println(@__LINE__)", expect="1")
    display(result)
    #=>
    Test passed at …/index.md
        println(@__LINE__)
    Expected output:
        1
    Actual output:
        1
    =#

When the test raises an exception, the error message (but not the stack trace)
is included with the output.

    result = runtest(@__FILE__, "sqrt(-1)\n", expect="ERROR: DomainError …\n …")
    display(result)
    #=>
    Test passed at …/index.md
        sqrt(-1)
    Expected output:
        ERROR: DomainError …
         …
    Actual output:
        ERROR: DomainError …
        sqrt will only return a complex result if called with a complex argument. …
    =#

In the expected output, we can use symbol `…` to match any number of characters
in a line, and symbol `⋮` to match any number of lines.

    result = runtest(@__FILE__, "print(collect('A':'Z'))\n", expect="['A', 'B', …, 'Z']\n")
    display(result)
    #=>
    Test passed at …/index.md
        print(collect('A':'Z'))
    Expected output:
        ['A', 'B', …, 'Z']
    Actual output:
        ['A', 'B', 'C', …, 'Y', 'Z']
    =#

    result = runtest(@__FILE__, "foreach(println, 'A':'Z')\n", expect="A\nB\n⋮\nZ\n")
    display(result)
    #=>
    Test passed at …/index.md
        foreach(println, 'A':'Z')
    Expected output:
        A
        B
        ⋮
        Z
    Actual output:
        A
        B
        ⋮
        Z
    =#

A test case can be executed in the context of a specific module.

    runtest(@__FILE__, "hello = \"Hello World!\"", mod=Main)

    Main.hello
    #-> "Hello World!"

