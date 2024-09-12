# nvim-dap-ruby
Ruby adapter for [nvim-dap](https://github.com/mfussenegger/nvim-dap) that uses
[rdbg](https://github.com/ruby/debug) to enable debugging capabilities without
modifying the source code, simply use [nvim-dap breackpoints](https://github.com/mfussenegger/nvim-dap?tab=readme-ov-file#usage).

## Installation

First, install [rdbg](https://github.com/ruby/debug) in your system, via your
package manager or as a
[gem](https://guides.rubygems.org/rubygems-basics/#installing-gems).

Using [lazy.nvim](https://github.com/folke/lazy.nvim):
```lua
{
    "mfussenegger/nvim-dap",
    dependencies = {
        { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } }, -- optional, but recommended
        {
            "jaimecgomezz/nvim-dap-ruby-rdbg",
            opts = {},
        },
    },
}
```

## Configuration

Here's a complete `opts` example:
```lua
{
    -- The `rdbg` executable path, defaults to `rdbg`
    rdbg_path = "/usr/bin/rdbg",
    -- Indicates wheter `rdbg` should stop at program start or not. It is
    -- applied to all configurations that doesn't specify it. Please see the
    -- #nonstop section for more details.
    nonstop = false,
    -- Whether the default plugin configurations should be included or not, defaults to `true`
    should_include_default_configurations = false,
    -- A list of user defined debugger configurations, defaults to `{}`
    configurations = {
        { -- Debug a script
            name = "debug my test file",
            -- The `cwd` is optional, if it isn't provided it defaults to `vim.fn.getcwd`
            cwd = '~/my-project',
            -- The list of arguments that will be fed to `rdbg` after the `--command --` flags, please see:
            -- https://github.com/ruby/debug?tab=readme-ov-file#rdbg-command-help
            args = { "ruby", "my-test.rb" },
        },
        { -- Debug the currest rspec file
            name = "rspec current file",
            args = { "rspec" },
            -- Can be any of the following
            --      - line (line at cursor position), e.g. Debug a single spec
            --      - file (current file), e.g. Debug all specs in a file
            --      - workspace (current working directory), e.g. Debug all specs
            --      - any other string will be used as provided
            target = "file",
            -- Indicates whether `rdbg` should stop at the program start for
            -- this specific configuration, it overwrites the global `nonstop`
            -- option. Please see the #nonstop section for more details.
            nonstop = true,
        },
        { 
            -- Attach a running `rdbg` instance. By providing no `args` or
            -- `target` values, it is understood that you want to connect to a
            -- debuggee. Please see the #attach-to-debuggee section for more details
            name = "attach to a debuggee",
            -- The `port` is optional, if isn't provided, you'll be prompted for
            -- one at the beginning of the debug session
            port = 1234,
            -- The `host` is also optional, it defaults to '127.0.0.1'
            host = "localhost"
        }
    }
}
```

## Nonstop
As stated above, this flag tells `rdbg` to stop, or not, at the beggining of the
program. 

I've tested the behavior of this flag on Linux and MacOS, and I've seen somewhat
confusing results; on Linux, the flag being set to `false` allows `rdbg` to
start adequately and open the necesary TCP/IP connections for `nvim-dap` to
connect to, whilst on MacOS, setting it to `true` grants the same output.

I'm sure that there's a valid explanation for this, but for now, enabling a
global `opts.nonstop` option, as well as a config-specific one, should grant the
necessary flexibility.

Additionally, if you need to improve/modify/inspect the default configurations,
you can access them as follows:

```lua
local dap_ruby = require("dap-ruby-rdbg")

-- Pick the first three configs, for example
dap_ruby.default_configurations = { unpack(dap_ruby.default_configurations, 1, 3) }
```

## Attach to debuggee
Although is possible to inspect the `rdbg` output by opening the `nvim-dap`
REPL as follows:

```lua
require("dap").repl.toggle()
```

There might be instances where you'd like to manually start `rdbg` in another
terminal and follow along with your code as you debug. Here are some sample
commands taken from the [rdbg command
help](https://github.com/ruby/debug?tab=readme-ov-file#rdbg-command-help)
section.

```sh
$ rdbg -O --port 1234 target.rb foo bar # starts accepts attaching with TCP/IP localhost:1234.
$ rdbg -O --port 1234 -- -r foo -e bar  # starts accepts attaching with TCP/IP localhost:1234.
```

After the `rdbg` instance is running, you can then run the `attach to debugger`
default config and connect to it by providing the `1234` port when prompted for
it.

Please see:
- https://github.com/ruby/debug?tab=readme-ov-file#use-rdbg-with-commands-written-in-ruby
- https://github.com/ruby/debug?tab=readme-ov-file#invoke-as-a-remote-debuggee

## Aknowledgements

- [nvim-dap-ruby](https://github.com/suketa/nvim-dap-ruby): Served as a starting point for this project
- [nvim-dap-python](https://github.com/mfussenegger/nvim-dap-python): Enlightened by example what would otherwise be a truly bumpy road
