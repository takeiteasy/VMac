# VMac

Simple Virtual Machine solution to test out the Virtualization framework. I believe this only works with the *new* Silicon chips. Inspired by [MacVM](https://github.com/KhaosT/MacVM).

```
USAGE: vmac [<options>] <path>

ARGUMENTS:
  <path>                  Path to the image

OPTIONS:
  -r, --ram <ram>         Set RAM allocation (Max: 8gb) (default: 4294967296)
  -c, --cores <cores>     Set number of cores to use (Max: 8) (default: 2)
  -d, --disks <disks>     Add storage (e.g. 32gb,8192mb+ro,4194304kb+rw) (Max:
                          38gb)
  -e, --eth <eth>         Add network interface (e.g.
                          nat,bridge,bridge@en1,bridge@bridge0)
  -v, --video <video>     Set graphics options - Format is:
                          <width>x<height>@<ppi> (default: VMGraphics(width:
                          2560, height: 1600, ppi: 220))
  -o, --out <out>         Path to save VM when installing OS
  -b, --recovery-mode     Set to boot into recovery mode
  -a, --no-audio          Set to disable audio
  -x, --no-gui            Set to disable GUI
  -H, --headless          Sets --no-audio and --no-gui to true
  -q, --quiet             Mute output
  -R, --run-after-install Run VM after installation
  -t, --tmp               One-use VM, delete after exit
  -h, --help              Show help information.
  ```

## License

```
The MIT License (MIT)

Copyright (c) 2022 George Watson

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
