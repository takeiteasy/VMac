## VMac

```USAGE: vmac [<options>] <path>

ARGUMENTS:
  <path>                  Path to the image

OPTIONS:
  -r, --ram <ram>         Set RAM allocation (Max: 8gb) (default: 4294967296)
  -c, --cores <cores>     Set number of cores to use (Max: 8) (default: 2)
  -d, --disks <disks>     Add storage (e.g. 32gb,8192mb+ro,4194304kb+rw) (Max:
                          98gb)
  -e, --eth <eth>         Add network interface (e.g.
                          nat,bridge,bridge@en1,bridge@bridge0)
  -v, --video <video>     Set graphics options - Format is:
                          <width>x<height>@<ppi> (default: VMGraphics(width:
                          2560, height: 1600, ppi: 220))
  -o, --out <out>         Path to save VM when installing OS
  -b, --recovery-mode     Set to boot into recovery mode (TODO)
  -a, --no-audio          Set to disable audio
  -x, --no-gui            Set to disable GUI
  -H, --headless          Sets --no-audio and --no-gui to true
  -q, --quiet             Mute output
  -R                      Run VM after installation
  -t, --tmp               One-use VM, delete after exit
  -h, --help              Show help information.```
